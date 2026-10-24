import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/message.dart';
import 'package:juniper_journal/src/features/chat/widgets/message_thread.dart';
import 'package:juniper_journal/src/shared/widgets/conversation_composer.dart';

Message message(String id, {String? parent, String conversation = 'chat'}) =>
    Message(
      id: id,
      conversationId: conversation,
      senderId: 'sender',
      createdAt: DateTime(2026, 1, 1, int.tryParse(id) ?? 0),
      content: ConversationContent(
        'Text $id',
        reply: parent == null
            ? null
            : {'id': parent, 'author': 'Person', 'text': 'Original'},
      ).encode(),
    );
void main() {
  test('replies and nested replies form one thread without duplicates', () {
    final threads = groupMessageThreads([
      message('1'),
      message('2'),
      message('3', parent: '1'),
      message('4', parent: '3'),
    ]);
    expect(threads.map((t) => t.parent.id), ['1', '2']);
    expect(threads.first.replies.map((m) => m.id), ['3', '4']);
  });
  test('missing, foreign, self and cyclic parents remain visible', () {
    final items = [
      message('1', parent: 'gone'),
      message('2', parent: '3'),
      message('3', parent: '2'),
      message('4', parent: '4'),
      message('5', parent: '6'),
      message('6', conversation: 'other'),
    ];
    final threads = groupMessageThreads(items);
    final visible = [
      for (final t in threads) ...[t.parent.id, ...t.replies.map((r) => r.id)],
    ];
    expect(visible.toSet(), items.map((m) => m.id).toSet());
    expect(visible.length, items.length);
  });
  testWidgets('thread count toggles connected inline replies', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InlineMessageThread(
            parent: Text('Original'),
            replies: [Text('First reply'), Text('Second reply')],
          ),
        ),
      ),
    );
    expect(find.text('2 replies · Hide'), findsOneWidget);
    expect(find.text('First reply'), findsOneWidget);
    await tester.tap(find.text('2 replies · Hide'));
    await tester.pumpAndSettle();
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('First reply'), findsNothing);
    await tester.tap(find.text('2 replies · View'));
    await tester.pumpAndSettle();
    expect(find.text('Second reply'), findsOneWidget);
  });
  testWidgets('inline body hides repeated quote but preserves text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationBody(
            message('2', parent: '1').content,
            showReply: false,
          ),
        ),
      ),
    );
    expect(find.text('Text 2'), findsOneWidget);
    expect(find.textContaining('Original'), findsNothing);
  });
  testWidgets('desktop reply thread stays compact and on the parent side', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InlineMessageThread(
            parent: Text('Parent'),
            replies: [
              Align(alignment: Alignment.centerRight, child: Text('Reply')),
            ],
          ),
        ),
      ),
    );
    final parent = tester.getRect(find.text('Parent'));
    final reply = tester.getRect(find.text('Reply'));
    expect(reply.right - parent.left, lessThanOrEqualTo(560));
    expect(reply.right, lessThan(700));
    expect(tester.takeException(), isNull);
  });
}
