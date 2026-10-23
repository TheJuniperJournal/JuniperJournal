import 'journal_choice_dialog.dart';
import 'package:flutter/material.dart';
import '../../../shared/styling/app_colors.dart';
import '../../../shared/styling/app_typography.dart';
import '../../../shared/widgets/modal_actions.dart';

Future<String?> chooseJournalPhase(
  BuildContext context, {
  required String selectedPhase,
  required String projectName,
}) => showAppDialog<String>(
  context: context,
  builder: (context) => JournalChoiceDialog(
    title: projectName,
    closeTooltip: 'Back to projects',
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const Text('Choose Phase', style: AppTypography.fieldLabel),
          const SizedBox(height: 8),
          const Text(
            'Which phase is this entry for? It will appear in that phase’s dashboard.',
            textAlign: TextAlign.center,
            style: AppTypography.helper,
          ),
          const SizedBox(height: 20),
          for (final phase in const [
            (
              'discover',
              'Discovery',
              Icons.search_outlined,
              'Observe, explore, and ask questions.',
            ),
            (
              'ideating',
              'Ideation',
              Icons.lightbulb_outline,
              'Develop ideas and compare possible solutions.',
            ),
            (
              'prototyping',
              'Prototyping',
              Icons.build_outlined,
              'Build, test, and analyze your ideas.',
            ),
            (
              'implementation',
              'Implementation',
              Icons.rocket_launch_outlined,
              'Document outcomes, impact, and reflection.',
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: phase.$1 == selectedPhase
                    ? AppColors.primary.withValues(alpha: .08)
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.primary),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Icon(phase.$3, color: AppColors.primary),
                  title: Text(phase.$2, style: AppTypography.fieldLabel),
                  subtitle: Text(phase.$4, style: AppTypography.helper),
                  trailing: Icon(
                    phase.$1 == selectedPhase
                        ? Icons.check_circle_outline
                        : Icons.chevron_right,
                    color: AppColors.primary,
                  ),
                  onTap: () => Navigator.pop(context, phase.$1),
                ),
              ),
            ),
        ],
      ),
    ),
  ),
);
