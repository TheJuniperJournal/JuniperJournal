import '../../backend/db/models/journal_entry.dart';
import '../../backend/db/repositories/projects_repo.dart';

String journalPhaseLabel(String phase) => switch (phase.toLowerCase()) {
  'discover' || 'discovery' => 'Discovery',
  'ideating' || 'ideation' => 'Ideation',
  'prototyping' => 'Prototyping',
  'implementation' => 'Implementation',
  _ => phase,
};
String journalEntryTitle(String input, int number, String phase) =>
    input.trim().isEmpty
    ? 'Entry $number: ${journalPhaseLabel(phase)}'
    : input.trim();

Future<int> journalEntryNumber(
  ProjectsRepo repo,
  String projectId,
  String phase,
  JournalEntry? entry,
) async {
  final match = RegExp(r'^Entry (\d+):').firstMatch(entry?.title ?? '');
  if (match != null) return int.parse(match.group(1)!);
  List<JournalEntry> entries;
  try {
    entries = await repo.getJournalEntries(projectId: projectId) ?? [];
  } catch (_) {
    return 1;
  }
  final samePhase =
      entries
          .where(
            (e) =>
                journalPhaseLabel(e.progress ?? '') == journalPhaseLabel(phase),
          )
          .toList()
        ..sort(
          (a, b) => (a.createdAt ?? DateTime(1970)).compareTo(
            b.createdAt ?? DateTime(1970),
          ),
        );
  final index = samePhase.indexWhere((e) => e.id == entry?.id);
  return index >= 0 ? index + 1 : samePhase.length + 1;
}
