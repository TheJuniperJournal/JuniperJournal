import 'package:flutter/material.dart';
import '../../backend/db/models/project.dart';
import '../../backend/db/models/user_profile.dart';
import '../styling/app_colors.dart';
import '../styling/app_typography.dart';
import 'item_action_menu.dart';
import '../../features/home_page/pages/public_user_profile.dart';

/// The same public project card for Explore, communities, and portfolios.
class ExploreProjectCard extends StatelessWidget {
  const ExploreProjectCard({
    super.key,
    required this.project,
    required this.onOpen,
    this.onBookmark,
    this.onDelete,
    this.people = const [],
    this.bookmarked = false,
    this.saving = false,
    this.entryCount,
  });
  final Project project;
  final VoidCallback onOpen;
  final VoidCallback? onBookmark;
  final Future<void> Function()? onDelete;
  final List<UserProfile> people;
  final bool bookmarked, saving;
  final int? entryCount;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: const Color(0x18000000),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 142,
                  width: double.infinity,
                  child: project.imageUrl?.isNotEmpty == true
                      ? Image.network(
                          project.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.projectName,
                      style: AppTypography.fieldLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'Bookmark project',
                      onPressed: saving ? null : onBookmark,
                      icon: Icon(
                        bookmarked ? Icons.bookmark : Icons.bookmark_border,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  if (onDelete != null)
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: ItemActionMenu(
                        deleteLabel: 'Delete Project',
                        onDelete: onDelete,
                      ),
                    ),
                  for (final person in people.take(2))
                    Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: GestureDetector(
                        onTap: () => openUserProfile(context, person.id),
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.primaryTint,
                          backgroundImage: person.avatarUrl?.isNotEmpty == true
                              ? NetworkImage(person.avatarUrl!)
                              : null,
                          child: person.avatarUrl?.isNotEmpty == true
                              ? null
                              : const Icon(Icons.person_outline, size: 12),
                        ),
                      ),
                    ),
                ],
              ),
              Text(
                '${entryCount ?? project.journalEntryCount} Journal Entries',
                style: AppTypography.helper,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _placeholder() => const ColoredBox(
    color: Color(0xFFE8F3EC),
    child: Center(
      child: Icon(Icons.landscape_outlined, color: AppColors.primary, size: 40),
    ),
  );
}
