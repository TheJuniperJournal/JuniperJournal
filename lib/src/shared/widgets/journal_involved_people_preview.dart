import 'package:juniper_journal/src/shared/widgets/protected_image.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'package:flutter/material.dart';
import '../../backend/db/models/user_profile.dart';
import '../../backend/db/repositories/users_repo.dart';
import '../../features/home_page/pages/public_user_profile.dart';
import '../styling/app_colors.dart';
import '../styling/app_typography.dart';

class JournalInvolvedPeoplePreview extends StatefulWidget {
  const JournalInvolvedPeoplePreview({
    super.key,
    required this.people,
    this.usersRepo,
  });
  final List<Map> people;
  final UsersRepo? usersRepo;
  @override
  State<JournalInvolvedPeoplePreview> createState() =>
      _JournalInvolvedPeoplePreviewState();
}

class _JournalInvolvedPeoplePreviewState
    extends State<JournalInvolvedPeoplePreview> {
  late final Future<List<UserProfile>> _profiles = _load();
  Future<List<UserProfile>> _load() async {
    final ids = widget.people
        .map((person) => person['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return [];
    try {
      return await (widget.usersRepo ?? UsersRepo()).getProfilesByIds(ids);
    } catch (_) {
      return [];
    }
  }

  Widget _avatar(String? url, String name, double radius) => CircleAvatar(
    radius: radius,
    backgroundColor: AppColors.avatarBackground,
    child: ClipOval(
      child: url != null && url.isNotEmpty
          ? ProtectedImage.network(
              url,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.person, color: AppColors.avatarIcon, size: radius),
            )
          : Icon(Icons.person, color: AppColors.avatarIcon, size: radius * .9),
    ),
  );
  Future<void> _open(Map person, UserProfile? profile) async {
    final id = person['id']?.toString() ?? '';
    if (id.isEmpty) return;
    await pushAppRoute(
      context,
      MaterialPageRoute(
        builder: (_) => PublicUserProfilePage(userId: id, profile: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.people.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Who was Involved?', style: AppTypography.fieldLabel),
          const SizedBox(height: 12),
          FutureBuilder<List<UserProfile>>(
            future: _profiles,
            builder: (context, snapshot) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final person in widget.people)
                  Builder(
                    builder: (context) {
                      final matches = (snapshot.data ?? <UserProfile>[]).where(
                        (profile) => profile.id == person['id'],
                      );
                      final profile = matches.isEmpty ? null : matches.first;
                      final name =
                          profile?.resolvedDisplayName ??
                          person['name']?.toString() ??
                          'Member';
                      final avatar =
                          profile?.avatarUrl ??
                          person['avatarUrl']?.toString() ??
                          person['avatar_url']?.toString();
                      final clickable =
                          (person['id']?.toString() ?? '').isNotEmpty;
                      return ActionChip(
                        avatar: _avatar(avatar, name, 14),
                        label: Text(name, style: AppTypography.body),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.borderLight),
                        onPressed: clickable
                            ? () => _open(person, profile)
                            : null,
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
