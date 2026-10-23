import 'package:flutter/material.dart';
import '../styling/app_colors.dart';
import '../styling/app_typography.dart';

/// One visual convention for optional inputs, without changing validation.
class OptionalFieldLabel extends StatelessWidget {
  const OptionalFieldLabel(
    this.label, {
    super.key,
    this.optional = false,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });
  final String label;
  final bool optional;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  @override
  Widget build(BuildContext context) {
    final suffix = RegExp(r'\s*\(optional\)\s*$', caseSensitive: false);
    final isOptional = optional || suffix.hasMatch(label);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: label.replaceFirst(suffix, '')),
          if (isOptional)
            const TextSpan(
              text: ' (optional)',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
      style: style ?? AppTypography.fieldLabel,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
