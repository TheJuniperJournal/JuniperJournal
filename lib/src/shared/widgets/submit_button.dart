import '../styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:flutter/material.dart';

class SubmitButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color? foregroundColor;
  final double height;
  final BorderRadius borderRadius;

  const SubmitButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
    required this.backgroundColor,
    this.foregroundColor,
    this.height = AppMetrics.primaryButtonHeight,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AppMetrics.cornerRadius),
    ),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  label,
                  key: const ValueKey('text'),
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.buttonSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}
