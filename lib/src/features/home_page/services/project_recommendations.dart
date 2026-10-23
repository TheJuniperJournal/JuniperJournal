import '../../../backend/db/models/project.dart';

/// Content-based recommendations. Candidates arrive in latest-activity order;
/// that order breaks affinity ties and provides a cold-start fallback.
List<Project> recommendProjects({
  required List<Project> candidates,
  required List<Project> history,
  String? userId,
}) {
  final known = {for (final project in history) project.id};
  final affinity = <String, double>{};
  for (final project in {for (final p in history) p.id: p}.values) {
    for (final feature in _features(project).entries) {
      affinity.update(
        feature.key,
        (value) => value + feature.value,
        ifAbsent: () => feature.value,
      );
    }
  }
  final positions = {
    for (var i = 0; i < candidates.length; i++) candidates[i].id: i,
  };
  double score(Project project) {
    var total = 0.0;
    for (final feature in _features(project).entries) {
      // Bound repeated signals so one prolific subject cannot dominate forever.
      total += feature.value * (affinity[feature.key] ?? 0).clamp(0, 12);
    }
    return total;
  }

  final results = candidates
      .where(
        (p) =>
            p.visibility?.toLowerCase() == 'public' &&
            !known.contains(p.id) &&
            (userId == null || p.userId != userId),
      )
      .toList();
  final scores = {for (final project in results) project.id: score(project)};
  results.sort((a, b) {
    final comparison = scores[b.id]!.compareTo(scores[a.id]!);
    return comparison != 0
        ? comparison
        : positions[a.id]!.compareTo(positions[b.id]!);
  });
  return results;
}

Map<String, double> _features(Project project) {
  final features = <String, double>{};
  void add(String prefix, String? value, double weight) {
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isNotEmpty) features['$prefix:$normalized'] = weight;
  }

  add('subject', project.subjectDomain, 3);
  for (final tag in project.tags) {
    final parts = tag.split('|');
    add('subject', parts.first, 3);
    if (parts.length > 1) add('topic', parts.skip(1).join('|'), 5);
  }
  add('difficulty', project.difficulty, 0.5);
  add('scale', project.projectScale, 0.5);
  return features;
}
