import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/features/project/utils/journal_completion.dart';

void main() {
  test('implementation overview does not require a date', () {
    expect(
      completedJournalStageIndices([
        {'stage': 'overview', 'summary': 'Implemented a prototype'},
      ]),
      contains(0),
    );
    expect(
      completedJournalStageIndices([
        {'stage': 'overview', 'summary': ''},
      ]),
      isNot(contains(0)),
    );
  });

  for (final type in ['building', 'testing', 'technical_analysis']) {
    test('$type completion uses the typed journal fields and shared stages', () {
      final prototype = <String, dynamic>{
        'stage': 'prototyping',
        'entryType': type,
        'title': 'Prototype',
        'summary': 'Built a model',
        'objective': 'Build a model',
        'outcome': 'Validated',
        'component': {'id': 'c', 'name': 'Lid Panel'},
        'question': 'Will it work?',
        'method': 'Measured results',
        'expectedOutcome': 'Improve',
        'results': 'Improved',
        'interpretation': 'Supported by data',
      };
      final content = [
        prototype,
        {
          'stage': 'learning',
          'inquiryLens': 'Design',
          'dci': ['DCI'],
          'sep': ['SEP'],
          'ccc': ['CCC'],
          // Disabled, incomplete legacy assessments must not block completion.
          'assessment': {'type': 'numeric', 'data': {}},
        },
        {
          'stage': 'nextAction',
          'submitted': true,
          'learned': 'Learning',
          'challenges': 'Challenge',
          'nextSteps': 'Next',
        },
      ];
      JournalEntry entry() => JournalEntry(
        id: 'e',
        projectId: 'p',
        title: 'Prototype',
        progress: 'prototyping',
        content: content,
      );
      expect(journalEntryIsComplete(entry()), isTrue);
      prototype[type == 'building' ? 'summary' : 'method'] = '';
      expect(journalEntryIsComplete(entry()), isFalse);
      prototype[type == 'building' ? 'summary' : 'method'] = 'Measured results';
      content.last['nextSteps'] = '';
      expect(journalEntryIsComplete(entry()), isFalse);
    });
  }

  test(
    'completion requires submitted required inputs, while optional fields stay optional',
    () {
      final content = <Map<String, dynamic>>[
        {
          'stage': 'observations',
          'observed': 'Observation',
          'known': 'Background',
        },
        {
          'stage': 'analyze',
          'rootCauses': [
            {
              'title': 'Cause',
              'description': 'Description',
              'reason': 'Reason',
            },
          ],
          'patternChange': 'Reduction',
          'patternExplanation': 'Reason',
        },
        {
          'stage': 'question',
          'questions': [
            {'type': 'How', 'text': 'How?'},
          ],
        },
        {
          'stage': 'learning',
          'inquiryLens': 'Observe',
          'dci': ['DCI'],
          'sep': ['SEP'],
          'ccc': ['CCC'],
        },
        {
          'stage': 'nextAction',
          'submitted': true,
          'learned': 'Learning',
          'challenges': 'Challenge',
          'nextSteps': 'Next',
        },
      ];
      JournalEntry entry() => JournalEntry(
        id: 'test',
        projectId: 'test',
        title: 'Entry',
        content: content,
      );
      expect(journalEntryIsComplete(entry()), true);
      content.last['learned'] = '';
      content.last['submitted'] = true;
      expect(journalEntryIsComplete(entry()), false);
      content.last['learned'] = 'Learning';
      content[3]['sep'] = [];
      expect(journalEntryIsComplete(entry()), false);
      content[3]['sep'] = ['SEP'];
      content[1]['rootCauses'] = [];
      expect(journalEntryIsComplete(entry()), false);
    },
  );
}
