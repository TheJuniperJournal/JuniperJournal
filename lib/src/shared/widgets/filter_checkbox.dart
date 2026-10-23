import 'package:flutter/material.dart';
import '../styling/app_colors.dart';

/// Shared appearance; callers retain single or multiple selection semantics.
class FilterCheckbox extends StatelessWidget {
  const FilterCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => Checkbox(
    value: value,
    onChanged: onChanged == null ? null : (value) => onChanged!(value ?? false),
    activeColor: AppColors.primary,
    checkColor: Colors.white,
    side: const BorderSide(color: AppColors.primary, width: 1.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}

/// Compact inline filter using the same checkbox as expanded filter menus.
class FilterCheckboxOption extends StatelessWidget {
  const FilterCheckboxOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.backgroundColor,
    this.selectedColor,
    this.side,
    this.shape,
    this.showCheckmark = true,
    this.checkmarkColor,
  });
  final Widget label;
  final bool selected, showCheckmark;
  final ValueChanged<bool>? onSelected;
  final Color? backgroundColor, selectedColor, checkmarkColor;
  final BorderSide? side;
  final OutlinedBorder? shape;
  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? (selectedColor ?? Colors.transparent)
        : (backgroundColor ?? Colors.transparent),
    shape:
        shape ??
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: side ?? const BorderSide(color: AppColors.borderLight),
        ),
    child: InkWell(
      customBorder:
          shape ??
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onSelected == null ? null : () => onSelected!(!selected),
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilterCheckbox(value: selected, onChanged: onSelected),
            label,
          ],
        ),
      ),
    ),
  );
}
