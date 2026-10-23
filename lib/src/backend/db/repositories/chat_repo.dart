import 'package:flutter/foundation.dart';
import 'package:juniper_journal/src/backend/db/models/conversation_preview.dart';
import 'package:juniper_journal/src/backend/db/models/message.dart';
import 'package:juniper_journal/src/backend/db/supabase_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRepo {
  SupabaseClient get _client => SupabaseDatabase.instance.client;

  Future<List<ConversationPreview>?> getConversations() async {
    try {
      final results = await Future.wait([
        _client.rpc('get_my_conversations'),
        _client.rpc('get_group_dms'),
      ]);

      final dms = List<Map<String, dynamic>>.from(
        results[0] as List,
      ).map(ConversationPreview.fromMap).toList();

      final groups = List<Map<String, dynamic>>.from(
        results[1] as List,
      ).map(ConversationPreview.fromGroupDmMap).toList();

      final merged = [...dms, ...groups];
      merged.sort((a, b) {
        final aTime = a.lastMessageAt ?? DateTime(0);
        final bTime = b.lastMessageAt ?? DateTime(0);
        return bTime.compareTo(aTime);
      });
      return merged;
    } catch (e, st) {
      debugPrint('getConversations error: $e\n$st');
      return null;
    }
  }

  Future<String?> createGroupDm({
    required String name,
    required List<String> memberIds,
  }) async {
    try {
      final data = await _client.rpc(
        'create_group_dm',
        params: {'p_name': name, 'p_member_ids': memberIds},
      );
      return data?.toString();
    } catch (e, st) {
      debugPrint('createGroupDm error: $e\n$st');
      return null;
    }
  }

  Future<bool> renameGroupDm({
    required String conversationId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 80) return false;
    try {
      await _client.rpc(
        'rename_group_dm',
        params: {'p_conversation_id': conversationId, 'p_name': trimmed},
      );
      return true;
    } catch (e) {
      debugPrint('renameGroupDm error: $e');
      return false;
    }
  }

  Future<String?> getOrCreateDm(String otherUserId) async {
    try {
      final data = await _client.rpc(
        'get_or_create_dm',
        params: {'other_user_id': otherUserId},
      );
      return data?.toString();
    } catch (e, st) {
      debugPrint('getOrCreateDm error: $e\n$st');
      return null;
    }
  }

  Future<List<Message>?> getMessages(String conversationId) async {
    try {
      final data = await _client.rpc(
        'get_conversation_messages',
        params: {'conv_id': conversationId},
      );
      return List<Map<String, dynamic>>.from(
        data as List,
      ).map(Message.fromMap).toList();
    } catch (e, st) {
      debugPrint('getMessages error: $e\n$st');
      return null;
    }
  }

  Future<bool> sendMessage(String conversationId, String content) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return false;
    try {
      await _client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': currentUserId,
        'content': content,
      });
      return true;
    } catch (e, st) {
      debugPrint('sendMessage error: $e\n$st');
      return false;
    }
  }

  Stream<List<Message>> streamMessages(String conversationId) async* {
    while (_client.auth.currentUser != null) {
      final messages = await getMessages(conversationId);
      if (messages != null) yield messages;
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  Future<bool> deleteConversation(String conversationId) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return false;
    try {
      await _client.from('conversation_deletions').upsert({
        'conversation_id': conversationId,
        'user_id': currentUserId,
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e, st) {
      debugPrint('deleteConversation error: $e\n$st');
      return false;
    }
  }

  Future<void> markAsRead(String conversationId) async {
    try {
      await _client.rpc(
        'mark_conversation_read',
        params: {'conv_id': conversationId},
      );
    } catch (e, st) {
      debugPrint('markAsRead error: $e\n$st');
    }
  }

  Future<int> getUnreadCount(String conversationId) async {
    try {
      final data = await _client.rpc(
        'get_conversation_unread_count',
        params: {'p_conv_id': conversationId},
      );
      return (data as num?)?.toInt() ?? 0;
    } catch (e, st) {
      debugPrint('getUnreadCount error: $e\n$st');
      return 0;
    }
  }

  // ── Group / community chat ──────────────────────────────────────────────────

  Future<List<Message>?> getCommunityMessages(String conversationId) async {
    try {
      final data = await _client.rpc(
        'get_community_messages',
        params: {'p_conv_id': conversationId},
      );
      return List<Map<String, dynamic>>.from(
        data as List,
      ).map(Message.fromMap).toList();
    } catch (e, st) {
      debugPrint('getCommunityMessages error: $e\n$st');
      return null;
    }
  }

  Stream<List<Message>> streamCommunityMessages(String conversationId) async* {
    while (true) {
      final messages = await getCommunityMessages(conversationId);
      if (messages != null) yield messages;
      await Future.delayed(const Duration(seconds: 3));
    }
  }
}
