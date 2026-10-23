import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Platform-wide text roles. Keep new screens on these roles rather than
/// introducing a new size or color for each widget.
abstract final class AppTypography {
  static const headingFamily = 'Manrope';
  static const bodyFamily = 'Inter';
  static const pageTitleSize = 20.0;
  static const sectionTitleSize = 18.0;
  static const evidenceTitleSize = 20.0;
  static const fieldLabelSize = 14.0;
  static const bodySize = 14.0;
  static const helperSize = 12.0;
  static const captionSize = 10.0;
  static const buttonSize = 14.0;
  static const displaySize = 28.0;
  static const heroSize = 40.0;

  static const pageTitle = TextStyle(
    fontFamily: headingFamily,
    fontSize: pageTitleSize,
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );
  static const sectionTitle = TextStyle(
    fontFamily: headingFamily,
    fontSize: sectionTitleSize,
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const evidenceTitle = TextStyle(
    fontFamily: headingFamily,
    fontSize: evidenceTitleSize,
    color: AppColors.primary,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const fieldLabel = TextStyle(
    fontFamily: bodyFamily,
    fontSize: fieldLabelSize,
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );
  static const inputText = TextStyle(
    fontFamily: bodyFamily,
    fontSize: bodySize,
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const body = TextStyle(
    fontFamily: bodyFamily,
    fontSize: bodySize,
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const helper = TextStyle(
    fontFamily: bodyFamily,
    fontSize: helperSize,
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const requirement = TextStyle(
    fontFamily: bodyFamily,
    fontSize: helperSize,
    color: AppColors.error,
    height: 1.5,
  );
  static const caption = TextStyle(
    fontFamily: bodyFamily,
    fontSize: captionSize,
    color: AppColors.textSecondary,
    height: 1.4,
  );
  static const button = TextStyle(
    fontFamily: bodyFamily,
    fontSize: buttonSize,
    fontWeight: FontWeight.w500,
  );
}
