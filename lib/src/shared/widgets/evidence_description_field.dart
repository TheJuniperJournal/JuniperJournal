import '../styling/app_metrics.dart';
import 'package:flutter/material.dart';
import '../styling/app_typography.dart';

class EvidenceDescriptionField extends StatelessWidget {
  const EvidenceDescriptionField({
    super.key,
    required this.controller,
    this.hintText = 'Describe what this evidence shows, how it relates to your notes, and any limits or uncertainty.',
  });
  final TextEditingController controller;
  final String hintText;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    minLines: AppMetrics.longResponseLines,
    maxLines: null,
    keyboardType: TextInputType.multiline,
    style: AppTypography.inputText,
    decoration: InputDecoration(
      hintText: hintText,
      contentPadding: const EdgeInsets.all(12),
    ),
  );
}
