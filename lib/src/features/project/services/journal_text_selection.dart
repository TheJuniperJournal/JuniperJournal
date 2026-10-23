import 'package:flutter/services.dart';

/// Preserve a local caret when a remote insertion precedes it. Offsets use
/// Flutter's UTF-16 convention; composing text is cleared on remote replacement.
TextEditingValue remoteJournalTextValue(TextEditingValue value, String text) {
  if (value.text == text) return value;
  var prefix = 0;
  while (prefix < value.text.length &&
      prefix < text.length &&
      value.text.codeUnitAt(prefix) == text.codeUnitAt(prefix)) {
    prefix++;
  }
  final delta = text.length - value.text.length;
  int offset(int old) => old < 0
      ? text.length
      : (old <= prefix ? old : old + delta).clamp(0, text.length);
  return TextEditingValue(
    text: text,
    selection: TextSelection(
      baseOffset: offset(value.selection.baseOffset),
      extentOffset: offset(value.selection.extentOffset),
    ),
  );
}
