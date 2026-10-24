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
    'replies stay visibly grouped inline and use the single chat composer',
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
      expect(find.text('Original message'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('The reply')).dy,
        lessThan(tester.getTopLeft(find.text('Unrelated later message')).dy),
      );
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(find.text('1 Reply'));
      await tester.pumpAndSettle();
      expect(find.text('The reply'), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      await tester.tap(find.text('1 Reply'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('The reply'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Replying to Ricky'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'New thread reply');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();
      expect(ConversationContent.parse(repo.sent!).reply?['id'], '1');
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
