import 'journal_preview_image.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import '../../features/home_page/pages/public_user_profile.dart';
import 'journal_entry_activity.dart';
import 'journal_involved_people_preview.dart';
import 'modal_actions.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/item_action_menu.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../backend/db/models/journal_entry.dart';

class JournalLogEntryCard extends StatelessWidget {
  const JournalLogEntryCard({
    super.key,
    required this.entry,
    required this.phaseLabel,
    required this.status,
    required this.onTap,
    this.imageUrl,
    this.imageUrls = const [],
    this.ecoPoints = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.projectLink,
    this.onDelete,
    this.onEdit,
  });
  final Widget? projectLink;
  final JournalEntry entry;
  final String phaseLabel;
  final Widget status;
  final VoidCallback onTap;
  final String? imageUrl;
  final List<String> imageUrls;
  List<String> get _previewImages => imageUrls.isNotEmpty
      ? imageUrls.take(2).toList()
      : [if (imageUrl != null) imageUrl!];
  final double ecoPoints;
  final int likeCount;
  final int commentCount;
  final VoidCallback? onDelete, onEdit;
  String get _displayTitle {
    final title = entry.title
        .replaceFirst(
          RegExp(r'^(?:Journal )?Entry:\s*', caseSensitive: false),
          '',
        )
        .trim();
    return title.isEmpty ? 'Untitled' : title;
  }

  String get _typeLabel => entry.isFreeNotes
      ? '$phaseLabel · Free Notes'
      : entry.prototypingTypeLabel?.toUpperCase() ?? phaseLabel;

  IconData get _phaseIcon => entry.isFreeNotes
      ? Icons.edit_note_outlined
      : switch (_typeLabel.toUpperCase()) {
          'BUILDING' => Icons.build_outlined,
          'TESTING' => Icons.science_outlined,
          'TECHNICAL ANALYSIS' => Icons.bar_chart_outlined,
          'PROTOTYPING' => Icons.build_circle_outlined,
          'IDEATING' => Icons.lightbulb_outline,
          'IMPLEMENTATION' => Icons.rocket_launch_outlined,
          _ => Icons.search,
        };
  static const _green = Color(0xFF5DB075);

  @override
  Widget build(BuildContext context) => AppTapTarget(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E5E5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_previewImages.isNotEmpty) ...[
            Row(
              children: [
                for (var i = 0; i < _previewImages.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 160,
                        child: JournalPreviewImage(
                          _previewImages[i],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 28,
                height: 34,
                child: CustomPaint(painter: _JournalLogIconPainter()),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_phaseIcon, size: 15, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                _typeLabel,
                                style: const TextStyle(
                                  fontFamily: AppTypography.bodyFamily,
                                  color: Colors.white,
                                  fontSize: AppTypography.captionSize,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: .4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        status,
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTypography.headingFamily,
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.sectionTitleSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Journal Entry${entry.createdAt == null ? '' : ' • ${DateFormat('EEEE, MMM d').format(entry.createdAt!.toLocal())}'}',
                      style: const TextStyle(
                        color: Color(0xFFA1A1A1),
                        fontSize: AppTypography.helperSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              if (onDelete != null)
                SizedBox(
                  width: 32,
                  height: 32,
                  child: ItemActionMenu(
                    onEdit: onEdit ?? onTap,
                    onDelete: onDelete,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFD0D0D0)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _author(context),
                    if (entry.contributorCount > 0) ...[
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _contributors(context),
                      ),
                    ],
                  ],
                ),
              ),
              _footerDivider(),
              Flexible(
                flex: 6,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [_activities(), _footerDivider(), _ecoPoints()],
                  ),
                ),
              ),
            ],
          ),
          if (projectLink != null) projectLink!,
        ],
      ),
    ),
  );
  Widget _author(BuildContext context) => AppTapTarget(
    onTap: entry.authorId == null
        ? null
        : () => openUserProfile(context, entry.authorId!),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFE8F1EB),
          backgroundImage: entry.authorAvatarUrl?.isNotEmpty == true
              ? NetworkImage(entry.authorAvatarUrl!)
              : null,
          child: entry.authorAvatarUrl?.isNotEmpty == true
              ? null
              : const Icon(Icons.person_outline, size: 18, color: _green),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Post by',
                style: TextStyle(
                  color: Color(0xFFA1A1A1),
                  fontSize: AppTypography.captionSize,
                ),
              ),
              Text(
                entry.authorDisplayName?.trim().isNotEmpty == true
                    ? entry.authorDisplayName!
                    : 'Author',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.helperSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _contributors(BuildContext context) => AppTapTarget(
    behavior: HitTestBehavior.opaque,
    onTap: () => showAppDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('Contributors')),
            IconButton(
              tooltip: 'Close contributors',
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: JournalInvolvedPeoplePreview(people: _people()),
          ),
        ),
      ),
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E0E0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/project_setup/project_collaborative.svg',
            width: 16,
            height: 16,
            colorFilter: const ColorFilter.mode(
              Color(0xFF717171),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '+ ${entry.contributorCount} ${entry.contributorCount == 1 ? 'contributor' : 'contributors'}',
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFF717171),
              fontSize: AppTypography.captionSize,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _footerDivider() => const SizedBox(
    height: 36,
    child: VerticalDivider(width: 18, thickness: 1, color: Color(0xFFD0D0D0)),
  );

  Widget _ecoPoints() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SvgPicture.asset(
        'assets/project_setup/card_eco_leaf.svg',
        width: 32,
        height: 32,
      ),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ecoPoints == ecoPoints.roundToDouble()
                ? ecoPoints.toInt().toString()
                : ecoPoints.toStringAsFixed(1),
            style: const TextStyle(fontSize: 20, color: Color(0xFF222222)),
          ),
          const Text(
            'EcoPoints',
            style: TextStyle(fontSize: 12, color: Color(0xFF777777)),
          ),
        ],
      ),
    ],
  );

  List<Map> _people() {
    final people = <String, Map>{};
    void walk(dynamic node) {
      if (node is List) {
        for (final item in node) {
          walk(item);
        }
      }
      if (node is Map) {
        for (final item in node.entries) {
          if (['involved', 'involvedIds', 'involved_ids'].contains(item.key) &&
              item.value is List) {
            for (final person in item.value) {
              final map = person is Map ? person : {'id': person.toString()};
              final id = (map['id'] ?? map['user_id'] ?? map['name'])
                  ?.toString();
              if (id != null && id != entry.authorId)
                people[id] = {
                  ...map,
                  'id': map['id'] ?? map['user_id'] ?? '',
                  'name': map['name'] ?? 'Member',
                };
            }
          } else {
            walk(item.value);
          }
        }
      }
    }

    walk(entry.content);
    return people.values.toList();
  }

  Widget _activities() => JournalEntryActivity(
    entryId: entry.id,
    likes: likeCount,
    comments: commentCount,
  );
}

class _JournalLogIconPainter extends CustomPainter {
  const _JournalLogIconPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = JournalLogEntryCard._green
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
        const Radius.circular(3),
      ),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(6, 1)
        ..lineTo(6, 12)
        ..lineTo(9, 9)
        ..lineTo(12, 12)
        ..lineTo(12, 1),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
