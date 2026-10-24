import 'package:juniper_journal/src/backend/db/supabase_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/message.dart';
import 'package:juniper_journal/src/backend/db/repositories/chat_repo.dart';
import 'package:juniper_journal/src/features/chat/pages/chat_screen.dart';
import 'package:juniper_journal/src/shared/widgets/conversation_composer.dart';

class _Chats extends ChatRepo {
  final rows = [
    Message(
      id: '1',
      conversationId: 'c',
      senderId: 'a',
      content: 'Original',
      createdAt: DateTime(2026, 1, 1),
    ),
    Message(
      id: '2',
      conversationId: 'c',
      senderId: 'b',
      content: 'Unrelated later message',
      createdAt: DateTime(2026, 1, 2),
    ),
    Message(
      id: '3',
      conversationId: 'c',
      senderId: 'b',
      content: const ConversationContent(
        'The reply',
        reply: {'id': '1', 'author': 'Ricky', 'text': 'Original'},
      ).encode(),
      createdAt: DateTime(2026, 1, 3),
    ),
  ];
  String? sent;
  @override
  Future<void> markAsRead(String id) async {}
  @override
  Stream<List<Message>> streamMessages(String id) => Stream.value(rows);
  @override
  Future<bool> sendMessage(String id, String content) async {
    sent = content;
    return true;
  }
}

void main() {
  setUpAll(() {
    SupabaseDatabase.instance.client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
    );
  });
  tearDownAll(() => SupabaseDatabase.instance.client.dispose());
  testWidgets(
    'main chat stays chronological and replies open a focused thread',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _Chats();
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            conversationId: 'c',
            otherUserName: 'Ricky',
            chatRepo: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Unrelated later message')).dy,
        lessThan(tester.getTopLeft(find.text('The reply')).dy),
      );
      await tester.tap(find.text('1 Reply').first);
      await tester.pumpAndSettle();
      final dialog = find.byType(Dialog);
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(
          of: dialog,
          matching: find.text('Unrelated later message'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('The reply')),
        findsOneWidget,
      );
      await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextField)),
        'New thread reply',
      );
      // Composer's send action is the upward arrow.
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.byIcon(Icons.arrow_upward_rounded),
        ),
      );
      await tester.pumpAndSettle();
      expect(ConversationContent.parse(repo.sent!).reply?['id'], '1');
      await tester.tap(find.byTooltip('Close thread'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Unrelated later message'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
