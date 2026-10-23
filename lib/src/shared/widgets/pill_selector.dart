import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';

/// A green-outlined pill button that opens a bottom-sheet picker.
/// [compact] = true → wraps content width; false (default) → full width.
class PillSelector extends StatelessWidget {
  const PillSelector({
    super.key,
    required this.value,
    required this.placeholder,
    required this.items,
    required this.onChanged,
    this.compact = false,
  });

  final String? value;
  final String placeholder;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final disabled = items.isEmpty;
    final labelColor = hasValue
        ? AppColors.primary
        : disabled
        ? Colors.grey.shade400
        : AppColors.primary.withValues(alpha: 0.55);

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: disabled ? Colors.grey.shade300 : AppColors.primary,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (!compact)
            Expanded(
              child: Text(
                value ?? placeholder,
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: labelColor,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            Flexible(
              child: Text(
                value ?? placeholder,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: labelColor,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down,
            color: disabled ? Colors.grey.shade300 : AppColors.primary,
            size: 18,
          ),
        ],
      ),
    );

    if (disabled) return compact ? IntrinsicWidth(child: pill) : pill;

    final tappable = Builder(
      builder: (ctx) =>
          AppTapTarget(onTap: () => _showDropdown(ctx), child: pill),
    );

    return compact ? IntrinsicWidth(child: tappable) : tappable;
  }

  void _showDropdown(BuildContext context) {
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final pillTopLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final pillBottomRight = box.localToGlobal(
      box.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final rect = RelativeRect.fromRect(
      Rect.fromPoints(pillTopLeft, pillBottomRight),
      Offset.zero & overlay.size,
    );

    // Cap menu width so it never extends beyond the right edge of the screen,
    // preventing Flutter from shifting it left and covering adjacent widgets.
    final maxWidth = (overlay.size.width - pillTopLeft.dx - 8).clamp(
      box.size.width,
      overlay.size.width,
    );

    showMenu<String>(
      context: context,
      position: rect,
      constraints: BoxConstraints(minWidth: box.size.width, maxWidth: maxWidth),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primary, width: 1),
      ),
      items: items
          .map(
            (item) => PopupMenuItem<String>(
              value: item,
              child: Container(
                decoration: item == value
                    ? BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                padding: item == value
                    ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
                    : EdgeInsets.zero,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: AppTypography.bodySize,
                          color: item == value
                              ? AppColors.primary
                              : Colors.black87,
                          fontWeight: item == value
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (item == value)
                      const Icon(
                        Icons.check,
                        size: 16,
                        color: AppColors.primary,
                      ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    ).then((selected) {
      if (selected != null) onChanged(selected);
    });
  }
}
