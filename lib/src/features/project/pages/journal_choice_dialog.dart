import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'package:flutter/material.dart';
import '../../../shared/styling/app_typography.dart';

/// Shared bounds keep the journal creation steps stable as their content changes.
class JournalChoiceDialog extends StatelessWidget {
  const JournalChoiceDialog({
    super.key,
    required this.child,
    required this.title,
    this.closeTooltip = 'Close',
    this.centerContent = false,
  });
  final Widget child;
  final String title, closeTooltip;
  final bool centerContent;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      key: const ValueKey('journal-choice-frame'),
      width: 440,
      height: 560,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    key: const ValueKey('journal-choice-close'),
                    tooltip: closeTooltip,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 24),
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTypography.sectionTitle,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: LayoutBuilder(
                builder: (context, constraints) => PageScrollWithFooter(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Align(
                        alignment: centerContent
                            ? Alignment.center
                            : Alignment.topCenter,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
