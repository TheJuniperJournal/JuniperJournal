import 'package:flutter/material.dart';

class AppColors {
  // ── Brand green palette ───────────────────────────────────────────────────
  static const Color primary = Color(0xFF5DB075); // Main brand green
  static const Color primaryDark = Color(
    0xFF2A7A38,
  ); // Darker green (active/emphasis)
  static const Color primaryTint = Color(
    0xFFE6F2E9,
  ); // Very light green (card/chip bg)
  static const Color accent = Color(
    0xFFc9f2cb,
  ); // Light green (e.g. calendar today)
  static const Color gradientStart = Color(0xFF8BD674);
  static const Color gradientEnd = Color(0xFF0B7D4E);

  // ── Surfaces & backgrounds ────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surfaceInput = Color(
    0xFFF2F2F2,
  ); // Search bars, input fills
  static const Color surfaceMuted = Color(0xFFF7F7F7); // Sheet fields, muted bg
  static const Color avatarBackground = Color(
    0xFFE8F4EC,
  ); // Avatar placeholder bg
  static const Color avatarIcon = Color(0xFF5B7B63); // Avatar placeholder icon

  // ── Dividers & borders ────────────────────────────────────────────────────
  static const Color divider = Color(
    0xFFE5E5EA,
  ); // Divider lines, appbar borders
  static const Color border = Color(
    0xFF4CAF50,
  ); // Green border (inputs, back arrow)
  static const Color borderLight = Color(0xFFE0E0E0); // Light grey card borders

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF212121); // Dark text
  static const Color textSecondary = Color(0xFF757575); // Medium grey text
  static const Color darkText = Color(0xFF1F2024);
  static const Color hintText = Color(0xFF808080);
  static const Color lightGrey = Color(0xFF868686);

  // ── Icons ─────────────────────────────────────────────────────────────────
  static const Color iconPrimary = Color(0xFF212121);
  static const Color iconSecondary = Color(0xFF757575);

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC93D);
  static const Color error = Color(0xFFFD1212);

  // ── Blue accents ──────────────────────────────────────────────────────────
  static const Color blue = Color(0xFF2C70BF);
  static const Color lightBlue = Color(0xFFDFECFD);

  // ── Tags ──────────────────────────────────────────────────────────────────
  static const Color tagBackground = Color(0xFFD2E2DA);
  static const Color tagBorder = Color(0xFF5DB075);
  static const Color tagText = Color(0xFF5DB075);

  // ── Button ────────────────────────────────────────────────────────────────
  static const Color buttonPrimary = Color(0xFF5DB075);
  static const Color buttonText = Color(0xFFFFFFFF);

  // ── Deprecated aliases ────────────────────────────────────────────────────
  // ignore: constant_identifier_names
  @Deprecated('Use AppColors.primary')
  static const Color submitButton = primary;
}
