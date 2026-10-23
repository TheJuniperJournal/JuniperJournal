class CommunityInvite {
  final String id;
  final String communityId;
  final String communityName;
  final String? communityImageUrl;
  final String? inviterDisplayName;
  final String? inviterUsername;
  final String status;

  const CommunityInvite({
    required this.id,
    required this.communityId,
    required this.communityName,
    this.communityImageUrl,
    this.inviterDisplayName,
    this.inviterUsername,
    required this.status,
  });

  String get inviterLabel {
    if (inviterDisplayName != null && inviterDisplayName!.trim().isNotEmpty) {
      return inviterDisplayName!.trim();
    }
    if (inviterUsername != null && inviterUsername!.trim().isNotEmpty) {
      return '@${inviterUsername!.trim()}';
    }
    return 'Someone';
  }

  factory CommunityInvite.fromMap(Map<String, dynamic> map) => CommunityInvite(
    id: map['id']?.toString() ?? '',
    communityId: map['community_id']?.toString() ?? '',
    communityName: map['community_name']?.toString() ?? '',
    communityImageUrl: map['community_image_url']?.toString(),
    inviterDisplayName: map['inviter_display_name']?.toString(),
    inviterUsername: map['inviter_username']?.toString(),
    status: map['status']?.toString() ?? 'pending',
  );
}
