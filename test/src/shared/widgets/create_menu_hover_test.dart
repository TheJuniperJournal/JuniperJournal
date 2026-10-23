import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/create_menu_dialog.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';

void main() {
  testWidgets('create option highlights its label without a hover background', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CreateMenuDialog(
              onClose: () {},
              onCommunityTap: () {},
              onJournalTap: () {},
              onProjectTap: () {},
            ),
          ),
        ),
      ),
    );
    final label = find.text('COMMUNITY');
    final initial = tester.widget<Text>(label).style!.color;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(label));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(label).style!.color, AppColors.primaryDark);
    final ink = tester.widget<InkWell>(
      find.ancestor(of: label, matching: find.byType(InkWell)).first,
    );
    expect(ink.hoverColor, Colors.transparent);
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(label).style!.color, initial);
    await mouse.removePointer();
  });
}
