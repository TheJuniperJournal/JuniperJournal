import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/features/chat/widgets/message_emoji_reactions.dart';
import 'package:juniper_journal/src/features/chat/widgets/message_gesture_surface.dart';

void main() {
  testWidgets(
    'right click and long press offer emojis without liking or replying',
    (tester) async {
      var likes = 0, replies = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MessageEmojiReactions(
                targetId: 'fixture',
                builder: (context, open, toggleLike, counts) =>
                    MessageGestureSurface(
                      onReply: () => replies++,
                      onLike: () => likes++,
                      onReactions: open,
                      child: const Text('Message'),
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(
        find.text('Message'),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      for (final emoji in messageReactionEmojis) {
        expect(find.text(emoji == '🌼' ? '🌼 Like' : emoji), findsOneWidget);
      }
      expect(likes, 0);
      expect(replies, 0);
      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Message'));
      await tester.pumpAndSettle();
      expect(find.text('🎉'), findsOneWidget);
      expect(likes, 0);
      expect(replies, 0);
    },
  );
}
