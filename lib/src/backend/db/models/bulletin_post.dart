class BulletinPost {
  final String id;
  final String communityId;
  final String userId;
  final String title;
  final String category;
  final String body;
  final DateTime createdAt;
  final List<String> imageUrls;
  final int commentCount;

  // Resolved author info (joined at fetch time)
  final String? authorDisplayName;
  final String? authorUsername;
  final String? authorAvatarUrl;

  const BulletinPost({
    required this.id,
    required this.communityId,
    required this.userId,
    required this.title,
    required this.category,
    required this.body,
    required this.createdAt,
    this.imageUrls = const [],
    this.commentCount = 0,
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

  factory BulletinPost.fromMap(
    Map<String, dynamic> map, {
    Map<String, dynamic>? profile,
  }) {
    final rawUrls = map['image_urls'];
    final imageUrls = rawUrls is List
        ? List<String>.from(rawUrls.map((e) => e.toString()))
        : <String>[];
    return BulletinPost(
      id: map['id']?.toString() ?? '',
      communityId: map['community_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      imageUrls: imageUrls,
      commentCount: (map['comment_count'] as int?) ?? 0,
      authorDisplayName: profile?['display_name']?.toString(),
      authorUsername: profile?['username']?.toString(),
      authorAvatarUrl: profile?['avatar_url']?.toString(),
    );
  }
}
