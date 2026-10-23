class BulletinComment {
  final String id;
  final String postId;
  final String userId;
  final String body;
  final DateTime createdAt;

  final String? authorDisplayName;
  final String? authorUsername;
  final String? authorAvatarUrl;

  const BulletinComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.body,
    required this.createdAt,
    this.authorDisplayName,
    this.authorUsername,
    this.authorAvatarUrl,
  });

  String get authorLabel {
    final d = authorDisplayName?.trim();
    final u = authorUsername?.trim();
    if (d != null && d.isNotEmpty) return d;
    if (u != null && u.isNotEmpty) return '@$u';
    return 'Member';
  }

  factory BulletinComment.fromMap(
    Map<String, dynamic> map, {
    Map<String, dynamic>? profile,
  }) {
    return BulletinComment(
      id: map['id']?.toString() ?? '',
      postId: map['post_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      authorDisplayName: profile?['display_name']?.toString(),
      authorUsername: profile?['username']?.toString(),
      authorAvatarUrl: profile?['avatar_url']?.toString(),
    );
  }
}
