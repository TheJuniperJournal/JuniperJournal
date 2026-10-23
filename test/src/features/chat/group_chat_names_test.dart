import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/conversation_preview.dart';
import 'package:juniper_journal/src/backend/db/models/message.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/chat_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/friends_repo.dart';
import 'package:juniper_journal/src/features/chat/pages/chat_screen.dart';
import 'package:juniper_journal/src/features/chat/pages/chats_list_screen.dart';
import 'package:juniper_journal/src/features/chat/widgets/group_chat_name_dialog.dart';

class _Chats extends ChatRepo {
  String? name;
  List<String>? members;
  bool succeed = true;
  int streams = 0;
  @override
  Future<void> markAsRead(String id) async {}
  @override
  Stream<List<Message>> streamCommunityMessages(String id) {
    streams++;
    return Stream.value([]);
  }

  @override
  Stream<List<Message>> streamMessages(String id) => Stream.value([]);
  @override
  Future<bool> renameGroupDm({
    required String conversationId,
    required String name,
  }) async {
    if (succeed) this.name = name;
    return succeed;
  }

  @override
  Future<String?> createGroupDm({
    required String name,
    required List<String> memberIds,
  }) async {
    this.name = name;
    members = memberIds;
    return 'g';
  }

  @override
  Future<List<ConversationPreview>?> getConversations() async => [
    if (name != null)
      ConversationPreview(
        conversationId: 'g',
        isGroup: true,
        groupName: name,
        unreadCount: 0,
      ),
  ];
}

class _Friends extends FriendsRepo {
  @override
  Future<List<UserProfile>?> getFriends() async => const [
    UserProfile(id: 'a', displayName: 'Amelia Yang'),
    UserProfile(id: 'b', displayName: 'Ricky Rios'),
  ];
}

void main() {
  testWidgets(
    'existing group name saves to header without restarting message stream',
    (tester) async {
      final repo = _Chats();
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            conversationId: 'g',
            otherUserName: 'Ricky, John',
            isGroup: true,
            canRenameGroup: true,
            chatRepo: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Rename group chat'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '  Garden team  ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.name, 'Garden team');
      expect(find.text('Garden team'), findsOneWidget);
      expect(repo.streams, 1);
    },
  );
  testWidgets(
    'blank and failed renames retain original name; cancel makes no change',
    (tester) async {
      final repo = _Chats()..succeed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            conversationId: 'g',
            otherUserName: 'Original',
            isGroup: true,
            canRenameGroup: true,
            chatRepo: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Rename group chat'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), ' ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a group name'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'New name');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save the group name. Please try again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Original'), findsOneWidget);
      expect(repo.name, isNull);
    },
  );
  testWidgets('direct and community chats have no group rename control', (
    tester,
  ) async {
    for (final group in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            key: ValueKey(group),
            conversationId: 'g',
            otherUserName: 'Conversation',
            isGroup: group,
            chatRepo: _Chats(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Rename group chat'), findsNothing);
    }
  });
  testWidgets(
    'creating a group asks for its name and passes selected members',
    (tester) async {
      final repo = _Chats();
      await tester.pumpWidget(
        MaterialApp(
          home: ChatsListScreen(chatRepo: repo, friendsRepo: _Friends()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amelia Yang'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ricky Rios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.byType(GroupChatNameDialog), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Garden team');
      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();
      expect(repo.name, 'Garden team');
      expect(repo.members, ['a', 'b']);
      expect(find.text('Garden team'), findsOneWidget);
      Navigator.pop(tester.element(find.byType(ChatScreen)));
      await tester.pumpAndSettle();
      expect(find.text('Garden team'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
