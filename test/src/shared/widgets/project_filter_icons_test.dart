import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/project_filter_sheet.dart';
import 'package:juniper_journal/src/features/project/pages/create_project.dart';

void main() {
  testWidgets(
    'filter artwork uses transparent vectors without background images',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final group in [
        ('Metrics', kMetricOptions),
        ('Impact', kImpactOptions),
        ('Pattern', kPatternOptions),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProjectFilterSheet(
                title: group.$1,
                options: group.$2,
                initialSelected: const {},
                onApply: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final icons = tester
            .widgetList<SvgPicture>(find.byType(SvgPicture))
            .toList();
        expect(icons, isNotEmpty);
        expect(find.byType(Image), findsNothing);
        for (final icon in icons) {
          expect(icon.colorFilter, isNull);
          expect(icon.width, 32);
          expect(icon.height, 32);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('scale filters reuse complete setup icons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectFilterSheet(
            title: 'Scale',
            options: kScaleOptions,
            initialSelected: const {},
            onApply: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final icons = tester.widgetList<ProjectSettingIcon>(
      find.byType(ProjectSettingIcon),
    );
    expect(icons.map((icon) => icon.value), ['Small', 'Medium', 'Large']);
    expect(
      icons.every((icon) => icon.kind == ProjectSettingKind.scale),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
