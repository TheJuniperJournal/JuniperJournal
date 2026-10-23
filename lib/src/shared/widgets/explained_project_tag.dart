import 'package:flutter/material.dart';
import '../styling/app_colors.dart';
import '../styling/app_typography.dart';
import 'modal_actions.dart';
import 'project_filter_sheet.dart';

class ExplainedProjectTag extends StatelessWidget {
  const ExplainedProjectTag({
    super.key,
    required this.label,
    required this.child,
    this.isPhase = false,
  });
  final String label;
  final Widget child;
  final bool isPhase;

  FilterOption? get _option {
    if (!isPhase)
      return kSubjectOptions
          .where((o) => o.label.toLowerCase() == label.toLowerCase())
          .firstOrNull;
    final index = switch (label.toLowerCase()) {
      'discovery' || 'discover' || 'discovering' => 0,
      'ideation' || 'ideating' => 1,
      'prototyping' => 2,
      'implementation' || 'implemented' => 3,
      _ => -1,
    };
    return index < 0 ? null : kPhaseOptions[index];
  }

  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: const StadiumBorder(),
    ),
    onPressed: () => showAppDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        constraints: const BoxConstraints(maxWidth: 440),
        title: Row(
          children: [
            Icon(
              _option?.icon ?? Icons.menu_book_outlined,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppTypography.sectionTitle)),
            IconButton(
              tooltip: 'Close explanation',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: Text(
          _option?.description ??
              'A journal records observations, ideas, progress, and learning throughout a project.',
        ),
      ),
    ),
    child: child,
  );
}
