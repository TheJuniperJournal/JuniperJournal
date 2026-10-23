import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/features/chat/widgets/message_gesture_surface.dart';

void main() {
  testWidgets('single click replies; double likes; secondary opens reactions', (
    tester,
  ) async {
    var replies = 0;
    var likes = 0;
    var reactions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageGestureSurface(
            onReply: () => replies++,
            onLike: () => likes++,
            onReactions: () => reactions++,
            child: const Text('Message'),
          ),
        ),
      ),
    );
    final message = find.text('Message');
    await tester.tap(message);
    await tester.pump(const Duration(milliseconds: 350));
    expect(replies, 1);
    expect(likes, 0);
    await tester.tap(message);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(message);
    await tester.pumpAndSettle();
    expect(replies, 1);
    expect(likes, 1);
    await tester.tap(
      message,
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(replies, 1);
    expect(likes, 1);
    expect(reactions, 1);
    expect(find.text('Reply'), findsNothing);
  });
  testWidgets('keyboard can reply and like without visible action buttons', (
    tester,
  ) async {
    var replies = 0;
    var likes = 0;
    var reactions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageGestureSurface(
            onReply: () => replies++,
            onLike: () => likes++,
            onReactions: () => reactions++,
            child: const Text('Message'),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    expect(replies, 1);
    expect(likes, 1);
  });
}
