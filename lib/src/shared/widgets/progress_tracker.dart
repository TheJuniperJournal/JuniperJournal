import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:flutter/material.dart';
import '../styling/app_colors.dart';
import '../styling/app_typography.dart';

/// Shared progress visuals; omitting [onSelected] makes it informational only.
class ProgressTracker extends StatelessWidget {
  const ProgressTracker({
    super.key,
    required this.labels,
    required this.reachedIndices,
    this.currentIndex,
    this.onSelected,
    this.showCurrentIndicator = true,
    this.requireCompletionForHighlight = false,
  });
  final List<String> labels;
  final Set<int> reachedIndices;
  final int? currentIndex;
  final ValueChanged<int>? onSelected;
  final bool showCurrentIndicator;
  final bool requireCompletionForHighlight;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 82,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = constraints.maxWidth / labels.length;
        return Stack(
          children: [
            Positioned(
              left: columnWidth / 2,
              right: columnWidth / 2,
              top: 16,
              child: const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFD9D9D9),
              ),
            ),
            Row(
              children: [
                for (var index = 0; index < labels.length; index++)
                  Expanded(child: _step(index, context)),
              ],
            ),
          ],
        );
      },
    ),
  );

  Widget _step(int index, BuildContext context) {
    final reached = reachedIndices.contains(index);
    final content = Semantics(
      button: onSelected != null,
      selected: currentIndex == index,
      label:
          '${labels[index]}, ${currentIndex == index
              ? 'current section'
              : reached
              ? (requireCompletionForHighlight ? 'completed' : 'visited')
              : 'not visited'}',
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            key: ValueKey('stage-visited-$index'),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: reached ? AppColors.primary : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: reached ? AppColors.primary : const Color(0xFFB7D7BF),
              ),
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  labels[index],
                  key: ValueKey('stage-label-$index'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.helperSize,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
                if (showCurrentIndicator) ...[
                  const SizedBox(height: 4),
                  Container(
                    key: ValueKey('stage-current-$index'),
                    height: 3,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: currentIndex == index
                          ? (!requireCompletionForHighlight || reached
                                ? AppColors.primary
                                : const Color(0xFFD9D9D9))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (onSelected == null) return content;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AppTapTarget(
        showHoverHighlight: false,
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelected!(index),
        child: content,
      ),
    );
  }
}
