import 'package:flutter/material.dart';
import '../styling/app_colors.dart';
import '../styling/app_typography.dart';

/// A card footer with the same inset as the entry content.
class JournalProjectLink extends StatelessWidget {
  const JournalProjectLink({
    super.key,
    required this.projectName,
    required this.onTap,
    this.topPadding = 12,
  });
  final double topPadding;
  final String projectName;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: topPadding),
    child: Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        button: true,
        label: 'View project: $projectName',
        excludeSemantics: true,
        onTap: onTap,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View Project',
                  style: AppTypography.helper.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward,
                  size: 18,
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
