import 'desktop_content_width.dart';
import 'package:juniper_journal/src/shared/widgets/optional_field_label.dart';
import '../styling/app_colors.dart';
import '../styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:flutter/material.dart';

/// Shared geometry for journal pages and their stage content.
abstract final class JournalPageLayout {
  static const contentWidth = 444.0;
  static const desktopContentWidth = 720.0;

  /// Use the browser width: the persistent desktop shell gives pages a
  /// narrower center column while retaining the full-window MediaQuery.
  static double widthFor(
    BuildContext context, {
    double mobileWidth = contentWidth,
  }) => MediaQuery.sizeOf(context).width >= 1000
      ? (DesktopContentWidth.of(context) ?? desktopContentWidth).clamp(
          0.0,
          desktopContentWidth,
        )
      : mobileWidth;
  static const horizontalInset = 40.0;
  static const stageGap = 30.0;
  static const sectionGap = AppMetrics.fieldGap;
  static const pagePadding = EdgeInsets.fromLTRB(
    horizontalInset,
    0,
    horizontalInset,
    AppMetrics.pageBottomPadding,
  );
  static const stagePadding = EdgeInsets.fromLTRB(
    horizontalInset,
    stageGap,
    horizontalInset,
    AppMetrics.pageBottomPadding,
  );
}

/// A section title always begins at the same edge as its prompts and inputs.
class JournalSectionHeader extends StatelessWidget {
  const JournalSectionHeader({
    super.key,
    required this.title,
    this.description,
  });
  final String title;
  final String? description;
  static const titleStyle = AppTypography.sectionTitle;
  static const descriptionStyle = AppTypography.helper;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: JournalPageLayout.sectionGap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        OptionalFieldLabel(
          title,
          style: title.toLowerCase().startsWith('evidence')
              ? AppTypography.evidenceTitle
              : titleStyle.copyWith(color: AppColors.primary),
          textAlign: TextAlign.start,
        ),
        if (description != null) ...[
          const SizedBox(height: 8),
          Text(
            description!,
            style: descriptionStyle,
            textAlign: TextAlign.start,
          ),
        ],
      ],
    ),
  );
}
