import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/features/learning_module/pages/table_block_editor.dart';

void main() {
  test('new table starts with three named columns and three rows', () {
    final table = TableBlockData.initial();
    expect(table.title, isEmpty);
    expect(table.columns, hasLength(3));
    expect(table.columns.first.name, 'Column 1');
    expect(table.rowCount, 3);
    expect(table.rows, isEmpty);
    expect(TableBlockData.fromJson({}).rowCount, 1);
    expect(TableBlockData.fromJson({}).columns, hasLength(3));
  });
  test('blank defaults preserve saved columns, rows and values', () {
    final saved = TableBlockData.fromJson({
      'title': 'Measurements',
      'columns': [
        {'id': 'a', 'name': 'Date', 'order_index': 0},
        {'id': 'b', 'name': 'Height', 'order_index': 1},
      ],
      'row_count': 2,
      'rows': [
        {'a': 'Monday', 'b': '12'},
        {'a': 'Tuesday', 'b': '14'},
      ],
    });
    expect(saved.columns.map((column) => column.name), ['Date', 'Height']);
    expect(saved.rowCount, 2);
    expect(saved.rows.last['b'], '14');
    final roundTrip = TableBlockData.fromJson(saved.toJson());
    expect(roundTrip.rows, saved.rows);
  });
}
