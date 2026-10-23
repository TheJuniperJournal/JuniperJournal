import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/security/input_validator.dart';

void main() {
  test('legacy subject and topic tags remain valid when saving settings', () {
    expect(
      InputValidator.tags([
        'Engineering & Design|Designing Solutions and Prototyping',
        'Environment & Sustainability|Ecosystems & Biodiversity',
      ]),
      isNull,
    );
  });
  test(
    'ordinary tag and structured component length limits remain enforced',
    () {
      final long = 'x' * 51;
      expect(InputValidator.tags([long]), isNotNull);
      expect(
        InputValidator.tags(['Environment & Sustainability|$long']),
        isNotNull,
      );
      expect(InputValidator.tags(['x' * 50 + '|' + 'y' * 50]), isNull);
      expect(InputValidator.tags(['x' * 50 + '||']), isNotNull);
    },
  );
  test('tag count limit is unchanged', () {
    expect(InputValidator.tags(List.filled(11, 'Water')), isNotNull);
  });
}
