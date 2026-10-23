import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/community.dart';
import 'package:juniper_journal/src/backend/db/models/community_member.dart';
import 'package:juniper_journal/src/backend/db/models/impact_entry.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/repositories/communities_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/community/community_journal_data.dart';
import 'package:juniper_journal/src/features/community/pages/community_profile_screen.dart';
import 'package:juniper_journal/src/features/community/pages/create_community_screen.dart';

JournalEntry _entry(String id, {bool submitted = true, DateTime? date}) =>
    JournalEntry(
      id: id,
      projectId: 'p',
      title: id,
      progress: 'prototyping',
      createdAt: date,
      content: [
        {
          'stage': 'prototyping',
          'entryType': 'building',
          'title': 'Lid',
          'summary': 'Built a lid',
          'objective': 'Reduce evaporation',
          'component': {'id': 'c', 'name': 'Lid'},
        },
        {
          'stage': 'learning',
          'inquiryLens': 'Design',
          'dci': ['DCI'],
          'sep': ['SEP'],
          'ccc': ['CCC'],
        },
        {
          'stage': 'nextAction',
          'submitted': submitted,
          'learned': 'Fit matters',
          'challenges': 'Leaks',
          'nextSteps': 'Seal it',
        },
      ],
    );

class _Projects extends ProjectsRepo {
  @override
  Future<List<Project>> getAudienceFeedProjects({
    List<String>? ownerIds,
    String? communityId,
  }) async => [
    const Project(
      id: 'p',
      projectName: 'Terrarium',
      tags: ['Environment & Sustainability'],
    ),
  ];
  @override
  Future<List<JournalEntry>> getCommunityJournalEntries({
    required String projectId,
    required String communityId,
  }) async => [
    _entry('old', date: DateTime(2025)),
    _entry('draft', submitted: false),
    _entry('new', date: DateTime(2026)),
  ];
  @override
  Future<List<ImpactEntry>?> getImpactEntries({
    required String projectId,
  }) async => [
    const ImpactEntry(
      id: 'i',
      projectId: 'p',
      title: 'Learning',
      metric: 'Education',
      impactScale: 'Seed',
      patternType: 'Capacity Building',
      evidenceType: 'Photo',
      confidenceScore: 'Medium',
      ecoPoints: 13,
      linkedJournalEntryId: 'new',
    ),
  ];
}

class _Communities extends CommunitiesRepo {
  @override
  Future<bool> isAcceptedCommunityMember(String id) async => true;

  @override
  Future<List<CommunityMember>> getCommunityMembers(String id) async => const [
    CommunityMember(
      memberId: 'owner',
      userId: 'o',
      displayName: 'Owner',
      role: 'owner',
      status: 'accepted',
    ),
    CommunityMember(
      memberId: 'm',
      userId: 'u',
      displayName: 'Amelia',
      role: 'member',
      status: 'accepted',
    ),
    CommunityMember(
      memberId: 'pending',
      userId: 'pending',
      displayName: 'Pending Person',
      role: 'member',
      status: 'pending',
    ),
  ];
}

class _VisitorCommunities extends CommunitiesRepo {
  bool rosterRead = false;
  @override
  Future<bool> isAcceptedCommunityMember(String id) async => false;
  @override
  Future<List<CommunityMember>> getCommunityMembers(String id) async {
    rosterRead = true;
    throw StateError('Visitors must not fetch a roster');
  }

  @override
  Future<Map<String, dynamic>> getPublicCommunityProfile(String id) async => {
    'member_count': 14,
    'admins': [
      {'id': 'admin', 'display_name': 'Public Admin', 'role': 'owner'},
    ],
    'eco_points': 12,
    'completed_entries': 2,
    'progress': [
      {
        'subject': 'Environment & Sustainability',
        'eco_points': 12,
        'entries': 2,
      },
    ],
    'projects': [
      {
        'id': 'public-p',
        'project_name': 'Public garden',
        'visibility': 'public',
        'tags': ['Environment & Sustainability'],
        'journal_entries': [
          {'count': 2},
        ],
      },
    ],
  };
}

const _community = Community(
  id: 'c',
  name: 'EcoSociety',
  visibility: 'public',
  createdBy: 'o',
);
void main() {
  test(
    'community journal excludes drafts, sorts newest first and links impact totals',
    () async {
      final records = await loadCommunityJournal(_Projects(), 'c');
      expect(records.map((r) => r.entry.id), ['new', 'old']);
      expect(records.first.ecoPoints, 13);
      expect(records.last.ecoPoints, 0);
    },
  );
  testWidgets(
    'community setup uses subject and visibility cards without overflowing',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: CreateCommunityScreen()));
      expect(find.text('Visible to everyone.'), findsOneWidget);
      await tester.tap(find.text('Private'));
      await tester.pump();
      await tester.ensureVisible(find.text('Energy & Systems'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Energy & Systems'));
      await tester.pump();
      await tester.ensureVisible(find.text('No members added yet.'));
      await tester.pumpAndSettle();
      expect(find.text('Add People'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final visitor in [null, 'outside-user']) {
    testWidgets('public community profile limits roster for visitor=$visitor', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _VisitorCommunities();
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfileScreen(
            community: _community,
            currentUserId: visitor,
            communitiesRepo: repo,
            projectsRepo: _Projects(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
      expect(find.text('Public garden'), findsOneWidget);
      expect(
        find.text('2 completed journal entries · 12 EcoPoints'),
        findsOneWidget,
      );
      await tester.tap(find.text('Members'));
      await tester.pumpAndSettle();
      expect(find.text('14 Members'), findsOneWidget);
      expect(find.text('Public Admin'), findsOneWidget);
      expect(find.text('Amelia'), findsNothing);
      expect(find.byTooltip('Manage members'), findsNothing);
      expect(find.byTooltip('Add people'), findsNothing);
      expect(find.text('Community settings'), findsNothing);
      expect(repo.rosterRead, isFalse);
    });
  }

  for (final owner in [true, false]) {
    testWidgets('community profile member controls respect owner=$owner', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfileScreen(
            community: _community,
            currentUserId: owner ? 'o' : 'u',
            communitiesRepo: _Communities(),
            projectsRepo: _Projects(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('2 completed journal entries · 13 EcoPoints'),
        findsOneWidget,
      );
      await tester.tap(find.text('Members'));
      await tester.pumpAndSettle();
      expect(find.text('Amelia'), findsOneWidget);
      expect(
        find.byTooltip('Add people'),
        owner ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Pending Person'),
        owner ? findsOneWidget : findsNothing,
      );
      if (owner) {
        await tester.tap(find.byTooltip('Manage members'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Remove member'), findsOneWidget);
        await tester.tap(find.byTooltip('Remove member'));
        await tester.pumpAndSettle();
        expect(find.text('Remove member?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
