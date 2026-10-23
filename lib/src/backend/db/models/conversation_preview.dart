class ConversationPreview {
  final String conversationId;
  final bool isGroup;
  final String? groupName;
  // DM-only fields
  final String? otherUserId;
  final String? otherDisplayName;
  final String? otherUsername;
  final String? otherAvatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime? myDeletedAt;

  const ConversationPreview({
    required this.conversationId,
    this.isGroup = false,
    this.groupName,
    this.otherUserId,
    this.otherDisplayName,
    this.otherUsername,
    this.otherAvatarUrl,
    this.lastMessage,
    this.lastMessageAt,
    required this.unreadCount,
    this.myDeletedAt,
  });

  String get resolvedDisplayName {
    if (isGroup) return groupName ?? 'Group';
    if (otherDisplayName != null && otherDisplayName!.trim().isNotEmpty) {
      return otherDisplayName!.trim();
    }
    if (otherUsername != null && otherUsername!.trim().isNotEmpty) {
      return '@${otherUsername!.trim()}';
    }
    return 'User';
  }

  factory ConversationPreview.fromMap(Map<String, dynamic> map) =>
      ConversationPreview(
        conversationId: map['conversation_id']?.toString() ?? '',
        isGroup: map['is_group'] == true,
        groupName: map['group_name']?.toString(),
        otherUserId: map['other_user_id']?.toString(),
        otherDisplayName: map['other_display_name']?.toString(),
        otherUsername: map['other_username']?.toString(),
        otherAvatarUrl: map['other_avatar_url']?.toString(),
        lastMessage: map['last_message']?.toString(),
        lastMessageAt: DateTime.tryParse(
          map['last_message_at']?.toString() ?? '',
        ),
        unreadCount: (map['unread_count'] as num?)?.toInt() ?? 0,
        myDeletedAt: DateTime.tryParse(map['my_deleted_at']?.toString() ?? ''),
      );

  /// Constructs a ConversationPreview from the group_dms RPC result.
  factory ConversationPreview.fromGroupDmMap(Map<String, dynamic> map) =>
      ConversationPreview(
        conversationId: map['conversation_id']?.toString() ?? '',
        isGroup: true,
        groupName: map['group_name']?.toString(),
        lastMessage: map['last_message']?.toString(),
        lastMessageAt: DateTime.tryParse(
          map['last_message_at']?.toString() ?? '',
        ),
        unreadCount: (map['unread_count'] as num?)?.toInt() ?? 0,
      );
}
