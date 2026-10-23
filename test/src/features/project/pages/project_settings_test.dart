import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:juniper_journal/src/backend/db/supabase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/project_settings.dart';

class _FakeProjectsRepo extends ProjectsRepo {
  @override
  Future<Project?> getProjectById(String id) async {
    return Project(
      id: id,
      projectName: 'River Cleanup',
      tags: ['Environment & Sustainability|Ecosystems & Biodiversity'],
      problemStatement: 'Too much runoff pollution.',
      difficulty: 'Easy',
      projectScale: 'Small',
      visibility: 'Public',
    );
  }

  @override
  Future<bool> updateProjectMetadata({
    required String id,
    required String projectName,
    required String problemStatement,
    required List<String> tags,
    String? projectImageUrl,
    String? difficulty,
    String? projectScale,
    String? visibility,
    String? projectType,
    List<Map<String, dynamic>>? communityLinks,
    List<Map<String, dynamic>>? learningObjectives,
    bool? shareFriends,
    List<String>? sharedCommunityIds,
  }) async {
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
  testWidgets('ProjectSettingsScreen loads and shows existing metadata', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectSettingsScreen(
          projectId: 'project-1',
          projectsRepo: _FakeProjectsRepo(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Project Settings'), findsOneWidget);
    expect(find.text('River Cleanup'), findsOneWidget);
    expect(find.text('Too much runoff pollution.'), findsOneWidget);
    expect(find.text('Save Settings'), findsOneWidget);
  });
}
