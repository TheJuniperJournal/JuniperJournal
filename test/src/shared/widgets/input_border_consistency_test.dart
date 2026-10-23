import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/styling/app_theme.dart';

void main() {
  test('text input outlines stay consistent when focused, including errors', () {
    final theme = buildAppTheme().inputDecorationTheme;
    expect(theme.focusedBorder, theme.enabledBorder);
    expect(theme.focusedErrorBorder, theme.errorBorder);
    expect(theme.errorBorder, isNot(theme.enabledBorder));
  });
}
