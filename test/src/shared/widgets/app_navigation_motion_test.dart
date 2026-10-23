import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/styling/app_motion.dart';
import 'package:juniper_journal/src/shared/styling/app_theme.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/app_tab_transition.dart';
import 'package:juniper_journal/src/shared/widgets/project_filter_sheet.dart';

void main() {
  testWidgets(
    'tab crossfade preserves input and scroll and hides inactive semantics',
    (tester) async {
      final selected = ValueNotifier(0);
      final text = TextEditingController();
      final scroll = ScrollController();
      addTearDown(selected.dispose);
      addTearDown(text.dispose);
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: selected,
              builder: (_, index, __) => AppTabStack(
                index: index,
                sizing: StackFit.expand,
                children: [
                  ListView(
                    controller: scroll,
                    children: [
                      TextField(controller: text),
                      const SizedBox(height: 1200),
                    ],
                  ),
                  const Center(child: Text('Second tab')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Keep my draft');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      scroll.jumpTo(120);
      await tester.pump();
      expect(scroll.offset, 120);
      selected.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      final opacities = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((w) => w.opacity);
      expect(opacities.any((value) => value > 0 && value < 1), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      selected.value = 0;
      await tester.pumpAndSettle();
      expect(text.text, 'Keep my draft');
      expect(scroll.offset, 120);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('reduced motion shows selected tab without a visual transition', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ValueListenableBuilder<int>(
            valueListenable: selected,
            builder: (_, index, __) => AppTabStack(
              index: index,
              children: const [Text('First'), Text('Second')],
            ),
          ),
        ),
      ),
    );
    selected.value = 1;
    await tester.pump();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(
              of: find.text('Second'),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      1,
    );
    await tester.pumpAndSettle();
  });
  testWidgets(
    'section crossfade handles long-to-short content without overflow',
    (tester) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ValueListenableBuilder<int>(
                valueListenable: selected,
                builder: (_, index, __) => AppContentTransition(
                  index: index,
                  child: Column(
                    children: List.generate(
                      index == 0 ? 20 : 2,
                      (i) => Text('Row $i'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      selected.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.text('Row 10'), findsNothing);
    },
  );
  testWidgets(
    'all platforms use the same page transition and back retains the page',
    (tester) async {
      final theme = buildAppTheme();
      for (final platform in TargetPlatform.values) {
        final builder = theme.pageTransitionsTheme.builders[platform];
        expect(builder, isA<AppPageTransitionsBuilder>());
        expect(builder!.transitionDuration, AppMotion.pageDuration);
        expect(builder.reverseTransitionDuration, AppMotion.pageDuration);
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('Detail page')),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(SlideTransition), findsWidgets);
      await tester.pumpAndSettle();
      Navigator.pop(tester.element(find.text('Detail page')));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
    },
  );
  testWidgets(
    'filter typography uses shared heading, label, and helper styles',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: ProjectFilterSheet(
              title: 'Subject',
              options: kSubjectOptions,
              initialSelected: const {},
              onApply: (_) {},
            ),
          ),
        ),
      );
      final title = tester.widget<Text>(find.text('Subject')).style!;
      final label = tester
          .widget<Text>(find.text(kSubjectOptions.first.label))
          .style!;
      final description = tester
          .widget<Text>(find.text(kSubjectOptions.first.description))
          .style!;
      expect(title.fontFamily, AppTypography.headingFamily);
      expect(title.fontSize, AppTypography.sectionTitleSize);
      expect(label, AppTypography.fieldLabel);
      expect(label.color, AppColors.textPrimary);
      expect(description.color, AppTypography.helper.color);
      expect(description.fontFamily, AppTypography.bodyFamily);
    },
  );
}
