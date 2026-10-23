import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/conversation_composer.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';

void main() {
  test('plain content is unchanged; malformed metadata remains readable', () {
    expect(const ConversationContent('Hello').encode(), 'Hello');
    expect(ConversationContent.parse('Old message').text, 'Old message');
    expect(
      ConversationContent.parse('{"juniper_message":1,broken').text,
      contains('broken'),
    );
  });
  test(
    'reply ids and mention identities persist and removed mentions are omitted',
    () {
      final controller = ConversationController();
      controller.replyTo('original-id', 'Sam', 'Original message');
      controller.text = 'Hi @sam';
      controller.mentions.add({'id': 'sam-id', 'token': '@sam'});
      final saved = ConversationContent.parse(controller.payload);
      expect(saved.reply?['id'], 'original-id');
      expect(saved.mentions.single['id'], 'sam-id');
      controller.text = 'Hi';
      expect(ConversationContent.parse(controller.payload).mentions, isEmpty);
      controller.cancelReply();
      expect(controller.payload, 'Hi');
      controller.clear();
      expect(controller.reply, isNull);
      controller.dispose();
    },
  );
  testWidgets(
    'reply can be cancelled without erasing text and @ selects a user',
    (tester) async {
      final controller = ConversationController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 340,
              child: ConversationComposer(
                controller: controller,
                searchUsers: (_) async => [
                  const UserProfile(
                    id: 'sam-id',
                    displayName: 'Sam',
                    username: 'sam',
                  ),
                ],
                child: TextField(
                  controller: controller,
                  focusNode: controller.focusNode,
                ),
              ),
            ),
          ),
        ),
      );
      controller.replyTo('parent', 'Alex', 'An earlier comment');
      controller.text = 'Draft';
      await tester.pump();
      expect(find.text('Replying to Alex'), findsOneWidget);
      await tester.tap(find.byTooltip('Cancel reply'));
      await tester.pump();
      expect(controller.text, 'Draft');
      await tester.enterText(find.byType(TextField), 'Hello @sa');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.tap(find.text('Sam'));
      await tester.pump();
      expect(controller.text, 'Hello @sam ');
      expect(
        ConversationContent.parse(controller.payload).mentions.single['id'],
        'sam-id',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets('saved reply renders the quote and message without metadata', (
    tester,
  ) async {
    final content = ConversationContent(
      'Thanks @sam',
      reply: {'id': 'p', 'author': 'Alex', 'text': 'Earlier'},
      mentions: [
        {'id': 'sam', 'token': '@sam'},
      ],
    ).encode();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 320, child: ConversationBody(content)),
        ),
      ),
    );
    expect(find.text('Alex\nEarlier'), findsOneWidget);
    expect(find.text('Thanks @sam'), findsOneWidget);
    expect(find.textContaining('juniper_message'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
