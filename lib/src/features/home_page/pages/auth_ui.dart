import 'package:flutter/material.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';

InputDecoration authInputDecoration(String hint) {
  return InputDecoration(
    hintText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.borderLight),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.borderLight),
    ),
  );
}
