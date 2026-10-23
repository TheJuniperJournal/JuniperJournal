import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/features/learning_module/pages/assessment_block.dart';

void main() {
  test('blank assessment defaults do not count as entered content', () {
    for (final multiple in [false, true]) {
      expect(
        AssessmentBlockData(
          type: AssessmentType.multipleChoice,
          data: {
            'question': '',
            'options': ['', ''],
            'correct_index': null,
            'allow_multiple': multiple,
            'correct_indices': [],
            'explanation': '',
          },
        ).hasDraft,
        false,
      );
    }
    expect(
      const AssessmentBlockData(
        type: AssessmentType.matching,
        data: {
          'top_items': ['', ''],
          'bottom_items': ['', ''],
          'correct_mapping': {'A': 'A', 'B': 'B'},
        },
      ).hasDraft,
      false,
    );
    expect(
      const AssessmentBlockData(
        type: AssessmentType.paragraph,
        data: {
          'question': '',
          'response_length': 'short',
          'max_characters': 300,
        },
      ).hasDraft,
      false,
    );
    expect(
      const AssessmentBlockData(
        type: AssessmentType.matching,
        data: {
          'top_items': ['term', ''],
          'bottom_items': ['', ''],
        },
      ).hasDraft,
      true,
    );
    expect(
      const AssessmentBlockData(
        type: AssessmentType.numeric,
        data: {'correct_answer': '0'},
      ).hasDraft,
      true,
    );
  });
}
