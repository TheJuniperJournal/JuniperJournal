import '../../../backend/db/models/journal_entry.dart';
import '../../learning_module/pages/assessment_block.dart';

/// Recomputed from persisted inputs so deleting required content reopens a draft.
bool journalEntryIsComplete(JournalEntry entry) {
  if (entry.isFreeNotes) {
    final metadata = entry.content.whereType<Map>().firstWhere(
      (row) => row['stage'] == 'free_notes',
    );
    return metadata['submitted'] == true && freeNotesHaveContent(entry.content);
  }
  final stages = {
    for (final row in entry.content.whereType<Map>())
      row['stage']?.toString(): row,
  };
  final prototype = stages['prototyping'];
  final count =
      stages.containsKey('observations') || stages.containsKey('challenge')
      ? 5
      : stages.containsKey('overview')
      ? 4
      : prototype is Map && prototype['entryType'] != null
      ? (prototype['entryType'] == 'technical_analysis'
            ? 3
            : prototype['entryType'] == 'building' &&
                  prototype['materialsWorkflow'] == true
            ? 5
            : 4)
      : 0;
  if (count == 0) return _legacyJournalEntryIsComplete(entry);
  final finalStage =
      stages[stages.containsKey('overview') ? 'reflection' : 'nextAction'];
  return finalStage is Map &&
      finalStage['submitted'] == true &&
      completedJournalStageIndices(entry.content).length == count;
}

bool _legacyJournalEntryIsComplete(JournalEntry entry) {
  final stages = {
    for (final item in entry.content.whereType<Map>())
      item['stage']?.toString(): item,
  };
  Map stage(String name) => stages[name] ?? {};
  bool fields(Map data, List<String> keys) =>
      keys.every((key) => (data[key]?.toString().trim() ?? '').isNotEmpty);
  List<Map> rows(Object? value) =>
      value is List ? value.whereType<Map>().toList() : [];
  bool choices(Object? value) => value is List && value.isNotEmpty;
  bool learning(Map data) {
    final lens =
        (data['inquiryLens'] ??
                (data['inquiryLensData'] is Map
                    ? (data['inquiryLensData'] as Map)['selected_lens']
                    : null))
            ?.toString();
    final assessment = AssessmentBlockData.fromJson(data['assessment']);
    return lens != null &&
        lens.isNotEmpty &&
        lens != 'None' &&
        choices(data['dci']) &&
        choices(data['sep']) &&
        choices(data['ccc']) &&
        (!assessmentFeaturesEnabled ||
            !assessment.hasDraft ||
            assessment.isValid);
  }

  bool next(Map data) => fields(data, ['learned', 'challenges', 'nextSteps']);
  if (stages.containsKey('observations')) {
    final causes = rows(stage('analyze')['rootCauses']);
    final questions = rows(stage('question')['questions']);
    return fields(stage('observations'), ['observed', 'known']) &&
        causes.isNotEmpty &&
        causes.every(
          (cause) => fields(cause, ['title', 'description', 'reason']),
        ) &&
        fields(stage('analyze'), ['patternChange', 'patternExplanation']) &&
        questions.isNotEmpty &&
        questions.length <= 4 &&
        questions.every((question) => fields(question, ['type', 'text'])) &&
        learning(stage('learning')) &&
        next(stage('nextAction'));
  }
  if (stages.containsKey('challenge')) {
    final ideas = rows(stage('ideas')['items']);
    final criteria = rows(stage('decisionMatrix')['criteria']);
    final total = criteria.fold<num>(
      0,
      (sum, criterion) => sum + (num.tryParse('${criterion['weight']}') ?? 0),
    );
    final rated = criteria.every(
      (criterion) => ideas.every((idea) {
        final ratings = criterion['ratings'];
        final score = ratings is Map
            ? num.tryParse('${ratings[idea['id']]}')
            : null;
        return score != null && score >= 1 && score <= 5;
      }),
    );
    return fields(stage('challenge'), ['problem']) &&
        rows(stage('challenge')['objectives']).isNotEmpty &&
        ideas.isNotEmpty &&
        ideas.every(
          (idea) => fields(idea, ['title', 'description', 'rationale']),
        ) &&
        criteria.isNotEmpty &&
        criteria.every((criterion) => fields(criterion, ['criterion'])) &&
        total == 100 &&
        rated &&
        learning(stage('learning')) &&
        next(stage('nextAction'));
  }
  if (stages.containsKey('overview')) {
    return fields(stage('overview'), ['summary']) &&
        learning(stage('learning')) &&
        fields(stage('reflection'), [
          'workedWell',
          'didntWork',
          'keyTakeaways',
          'change',
        ]);
  }
  if (stages.containsKey('prototyping')) {
    final prototype = stage('prototyping');
    if (prototype['entryType'] != null) {
      final keys = switch (prototype['entryType']) {
        'building' => ['summary'],
        'testing' => ['question', 'method', 'expectedOutcome', 'results'],
        'technical_analysis' => [
          'question',
          'method',
          'results',
          'interpretation',
        ],
        _ => <String>[],
      };
      return keys.isNotEmpty &&
          (prototype['entryType'] != 'building' ||
              (prototype['component'] is Map &&
                  fields(prototype['component'] as Map, ['id', 'name']))) &&
          fields(prototype, keys) &&
          learning(stage('learning')) &&
          next(stage('nextAction'));
    }

    final iterations = rows(stage('prototyping')['iterations']);
    return iterations.isNotEmpty &&
        iterations.every((iteration) {
          final components = rows(iteration['components']);
          return fields(iteration, ['title']) &&
              components.isNotEmpty &&
              components.every((component) {
                final builds = rows(component['buildLogs']);
                final tests = rows(component['testEntries']);
                bool logReady(Map log, List<String> keys) =>
                    fields(log, keys) &&
                    learning(
                      log['learning'] is Map ? log['learning'] as Map : {},
                    ) &&
                    next(
                      log['nextAction'] is Map ? log['nextAction'] as Map : {},
                    );
                return fields(component, ['name', 'description', 'status']) &&
                    builds.isNotEmpty &&
                    tests.isNotEmpty &&
                    builds.every(
                      (log) => logReady(log, ['title', 'summary']),
                    ) &&
                    tests.every(
                      (log) => logReady(log, [
                        'title',
                        'description',
                        'method',
                        'expectedOutcome',
                        'outcome',
                      ]),
                    );
              });
        });
  }
  return false;
}

/// Completed journal stages; navigation history never contributes to this set.
Set<int> completedJournalStageIndices(List<dynamic> content) {
  final stages = {
    for (final row in content.whereType<Map>()) row['stage']?.toString(): row,
  };
  Map stage(String key) => stages[key] ?? {};
  bool fields(Map data, List<String> keys) =>
      keys.every((key) => (data[key]?.toString().trim() ?? '').isNotEmpty);
  List<Map> rows(Object? raw) =>
      raw is List ? raw.whereType<Map>().toList() : [];
  bool choices(Object? raw) => raw is List && raw.isNotEmpty;
  bool learning(Map data) {
    final lens =
        (data['inquiryLens'] ??
                (data['inquiryLensData'] is Map
                    ? (data['inquiryLensData'] as Map)['selected_lens']
                    : null))
            ?.toString()
            .trim() ??
        '';
    final assessment = AssessmentBlockData.fromJson(data['assessment']);
    return lens.isNotEmpty &&
        lens != 'None' &&
        choices(data['dci']) &&
        choices(data['sep']) &&
        choices(data['ccc']) &&
        (!assessmentFeaturesEnabled ||
            assessment.type == null ||
            assessment.isValid);
  }

  final learned = learning(stage('learning'));
  final next = fields(stage('nextAction'), [
    'learned',
    'challenges',
    'nextSteps',
  ]);
  List<bool> complete = [];
  if (stages.containsKey('observations')) {
    final observe = stage('observations');
    final analyze = stage('analyze');
    final causes = rows(analyze['rootCauses']);
    final questions = rows(stage('question')['questions']);
    complete = [
      fields(observe, ['observed', 'known']),
      causes.isNotEmpty &&
          causes.every(
            (cause) => fields(cause, ['title', 'description', 'reason']),
          ) &&
          fields(analyze, ['patternChange', 'patternExplanation']),
      questions.isNotEmpty &&
          questions.length <= 4 &&
          questions.every((question) => fields(question, ['type', 'text'])),
      learned,
      next,
    ];
  } else if (stages.containsKey('challenge')) {
    final ideas = rows(stage('ideas')['items']);
    final criteria = rows(stage('decisionMatrix')['criteria']);
    final total = criteria.fold<num>(
      0,
      (sum, row) => sum + (num.tryParse('${row['weight']}') ?? 0),
    );
    final matrix =
        ideas.isNotEmpty &&
        criteria.isNotEmpty &&
        criteria.length <= 5 &&
        total == 100 &&
        criteria.every(
          (criterion) =>
              fields(criterion, ['criterion']) &&
              ideas.every((idea) {
                final ratings = criterion['ratings'];
                final score = ratings is Map
                    ? num.tryParse('${ratings[idea['id']]}')
                    : null;
                return score != null && score >= 1 && score <= 5;
              }),
        );
    complete = [
      fields(stage('challenge'), ['problem']) &&
          rows(stage('challenge')['objectives']).isNotEmpty,
      ideas.isNotEmpty &&
          ideas.length <= 4 &&
          ideas.every(
            (idea) => fields(idea, ['title', 'description', 'rationale']),
          ),
      matrix,
      learned,
      next,
    ];
  } else if (stages.containsKey('overview')) {
    complete = [
      fields(stage('overview'), ['summary']),
      true, // Implementation impacts are optional, including zero entries.
      learned,
      fields(stage('reflection'), [
        'workedWell',
        'didntWork',
        'keyTakeaways',
        'change',
      ]),
    ];
  } else if (stages.containsKey('prototyping')) {
    final data = stage('prototyping');
    final type = data['entryType'];
    final ready = switch (type) {
      'building' => fields(data, ['objective', 'summary']),
      'testing' => fields(data, [
        'question',
        'method',
        'expectedOutcome',
        'outcome',
      ]),
      'technical_analysis' =>
        data['analysisWorkflow'] == true
            ? fields(data, ['question', 'baseline']) &&
                  rows(data['dataSources']).isNotEmpty
            : fields(data, ['question', 'method', 'results', 'interpretation']),
      _ => false,
    };
    complete = [
      // Linking a component is optional, while retaining the stage position.
      if (type == 'building' || type == 'testing') true,
      ready,
      if (type == 'building' && data['materialsWorkflow'] == true)
        data['noMaterials'] == true ||
            (rows(data['materials']).isNotEmpty &&
                rows(data['materials']).every(
                  (item) =>
                      fields(item, ['name']) &&
                      item['cost'] is num &&
                      (item['cost'] as num).isFinite &&
                      (item['cost'] as num) >= 0,
                )),
      learned,
      next,
    ];
  } else if (stages.containsKey('log')) {
    complete = [stage('log')['complete'] == true, learned, next];
  }
  return {
    for (var index = 0; index < complete.length; index++)
      if (complete[index]) index,
  };
}

/// A blank canvas, an empty table, or a formula placeholder is still a draft.
bool freeNotesHaveContent(List<dynamic> content) =>
    content.whereType<Map>().any((block) {
      switch (block['type']) {
        case 'header':
        case 'body':
          return (block['text']?.toString().trim() ?? '').isNotEmpty;
        case 'image':
          return (block['url']?.toString().trim() ?? '').isNotEmpty;
        case 'math':
          return (block['latex']?.toString().trim() ?? '').isNotEmpty;
        case 'table':
          final cells = block['rows'];
          return cells is List &&
              cells.any(
                (row) =>
                    row is List &&
                    row.any(
                      (cell) => (cell?.toString().trim() ?? '').isNotEmpty,
                    ),
              );
        default:
          return false;
      }
    });

/// Public feeds re-check current content, even when a stored publication flag is stale.
List<JournalEntry> completedJournalFeedEntries(
  Iterable<JournalEntry> entries,
) => entries.where(journalEntryIsComplete).toList()
  ..sort(
    (a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(1970)).compareTo(
      a.updatedAt ?? a.createdAt ?? DateTime(1970),
    ),
  );
