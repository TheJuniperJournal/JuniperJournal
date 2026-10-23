import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/main.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';

void main() {
  testWidgets('app applies shared typography to inputs and buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MyApp(
        initialPage: Scaffold(
          body: Column(children: [TextField(), Text('Preview')]),
        ),
      ),
    );
    final context = tester.element(find.byType(TextField));
    final theme = Theme.of(context);
    expect(theme.textTheme.titleMedium!.fontSize, AppTypography.bodySize);
    expect(theme.textTheme.titleMedium!.color, AppTypography.inputText.color);
    expect(theme.appBarTheme.titleTextStyle, AppTypography.pageTitle);
    expect(theme.textTheme.bodyMedium!.fontFamily, 'Inter');
    expect(theme.textTheme.titleLarge!.fontFamily, 'Manrope');
    expect(AppTypography.sectionTitle.fontFamily, 'Manrope');
    expect(AppTypography.button.fontFamily, 'Inter');
    expect(AppTypography.pageTitle.fontWeight, FontWeight.w600);
    expect(
      theme.textButtonTheme.style!.textStyle!.resolve({}),
      AppTypography.button,
    );
  });
}
