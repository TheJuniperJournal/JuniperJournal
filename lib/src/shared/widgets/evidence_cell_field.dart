import 'package:flutter/material.dart';

/// Table boundaries supply the border, so spreadsheet cells have no inner bubble.
class EvidenceCellField extends StatelessWidget {
  const EvidenceCellField({
    super.key,
    required this.controller,
    this.onChanged,
    this.numeric = false,
    this.label,
  });
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool numeric;
  final String? label;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    minLines: 1,
    maxLines: null,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true, signed: true)
        : TextInputType.multiline,
    decoration: InputDecoration(
      hintText: label,
      isDense: true,
      constraints: const BoxConstraints(minHeight: 44),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
  );
}
