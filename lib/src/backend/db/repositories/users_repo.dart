import 'package:flutter/foundation.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/supabase_database.dart';
import 'package:juniper_journal/src/backend/security/input_validator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsersRepo {
  UsersRepo({SupabaseClient? client}) : _providedClient = client;
  final SupabaseClient? _providedClient;
  static const profilesTable = 'profiles';

  SupabaseClient get _client =>
      _providedClient ?? SupabaseDatabase.instance.client;

  Map<String, dynamic> _profileSeedDataFromUser(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final data = <String, dynamic>{'id': user.id, 'is_public_profile': true};

    final username = metadata['username']?.toString().trim().toLowerCase();
    if (username != null && username.isNotEmpty) {
      data['username'] = username;
    }

    final displayName = metadata['display_name']?.toString().trim();
    if (displayName != null && displayName.isNotEmpty) {
      data['display_name'] = displayName;
    }

    final birthday = metadata['birthday']?.toString().trim();
    if (birthday != null && birthday.isNotEmpty) {
      data['birthday'] = birthday;
    }

    return data;
  }

  Future<UserProfile?> getCurrentUserProfile() async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return null;

    try {
      final rows = await _client
          .from(profilesTable)
          .select('*')
          .eq('id', currentUserId)
          .limit(1);

      if (rows.isEmpty) return null;
      return UserProfile.fromMap(Map<String, dynamic>.from(rows.first));
    } catch (e, st) {
      debugPrint('getCurrentUserProfile error: $e\n$st');
      return null;
    }
  }

  /// Creates or updates the current user's profile row.
  /// Call this after a successful signup to store the username.
  Future<void> upsertCurrentUserProfile({
    String? username,
    String? displayName,
    DateTime? birthday,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final data = _profileSeedDataFromUser(user);
      if (username != null && username.trim().isNotEmpty) {
        data['username'] = username.trim().toLowerCase();
      }
      if (displayName != null && displayName.trim().isNotEmpty) {
        data['display_name'] = displayName.trim();
      }
      if (birthday != null) {
        data['birthday'] = birthday.toIso8601String().split('T').first;
      }
      await _client.from(profilesTable).upsert(data, onConflict: 'id');
    } catch (e, st) {
      debugPrint('upsertCurrentUserProfile error: $e\n$st');
    }
  }

  /// Returns true if [username] is not already taken.
  /// Fails open (returns true) on errors to avoid blocking signup.
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final rows = await _client
          .from(profilesTable)
          .select('id')
          .eq('username', username.trim().toLowerCase())
          .limit(1);
      return rows.isEmpty;
    } catch (e, st) {
      debugPrint('isUsernameAvailable error: $e\n$st');
      return true;
    }
  }

  /// Inserts a profile row if one doesn't already exist.
  /// Safe to call on login — never overwrites existing data.
  Future<void> ensureProfileExists() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client
          .from(profilesTable)
          .upsert(
            _profileSeedDataFromUser(user),
            onConflict: 'id',
            ignoreDuplicates: true,
          );
    } catch (e, st) {
      debugPrint('ensureProfileExists error: $e\n$st');
    }
  }

  Future<bool> updateCurrentUserProfile({
    String? avatarUrl,
    String? bio,
    String? displayName,
    bool? isPublicProfile,
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return false;

    if (displayName != null) {
      final nameErr = InputValidator.displayName(displayName);
      if (nameErr != null) return false;
    }

    final data = <String, dynamic>{};
    if (bio != null) {
      if (bio.trim().length > 500) return false;
      data['bio'] = bio.trim();
    }
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    if (displayName != null) data['display_name'] = displayName.trim();
    if (isPublicProfile != null) data['is_public_profile'] = isPublicProfile;

    if (data.isEmpty) return true;

    try {
      await _client.from(profilesTable).update(data).eq('id', currentUserId);
      return true;
    } catch (e, st) {
      debugPrint('updateCurrentUserProfile error: $e\n$st');
      return false;
    }
  }

  Future<List<UserProfile>> getProfilesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final rows = await _client.rpc(
        'user_profile_cards',
        params: {'p_ids': ids},
      );
      return List<Map<String, dynamic>>.from(
        rows,
      ).map(UserProfile.fromMap).toList();
    } catch (e, st) {
      debugPrint('getProfilesByIds error: $e\n$st');
      return [];
    }
  }

  Future<List<UserProfile>?> searchPublicUsers({required String query}) async {
    final queryErr = InputValidator.searchQuery(query);
    if (queryErr != null) return null;

    try {
      // Search includes private accounts, but returns directory identity only.
      final rows = await _client.rpc(
        'search_user_directory',
        params: {'p_query': query.trim()},
      );
      return List<Map<String, dynamic>>.from(
        rows,
      ).map(UserProfile.fromMap).toList();
    } catch (e, st) {
      debugPrint('searchPublicUsers error: $e\n$st');
      return null;
    }
  }

  Future<List<UserProfile>?> searchProjectInvitees({
    required String query,
  }) async {
    return searchPublicUsers(query: query);
  }
}
