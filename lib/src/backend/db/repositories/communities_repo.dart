import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:juniper_journal/src/backend/db/models/bulletin_comment.dart';
import 'package:juniper_journal/src/backend/db/models/bulletin_post.dart';
import 'package:juniper_journal/src/backend/db/models/community.dart';
import 'package:juniper_journal/src/backend/db/models/community_invite.dart';
import 'package:juniper_journal/src/backend/db/models/community_member.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/supabase_database.dart';
import 'package:juniper_journal/src/backend/storage/storage_service.dart';

class CommunitiesRepo {
  SupabaseClient get _client => SupabaseDatabase.instance.client;

  Future<bool> isAcceptedCommunityMember(String communityId) async {
    final user = _client.auth.currentUser?.id;
    if (user == null) return false;
    try {
      final row = await _client
          .from('community_members')
          .select('id')
          .eq('community_id', communityId)
          .eq('user_id', user)
          .eq('status', 'accepted')
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  /// Public summary contains administrators and aggregate counts, never a roster.
  Future<Map<String, dynamic>> getPublicCommunityProfile(
    String communityId,
  ) async => Map<String, dynamic>.from(
    await _client.rpc(
          'public_community_profile',
          params: {'p_community_id': communityId},
        )
        as Map,
  );

  // ── Create ──────────────────────────────────────────────────────────────────

  /// Creates a community, adds the creator as owner, creates the group
  /// conversation, then invites [memberIds].
  /// Returns the new Community or null on failure.
  Future<Community?> createCommunity({
    required String name,
    String? imageUrl,
    required String visibility,
    String? subjectFocus,
    List<String> memberIds = const [],
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return null;

    try {
      // 1. Insert community
      final row = await _client
          .from('communities')
          .insert({
            'name': name,
            'image_url': imageUrl,
            'visibility': visibility,
            'subject_focus': subjectFocus,
            'created_by': currentUserId,
          })
          .select()
          .single();

      final community = Community.fromMap(row);

      // 2. Add creator as accepted owner
      await _client.from('community_members').insert({
        'community_id': community.id,
        'user_id': currentUserId,
        'role': 'owner',
        'invited_by': currentUserId,
        'status': 'accepted',
      });

      // 3. Create the group conversation (RPC adds all accepted members)
      await _client.rpc(
        'create_community_conversation',
        params: {'p_community_id': community.id, 'p_group_name': name},
      );

      // 4. Invite additional members (pending)
      for (final userId in memberIds) {
        if (userId == currentUserId) continue;
        await _client.from('community_members').insert({
          'community_id': community.id,
          'user_id': userId,
          'role': 'member',
          'invited_by': currentUserId,
          'status': 'pending',
        });
      }

      // 5. Re-fetch to get conversation_id
      final updated = await getCommunityById(community.id);
      return updated ?? community;
    } catch (e, st) {
      debugPrint('createCommunity error: $e\n$st');
      return null;
    }
  }

  // ── Read ────────────────────────────────────────────────────────────────────

  Future<Community?> getCommunityById(String id) async {
    try {
      final row = await _client
          .from('communities')
          .select()
          .eq('id', id)
          .single();
      return Community.fromMap(row);
    } catch (e, st) {
      debugPrint('getCommunityById error: $e\n$st');
      return null;
    }
  }

  /// Returns communities the current user belongs to (accepted) or owns.
  Future<List<Community>> getUserCommunities() async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return [];
    try {
      final rows = await _client
          .from('community_members')
          .select('community_id, communities(*)')
          .eq('user_id', currentUserId)
          .eq('status', 'accepted');

      return List<Map<String, dynamic>>.from(rows)
          .map(
            (r) => Community.fromMap(r['communities'] as Map<String, dynamic>),
          )
          .toList();
    } catch (e, st) {
      debugPrint('getUserCommunities error: $e\n$st');
      return [];
    }
  }

  /// Returns all communities created in the app.
  Future<List<Community>> getAllCommunities() async {
    try {
      final rows = await _client
          .from('communities')
          .select()
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(
        rows,
      ).map(Community.fromMap).toList();
    } catch (e, st) {
      debugPrint('getAllCommunities error: $e\n$st');
      return [];
    }
  }

  /// Returns all accepted members' projects for a community.
  Future<List<Project>> getCommunityProjects(String communityId) async {
    try {
      if (_client.auth.currentUser == null) {
        final rows = await _client
            .from('project_documentation')
            .select()
            .ilike('visibility', 'public')
            .contains('community_links', [
              {'id': communityId},
            ]);
        return [for (final row in rows) Project.fromMap(row)];
      }
      // Get accepted member user IDs
      final memberRows = await _client
          .from('community_members')
          .select('user_id')
          .eq('community_id', communityId)
          .eq('status', 'accepted');

      final memberIds = List<Map<String, dynamic>>.from(
        memberRows,
      ).map((r) => r['user_id'].toString()).toList();

      final linkedRows = await _client
          .from('project_documentation')
          .select()
          .contains('community_links', [
            {'id': communityId},
          ]);
      final memberProjectRows = memberIds.isEmpty
          ? <dynamic>[]
          : await _client
                .from('project_documentation')
                .select()
                .inFilter('user_id', memberIds);
      final byId = <String, Project>{};
      for (final row in [...memberProjectRows, ...linkedRows]) {
        final project = Project.fromMap(Map<String, dynamic>.from(row));
        byId[project.id] = project;
      }
      return byId.values.toList();
    } catch (e, st) {
      debugPrint('getCommunityProjects error: $e\n$st');
      return [];
    }
  }

  // ── Invites ─────────────────────────────────────────────────────────────────

  /// Returns pending community invites for the current user.
  Future<List<CommunityInvite>> getPendingInvites() async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return [];
    try {
      final rows = await _client
          .from('community_members')
          .select('''
            id, community_id, status,
            communities(name, image_url),
            profiles!community_members_invited_by_fkey(display_name, username)
          ''')
          .eq('user_id', currentUserId)
          .eq('status', 'pending');

      return List<Map<String, dynamic>>.from(rows).map((r) {
        final community = r['communities'] as Map<String, dynamic>? ?? {};
        final inviter = r['profiles'] as Map<String, dynamic>? ?? {};
        return CommunityInvite(
          id: r['id']?.toString() ?? '',
          communityId: r['community_id']?.toString() ?? '',
          communityName: community['name']?.toString() ?? '',
          communityImageUrl: community['image_url']?.toString(),
          inviterDisplayName: inviter['display_name']?.toString(),
          inviterUsername: inviter['username']?.toString(),
          status: r['status']?.toString() ?? 'pending',
        );
      }).toList();
    } catch (e, st) {
      debugPrint('getPendingInvites error: $e\n$st');
      return [];
    }
  }

  // ── Members (owner view) ────────────────────────────────────────────────────

  /// All accepted + pending members for a community (owner use).
  Future<List<CommunityMember>> getCommunityMembers(String communityId) async {
    try {
      // Fetch member rows without the ambiguous profiles join
      final rows = await _client
          .from('community_members')
          .select('id, user_id, role, status')
          .eq('community_id', communityId)
          .inFilter('status', ['accepted', 'pending'])
          .order('joined_at');

      final members = List<Map<String, dynamic>>.from(rows);
      if (members.isEmpty) return [];

      // Fetch profiles separately by user_id
      final userIds = members.map((r) => r['user_id'].toString()).toList();
      final profileRows = await _client
          .from('profiles')
          .select('id, display_name, username, avatar_url')
          .inFilter('id', userIds);

      final profileMap = {
        for (final p in List<Map<String, dynamic>>.from(profileRows))
          p['id'].toString(): p,
      };

      return members.map((r) {
        final profile = profileMap[r['user_id'].toString()] ?? {};
        return CommunityMember.fromMap({...r, 'profiles': profile});
      }).toList();
    } catch (e, st) {
      debugPrint('getCommunityMembers error: $e\n$st');
      return [];
    }
  }

  /// Invite a user to the community (inserts pending row).
  Future<bool> inviteMember({
    required String communityId,
    required String userId,
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return false;
    try {
      await _client.from('community_members').upsert({
        'community_id': communityId,
        'user_id': userId,
        'role': 'member',
        'invited_by': currentUserId,
        'status': 'pending',
      }, onConflict: 'community_id,user_id');
      return true;
    } catch (e, st) {
      debugPrint('inviteMember error: $e\n$st');
      return false;
    }
  }

  /// Remove an accepted member or cancel a pending invite by memberId row.
  Future<bool> removeMember(String memberId) async {
    try {
      await _client.from('community_members').delete().eq('id', memberId);
      return true;
    } catch (e, st) {
      debugPrint('removeMember error: $e\n$st');
      return false;
    }
  }

  // ── Update ──────────────────────────────────────────────────────────────────

  Future<bool> updateCommunity({
    required String id,
    String? name,
    String? imageUrl,
    String? visibility,
    String? subjectFocus,
    String? bannerColorHex,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (imageUrl != null) updates['image_url'] = imageUrl;
      if (visibility != null) updates['visibility'] = visibility;
      if (subjectFocus != null) updates['subject_focus'] = subjectFocus;
      if (bannerColorHex != null) updates['banner_color'] = bannerColorHex;

      if (updates.isEmpty) return true;
      await _client.from('communities').update(updates).eq('id', id);
      return true;
    } catch (e, st) {
      debugPrint('updateCommunity error: $e\n$st');
      return false;
    }
  }

  /// Accept or decline a community invite by community_member row id.
  /// Deletes a community and all associated data:
  /// 1. Community image from storage (if any)
  /// 2. Group conversation row → cascades messages + participants
  /// 3. Communities row → cascades community_members
  Future<bool> deleteCommunity(Community community) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId != community.createdBy) {
      return false;
    }
    try {
      // 1. Delete community image from storage
      if (community.imageUrl != null && community.imageUrl!.isNotEmpty) {
        await StorageService().deleteImage(
          community.imageUrl!,
          bucketName: 'images',
        );
      }

      // 2. Delete the group conversation (cascades messages + participants)
      if (community.conversationId != null) {
        await _client
            .from('conversations')
            .delete()
            .eq('id', community.conversationId!);
      }

      // 3. Delete the community row (cascades community_members)
      await _client.from('communities').delete().eq('id', community.id);

      return true;
    } catch (e, st) {
      debugPrint('deleteCommunity error: $e\n$st');
      return false;
    }
  }

  Future<bool> respondToInvite(String memberId, bool accept) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return false;
    try {
      if (accept) {
        // Mark as accepted
        await _client
            .from('community_members')
            .update({'status': 'accepted'})
            .eq('id', memberId)
            .eq('user_id', currentUserId);

        // Add to group conversation
        final memberRow = await _client
            .from('community_members')
            .select('community_id, communities(conversation_id)')
            .eq('id', memberId)
            .single();

        final community =
            memberRow['communities'] as Map<String, dynamic>? ?? {};
        final convId = community['conversation_id']?.toString();
        if (convId != null) {
          await _client.rpc(
            'add_to_group_conversation',
            params: {'p_conversation_id': convId, 'p_user_id': currentUserId},
          );
        }
      } else {
        await _client
            .from('community_members')
            .update({'status': 'declined'})
            .eq('id', memberId)
            .eq('user_id', currentUserId);
      }
      return true;
    } catch (e, st) {
      debugPrint('respondToInvite error: $e\n$st');
      return false;
    }
  }

  // ── Bulletin posts ───────────────────────────────────────────────────────────

  Future<BulletinPost?> createBulletinPost({
    required String communityId,
    required String title,
    required String category,
    required String body,
    List<String> imageUrls = const [],
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await _client
          .from('bulletin_posts')
          .insert({
            'community_id': communityId,
            'user_id': user.id,
            'title': title,
            'category': category,
            'body': body,
            'image_urls': imageUrls,
          })
          .select()
          .single();
      return BulletinPost.fromMap(Map<String, dynamic>.from(row));
    } catch (e, st) {
      debugPrint('createBulletinPost error: $e\n$st');
      return null;
    }
  }

  Future<List<BulletinPost>> getBulletinPosts(String communityId) async {
    try {
      final rows = await _client
          .from('bulletin_posts')
          .select(
            'id, community_id, user_id, title, category, body, created_at, image_urls',
          )
          .eq('community_id', communityId)
          .order('created_at', ascending: false);

      final posts = List<Map<String, dynamic>>.from(rows);
      if (posts.isEmpty) return [];

      final userIds = posts
          .map((r) => r['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final profileRows = await _client
          .from('profiles')
          .select('id, display_name, username, avatar_url')
          .inFilter('id', userIds);

      final profileById = {
        for (final p in List<Map<String, dynamic>>.from(profileRows))
          p['id'].toString(): p,
      };

      // Fetch comment counts
      final postIds = posts
          .map((r) => r['id']?.toString())
          .whereType<String>()
          .toList();
      Map<String, int> commentCounts = {};
      if (postIds.isNotEmpty) {
        try {
          final countRows = await _client
              .from('bulletin_post_comments')
              .select('post_id')
              .inFilter('post_id', postIds);
          for (final r in List<Map<String, dynamic>>.from(countRows)) {
            final pid = r['post_id']?.toString() ?? '';
            commentCounts[pid] = (commentCounts[pid] ?? 0) + 1;
          }
        } catch (_) {}
      }

      return posts
          .map(
            (r) => BulletinPost.fromMap({
              ...r,
              'comment_count': commentCounts[r['id']?.toString()] ?? 0,
            }, profile: profileById[r['user_id']?.toString()]),
          )
          .toList();
    } catch (e, st) {
      debugPrint('getBulletinPosts error: $e\n$st');
      return [];
    }
  }

  Future<bool> updateBulletinPost({
    required String id,
    String? title,
    String? category,
    String? body,
    List<String>? imageUrls,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (category != null) updates['category'] = category;
      if (body != null) updates['body'] = body;
      if (imageUrls != null) updates['image_urls'] = imageUrls;
      if (updates.isEmpty) return true;
      await _client
          .from('bulletin_posts')
          .update(updates)
          .eq('id', id)
          .eq('user_id', user.id);
      return true;
    } catch (e, st) {
      debugPrint('updateBulletinPost error: $e\n$st');
      return false;
    }
  }

  Future<bool> deleteBulletinPost(String id) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      await _client
          .from('bulletin_posts')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);
      return true;
    } catch (e, st) {
      debugPrint('deleteBulletinPost error: $e\n$st');
      return false;
    }
  }

  Future<List<BulletinComment>> getBulletinComments(String postId) async {
    try {
      final rows = await _client
          .from('bulletin_post_comments')
          .select('id, post_id, user_id, body, created_at')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      final comments = List<Map<String, dynamic>>.from(rows);
      if (comments.isEmpty) return [];

      final userIds = comments
          .map((r) => r['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final profileRows = await _client
          .from('profiles')
          .select('id, display_name, username, avatar_url')
          .inFilter('id', userIds);

      final profileById = {
        for (final p in List<Map<String, dynamic>>.from(profileRows))
          p['id'].toString(): p,
      };

      return comments
          .map(
            (r) => BulletinComment.fromMap(
              r,
              profile: profileById[r['user_id']?.toString()],
            ),
          )
          .toList();
    } catch (e, st) {
      debugPrint('getBulletinComments error: $e\n$st');
      return [];
    }
  }

  Future<BulletinComment?> addBulletinComment({
    required String postId,
    required String body,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await _client
          .from('bulletin_post_comments')
          .insert({'post_id': postId, 'user_id': user.id, 'body': body})
          .select()
          .single();

      // fetch own profile for display
      final profileRow = await _client
          .from('profiles')
          .select('id, display_name, username, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      return BulletinComment.fromMap(
        Map<String, dynamic>.from(row),
        profile: profileRow != null
            ? Map<String, dynamic>.from(profileRow)
            : null,
      );
    } catch (e, st) {
      debugPrint('addBulletinComment error: $e\n$st');
      return null;
    }
  }

  Future<bool> deleteBulletinComment(String commentId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      await _client
          .from('bulletin_post_comments')
          .delete()
          .eq('id', commentId)
          .eq('user_id', user.id);
      return true;
    } catch (e, st) {
      debugPrint('deleteBulletinComment error: $e\n$st');
      return false;
    }
  }
}
