import 'package:flutter/foundation.dart';
import 'package:juniper_journal/src/backend/db/models/friend_request.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/supabase_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FriendsRepo {
  static const table = 'friend_requests';
  static const profilesTable = 'profiles';

  SupabaseClient get _client => SupabaseDatabase.instance.client;

  Future<bool> canViewUserProjects({required String targetUserId}) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return false;
    if (currentUserId == targetUserId) return true;

    try {
      final profileRows = await _client
          .from(profilesTable)
          .select('is_public_profile')
          .eq('id', targetUserId)
          .limit(1);

      if (profileRows.isNotEmpty) {
        final isPublic =
            profileRows.first['is_public_profile'] as bool? ?? true;
        if (isPublic) return true;
      }

      final friendRows = await _client
          .from(table)
          .select('id')
          .or(
            'and(requester_id.eq.$currentUserId,addressee_id.eq.$targetUserId,status.eq.accepted),and(requester_id.eq.$targetUserId,addressee_id.eq.$currentUserId,status.eq.accepted)',
          )
          .limit(1);

      return friendRows.isNotEmpty;
    } catch (e, st) {
      debugPrint('canViewUserProjects error: $e\n$st');
      return false;
    }
  }

  Future<Map<String, String>> getRelationshipStatuses(
    List<String> otherUserIds,
  ) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null || otherUserIds.isEmpty) return {};

    final statusMap = {for (final id in otherUserIds) id: 'none'};

    try {
      final outgoingPending = await _client
          .from(table)
          .select('addressee_id')
          .eq('requester_id', currentUserId)
          .eq('status', 'pending')
          .inFilter('addressee_id', otherUserIds);

      for (final row in outgoingPending) {
        final id = row['addressee_id']?.toString();
        if (id != null) statusMap[id] = 'pending_outgoing';
      }

      final incomingPending = await _client
          .from(table)
          .select('requester_id')
          .eq('addressee_id', currentUserId)
          .eq('status', 'pending')
          .inFilter('requester_id', otherUserIds);

      for (final row in incomingPending) {
        final id = row['requester_id']?.toString();
        if (id != null) statusMap[id] = 'pending_incoming';
      }

      final acceptedOutgoing = await _client
          .from(table)
          .select('addressee_id')
          .eq('requester_id', currentUserId)
          .eq('status', 'accepted')
          .inFilter('addressee_id', otherUserIds);

      for (final row in acceptedOutgoing) {
        final id = row['addressee_id']?.toString();
        if (id != null) statusMap[id] = 'friends';
      }

      final acceptedIncoming = await _client
          .from(table)
          .select('requester_id')
          .eq('addressee_id', currentUserId)
          .eq('status', 'accepted')
          .inFilter('requester_id', otherUserIds);

      for (final row in acceptedIncoming) {
        final id = row['requester_id']?.toString();
        if (id != null) statusMap[id] = 'friends';
      }
    } catch (e, st) {
      debugPrint('getRelationshipStatuses error: $e\n$st');
      return {};
    }

    return statusMap;
  }

  Future<bool> sendFriendRequest({required String addresseeId}) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null || addresseeId == currentUserId) return false;

    try {
      final existing = await _client
          .from(table)
          .select('id, requester_id, addressee_id, status')
          .or(
            'and(requester_id.eq.$currentUserId,addressee_id.eq.$addresseeId),and(requester_id.eq.$addresseeId,addressee_id.eq.$currentUserId)',
          )
          .limit(1);

      if (existing.isNotEmpty) {
        final row = existing.first;
        final status = row['status']?.toString();
        final requester = row['requester_id']?.toString();

        if (status == 'accepted' ||
            (status == 'pending' && requester == currentUserId)) {
          return true;
        }

        if (status == 'pending' && requester == addresseeId) {
          final requestId = row['id']?.toString();
          if (requestId != null) {
            await _client
                .from(table)
                .update({'status': 'accepted'})
                .eq('id', requestId)
                .eq('addressee_id', currentUserId);
            return true;
          }
        }
      }

      await _client.from(table).insert({
        'requester_id': currentUserId,
        'addressee_id': addresseeId,
        'status': 'pending',
      });
      return true;
    } catch (e, st) {
      debugPrint('sendFriendRequest error: $e\n$st');
      return false;
    }
  }

  Future<bool> acceptFriendRequest({required String requesterId}) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return false;

    try {
      await _client
          .from(table)
          .update({'status': 'accepted'})
          .eq('requester_id', requesterId)
          .eq('addressee_id', currentUserId)
          .eq('status', 'pending');
      return true;
    } catch (e, st) {
      debugPrint('acceptFriendRequest error: $e\n$st');
      return false;
    }
  }

  Future<bool> declineFriendRequest({required String requesterId}) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return false;

    try {
      await _client
          .from(table)
          .update({'status': 'declined'})
          .eq('requester_id', requesterId)
          .eq('addressee_id', currentUserId)
          .eq('status', 'pending');
      return true;
    } catch (e, st) {
      debugPrint('declineFriendRequest error: $e\n$st');
      return false;
    }
  }

  Future<List<FriendRequest>?> getIncomingFriendRequests() async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return [];

    try {
      final requests = await _client
          .from(table)
          .select('requester_id, created_at')
          .eq('addressee_id', currentUserId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final requesterIds = requests
          .map((row) => row['requester_id']?.toString())
          .whereType<String>()
          .toList();

      if (requesterIds.isEmpty) return [];

      final profiles = await _client
          .from(profilesTable)
          .select('id, display_name, username, avatar_url')
          .inFilter('id', requesterIds);

      final profileById = {
        for (final row in profiles)
          row['id']?.toString() ?? '': Map<String, dynamic>.from(row),
      };

      return requests.map<FriendRequest>((requestRow) {
        final requesterId = requestRow['requester_id']?.toString() ?? '';
        final profile = profileById[requesterId] ?? const <String, dynamic>{};

        return FriendRequest.fromMap({
          'requester_id': requesterId,
          'created_at': requestRow['created_at'],
          'display_name': profile['display_name'],
          'username': profile['username'],
          'avatar_url': profile['avatar_url'],
        });
      }).toList();
    } catch (e, st) {
      debugPrint('getIncomingFriendRequests error: $e\n$st');
      return null;
    }
  }

  Future<bool> removeFriend({required String friendId}) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return false;

    try {
      // Run both directions in parallel. The friendship row exists in exactly
      // one direction, so one delete will hit a row and the other will be a
      // no-op. This also handles RLS policies that only allow deleting rows
      // where the current user is the requester.
      await Future.wait<void>([
        _client
            .from(table)
            .delete()
            .eq('requester_id', currentUserId)
            .eq('addressee_id', friendId),
        _client
            .from(table)
            .delete()
            .eq('requester_id', friendId)
            .eq('addressee_id', currentUserId),
      ]);
      return true;
    } catch (e, st) {
      debugPrint('removeFriend error: $e\n$st');
      return false;
    }
  }

  Future<List<UserProfile>?> getFriends() async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return [];

    return getVisibleFriendsForUser(currentUserId);
  }

  /// Uses existing row-level access: never broadens visibility of friendships.
  Future<List<UserProfile>?> getVisibleFriendsForUser(String userId) async {
    try {
      final outgoing = await _client
          .from(table)
          .select('addressee_id, created_at')
          .eq('requester_id', userId)
          .eq('status', 'accepted');

      final incoming = await _client
          .from(table)
          .select('requester_id, created_at')
          .eq('addressee_id', userId)
          .eq('status', 'accepted');

      final friendIds = <String>{
        ...outgoing
            .map((row) => row['addressee_id']?.toString())
            .whereType<String>(),
        ...incoming
            .map((row) => row['requester_id']?.toString())
            .whereType<String>(),
      }.toList();

      if (friendIds.isEmpty) return [];

      final profiles = await _client
          .from(profilesTable)
          .select('id, display_name, username, avatar_url')
          .inFilter('id', friendIds);

      return List<Map<String, dynamic>>.from(
        profiles,
      ).map(UserProfile.fromMap).toList();
    } catch (e, st) {
      debugPrint('getFriends error: $e\n$st');
      return null;
    }
  }
}
