import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/features/home_page/services/project_recommendations.dart';

Project project(
  String id,
  String subject, {
  String? topic,
  String visibility = 'public',
  String? owner,
}) => Project(
  id: id,
  projectName: id,
  tags: [topic == null ? subject : '$subject|$topic'],
  visibility: visibility,
  userId: owner,
);
void main() {
  test('matching topics and subjects rank ahead of unrelated projects', () {
    final history = [project('mine', 'Environment', topic: 'Gardening')];
    final results = recommendProjects(
      candidates: [
        project('solar', 'Energy'),
        project('forest', 'Environment'),
        project('garden', 'Environment', topic: 'Gardening'),
      ],
      history: history,
    );
    expect(results.map((p) => p.id), ['garden', 'forest', 'solar']);
  });
  test('own, known and private projects never appear', () {
    final saved = project('saved', 'Environment');
    final results = recommendProjects(
      candidates: [
        saved,
        project('own', 'Energy', owner: 'me'),
        project('private', 'Environment', visibility: 'private'),
        project('new', 'Environment'),
      ],
      history: [saved],
      userId: 'me',
    );
    expect(results.map((p) => p.id), ['new']);
  });
  test('cold start preserves latest activity order', () {
    final results = recommendProjects(
      candidates: [
        project('latest', 'Energy'),
        project('older', 'Environment'),
      ],
      history: [],
    );
    expect(results.map((p) => p.id), ['latest', 'older']);
  });
  test(
    'new bookmark interests change recommendations without popularity bias',
    () {
      final candidates = [
        project('garden', 'Environment'),
        project('solar', 'Energy'),
      ];
      final results = recommendProjects(
        candidates: candidates,
        history: [project('bookmark', 'Energy')],
      );
      expect(results.first.id, 'solar');
    },
  );
}
