class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String? senderDisplayName;
  final String? senderUsername;
  final String? senderAvatarUrl;
  final String content;
  final DateTime createdAt;
  final DateTime? readAt;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderDisplayName,
    this.senderUsername,
    this.senderAvatarUrl,
    required this.content,
    required this.createdAt,
    this.readAt,
  });

  String get resolvedSenderName {
    if (senderDisplayName != null && senderDisplayName!.trim().isNotEmpty) {
      return senderDisplayName!.trim();
    }
    if (senderUsername != null && senderUsername!.trim().isNotEmpty) {
      return '@${senderUsername!.trim()}';
    }
    return 'User';
  }

  factory Message.fromMap(Map<String, dynamic> map) => Message(
    id: map['id']?.toString() ?? '',
    conversationId: map['conversation_id']?.toString() ?? '',
    senderId: map['sender_id']?.toString() ?? '',
    senderDisplayName: map['sender_display_name']?.toString(),
    senderUsername: map['sender_username']?.toString(),
    senderAvatarUrl: map['sender_avatar_url']?.toString(),
    content: map['content']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(map['created_at']?.toString() ?? '') ??
        DateTime.now(),
    readAt: map['read_at'] != null
        ? DateTime.tryParse(map['read_at'].toString())
        : null,
  );
}
