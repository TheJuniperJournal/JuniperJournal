class UserProfile {
  final String id;
  final String bio;
  final String? displayName;
  final String? username;
  final String? avatarUrl;
  final bool isPublicProfile;
  final DateTime? birthday;

  const UserProfile({
    required this.id,
    this.bio = '',
    this.displayName,
    this.username,
    this.avatarUrl,
    this.isPublicProfile = true,
    this.birthday,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    id: map['id']?.toString() ?? '',
    bio: map['bio']?.toString() ?? '',
    displayName: map['display_name']?.toString(),
    username: map['username']?.toString(),
    avatarUrl: map['avatar_url']?.toString(),
    isPublicProfile: map['is_public_profile'] as bool? ?? true,
    birthday: map['birthday'] != null
        ? DateTime.tryParse(map['birthday'].toString())
        : null,
  );

  String get resolvedDisplayName {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!.trim();
    }
    if (username != null && username!.trim().isNotEmpty) {
      return '@${username!.trim()}';
    }
    return 'User';
  }
}
