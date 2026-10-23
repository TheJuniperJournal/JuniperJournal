import 'journal_choice_dialog.dart';
import 'package:flutter/material.dart';
import '../../../shared/styling/app_colors.dart';
import '../../../shared/styling/app_typography.dart';
import '../../../shared/widgets/modal_actions.dart';

enum JournalType { guided, freeNotes }

Future<JournalType?> chooseJournalType(BuildContext context) =>
    showAppDialog<JournalType>(
      context: context,
      builder: (context) => JournalChoiceDialog(
        title: 'Journal Type',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'How would you like to capture this entry?',
                textAlign: TextAlign.center,
                style: AppTypography.helper,
              ),
              const SizedBox(height: 28),
              const _Choice(
                type: JournalType.guided,
                icon: Icons.signpost_outlined,
                title: 'Guided',
                description: 'Step-by-step prompts for this phase.',
                recommended: true,
              ),
              const SizedBox(height: 16),
              const _Choice(
                type: JournalType.freeNotes,
                icon: Icons.edit_note_outlined,
                title: 'Free Notes',
                description:
                    'An open canvas for text, photos, tables, and ideas.',
              ),
            ],
          ),
        ),
      ),
    );

class _Choice extends StatelessWidget {
  const _Choice({
    required this.type,
    required this.icon,
    required this.title,
    required this.description,
    this.recommended = false,
  });
  final JournalType type;
  final bool recommended;
  final IconData icon;
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.primary),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pop(context, type),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 144),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 28, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (recommended) ...[
                        Text(
                          'Recommended',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(title, style: AppTypography.fieldLabel),
                      const SizedBox(height: 6),
                      Text(description, style: AppTypography.helper),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  size: 24,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
