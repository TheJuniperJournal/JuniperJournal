import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/features/community/pages/create_community_screen.dart';
import 'package:juniper_journal/src/features/project/pages/create_project.dart';
import 'package:juniper_journal/src/shared/widgets/creation_page_layout.dart';
import 'package:juniper_journal/src/shared/widgets/journal_section_header.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';

void main() {
  for (final width in [360.0, 1000.0]) {
    testWidgets('project and community setup share geometry at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<(Rect, Rect, Rect)> measure(Widget page) async {
        await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: page));
        await tester.pumpAndSettle();
        final field = tester.getRect(find.byType(TextField).first);
        final frame = tester.getRect(find.byType(CreationPageFrame));
        final header = tester.getRect(find.byType(CreationPageHeader));
        expect(tester.takeException(), isNull);
        expect(field.height, 64);
        expect(
          field.width,
          lessThanOrEqualTo(
            (width >= 1000 ? 720 : JournalPageLayout.contentWidth) -
                JournalPageLayout.horizontalInset * 2,
          ),
        );
        final title = find.text(
          page is CreateProjectScreen ? 'Create Project' : 'Create Community',
        );
        expect(tester.widget<Text>(title).style, AppTypography.pageTitle);
        expect(find.text('Save'), findsNothing);
        return (field, frame, header);
      }

      final project = await measure(const CreateProjectScreen());
      final community = await measure(const CreateCommunityScreen());
      expect(community.$1, project.$1);
      expect(community.$3, project.$3);
      if (width >= 1000) {
        expect(project.$1.width, 640);
        expect(project.$3.width, 720);
        expect(project.$3.center.dx, width / 2);
      }
    });
  }
}
