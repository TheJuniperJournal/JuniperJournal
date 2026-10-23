import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import '../../../shared/widgets/evidence_cell_field.dart';
import 'package:juniper_journal/src/shared/widgets/journal_section_header.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'package:juniper_journal/src/shared/widgets/evidence_block_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:juniper_journal/src/features/learning_module/pages/assessment_block.dart';
import 'package:juniper_journal/src/features/learning_module/pages/inquiry_lens_selector.dart';

class TableBlockData {
  final String title;
  final List<TableColumnData> columns;
  final int rowCount;
  final List<Map<String, String>> rows;
  final String inquiryLens;
  final InquiryLensData inquiryLensData;
  final AssessmentBlockData assessment;

  const TableBlockData({
    this.title = '',
    this.columns = const [],
    this.rowCount = 1,
    this.rows = const [],
    this.inquiryLens = 'None',
    this.inquiryLensData = const InquiryLensData(),
    this.assessment = const AssessmentBlockData(),
  });

  factory TableBlockData.initial() => const TableBlockData(
    columns: [
      TableColumnData(id: 'col-1', name: 'Column 1', orderIndex: 0),
      TableColumnData(id: 'col-2', name: 'Column 2', orderIndex: 1),
      TableColumnData(id: 'col-3', name: 'Column 3', orderIndex: 2),
    ],
    rowCount: 3,
  );

  String get cardSubtitle {
    if (title.trim().isNotEmpty) return title.trim();
    final names = columns
        .map((column) => column.name.trim())
        .where((name) => name.isNotEmpty);
    if (names.isNotEmpty) return names.join(', ');
    return 'Organize data in rows and columns.';
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'columns': [for (final column in columns) column.toJson()],
    'row_count': rowCount,
    'rows': rows,
    'inquiry_lens': inquiryLens,
    'inquiry_lens_data': inquiryLensData.toJson(),
    'inquiry': inquiryLensData.toPreviewJson(),
    'assessment': assessment.toJson(),
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  factory TableBlockData.fromJson(Map<String, dynamic> json) {
    final rawColumns = json['columns'];
    final columns = rawColumns is List
        ? [
            for (final item in rawColumns)
              if (item is Map)
                TableColumnData.fromJson(Map<String, dynamic>.from(item)),
          ]
        : <TableColumnData>[];
    final rawRows = json['rows'];
    final rows = rawRows is List
        ? [
            for (final row in rawRows)
              if (row is Map)
                {
                  for (final entry in row.entries)
                    entry.key.toString(): entry.value?.toString() ?? '',
                },
          ]
        : <Map<String, String>>[];
    return TableBlockData(
      title: json['title']?.toString() ?? '',
      columns: [
        ...(columns.isEmpty ? TableBlockData.initial().columns : columns),
      ]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)),
      rowCount:
          int.tryParse(json['row_count']?.toString() ?? '') ??
          (rows.isEmpty ? 1 : rows.length),
      rows: rows,
      inquiryLens: json['inquiry_lens']?.toString() ?? 'None',
      inquiryLensData: InquiryLensData.fromJson(
        json['inquiry_lens_data'],
        legacyLens: json['inquiry_lens']?.toString() ?? 'None',
      ),
      assessment: AssessmentBlockData.fromJson(json['assessment']),
    );
  }
}

class TableColumnData {
  final String id;
  final String name;
  final int orderIndex;

  const TableColumnData({
    required this.id,
    required this.name,
    required this.orderIndex,
  });

  TableColumnData copyWith({String? name, int? orderIndex}) {
    return TableColumnData(
      id: id,
      name: name ?? this.name,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'order_index': orderIndex,
  };

  factory TableColumnData.fromJson(Map<String, dynamic> json) {
    return TableColumnData(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      orderIndex: int.tryParse(json['order_index']?.toString() ?? '') ?? 0,
    );
  }
}

class TableBlockEditorScreen extends StatefulWidget {
  final TableBlockData? initialData;

  const TableBlockEditorScreen({super.key, this.initialData});

  @override
  State<TableBlockEditorScreen> createState() => _TableBlockEditorScreenState();
}

class _TableBlockEditorScreenState extends State<TableBlockEditorScreen> {
  static const _green = Color(0xFF5DB075);
  static const _text = Color(0xFF141414);
  static const _muted = Color(0xFFCECECE);
  static const _border = Color(0xFFD8D0D0);
  static const _error = Color(0xFFFD1212);
  static const _screenWidth = 393.0;
  static const _minRows = 1;
  static const _maxRows = 20;
  static const _minColumns = 1;
  static const _maxColumns = 6;

  late final TextEditingController _titleController;
  late List<TableColumnData> _columns;
  late List<TextEditingController> _columnControllers;
  late List<Map<String, String>> _rows;
  int _rowCount = 1;
  InquiryLensData _inquiryLensData = const InquiryLensData();
  AssessmentBlockData _assessment = const AssessmentBlockData();
  bool _showValidation = false;
  bool _saving = false;

  bool get _isEditing => widget.initialData != null;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData ?? TableBlockData.initial();
    _titleController = TextEditingController(text: data.title)
      ..addListener(_refresh);
    _columns = _normalizeColumns(data.columns);
    _columnControllers = [
      for (final column in _columns)
        TextEditingController(text: column.name)..addListener(_refresh),
    ];
    _rowCount = data.rowCount.clamp(_minRows, _maxRows);
    _rows = _normalizeRows(data.rows, _rowCount);
    _inquiryLensData = data.inquiryLensData.selectLens(data.inquiryLens);
    _assessment = data.assessment;
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final controller in _columnControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<TableColumnData> _normalizeColumns(List<TableColumnData> columns) {
    final source = columns.isEmpty ? TableBlockData.initial().columns : columns;
    return [
      for (var index = 0; index < source.length; index++)
        source[index].copyWith(orderIndex: index),
    ];
  }

  List<Map<String, String>> _normalizeRows(
    List<Map<String, String>> rows,
    int rowCount,
  ) {
    return [
      for (var rowIndex = 0; rowIndex < rowCount; rowIndex++)
        {
          for (final column in _columns)
            column.id: rowIndex < rows.length
                ? rows[rowIndex][column.id]?.toString() ?? ''
                : '',
        },
    ];
  }

  bool get _hasValidColumns =>
      _columnControllers.isNotEmpty &&
      _columnControllers.every(
        (controller) => controller.text.trim().isNotEmpty,
      );

  bool get _hasValidCells =>
      _rows.any((row) => row.values.any((value) => value.trim().isNotEmpty));

  bool get _canSave =>
      _hasValidColumns &&
      _rowCount >= _minRows &&
      _rowCount <= _maxRows &&
      _hasValidCells &&
      !_saving;

  void _addColumn() {
    if (_columns.length >= _maxColumns) return;
    setState(() {
      final index = _columns.length;
      final column = TableColumnData(
        id: 'col-${DateTime.now().microsecondsSinceEpoch}',
        name: '',
        orderIndex: index,
      );
      _columns.add(column);
      _columnControllers.add(TextEditingController()..addListener(_refresh));
      for (final row in _rows) {
        row[column.id] = '';
      }
    });
  }

  Future<void> _removeColumn(int index) async {
    if (_columns.length <= _minColumns) return;
    final column = _columns[index];
    final hasValues = _rows.any((row) => (row[column.id] ?? '').isNotEmpty);
    if (hasValues) {
      final confirmed = await _confirm(
        title: 'Delete column?',
        message: 'Deleting this column will remove its cell values.',
      );
      if (!confirmed) return;
    }
    setState(() {
      _columns.removeAt(index);
      _columnControllers.removeAt(index).dispose();
      for (final row in _rows) {
        row.remove(column.id);
      }
      _reindexColumns();
    });
  }

  void _reorderColumn(int oldIndex, int newIndex) {
    setState(() {
      final column = _columns.removeAt(oldIndex);
      final controller = _columnControllers.removeAt(oldIndex);
      _columns.insert(newIndex, column);
      _columnControllers.insert(newIndex, controller);
      _reindexColumns();
    });
  }

  void _reindexColumns() {
    _columns = [
      for (var index = 0; index < _columns.length; index++)
        _columns[index].copyWith(orderIndex: index),
    ];
  }

  Future<void> _changeRows(int nextCount) async {
    nextCount = nextCount.clamp(_minRows, _maxRows);
    if (nextCount == _rowCount) return;
    if (nextCount < _rowCount) {
      final removedRows = _rows.sublist(nextCount);
      final hasValues = removedRows.any(
        (row) => row.values.any((value) => value.trim().isNotEmpty),
      );
      if (hasValues) {
        final confirmed = await _confirm(
          title: 'Remove rows?',
          message: 'Removing rows will delete values in trailing rows.',
        );
        if (!confirmed) return;
      }
    }
    setState(() {
      if (nextCount > _rowCount) {
        for (var index = _rowCount; index < nextCount; index++) {
          _rows.add({for (final column in _columns) column.id: ''});
        }
      } else {
        _rows = _rows.take(nextCount).toList();
      }
      _rowCount = nextCount;
    });
  }

  void _addRow() => _changeRows(_rowCount + 1);

  Future<void> _removeRow(int index) async {
    if (_rowCount <= _minRows) return;
    final row = _rows[index];
    if (row.values.any((value) => value.trim().isNotEmpty)) {
      final confirmed = await _confirm(
        title: 'Delete row?',
        message: 'Deleting this row will remove its cell values.',
      );
      if (!confirmed) return;
    }
    setState(() {
      _rows.removeAt(index);
      _rowCount = _rows.length;
    });
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  void _saveBlock() {
    setState(() => _showValidation = true);
    if (!_canSave) return;
    setState(() => _saving = true);
    Navigator.of(context).pop(
      TableBlockData(
        title: _titleController.text.trim(),
        columns: [
          for (var index = 0; index < _columns.length; index++)
            _columns[index].copyWith(
              name: _columnControllers[index].text.trim(),
              orderIndex: index,
            ),
        ],
        rowCount: _rowCount,
        rows: [
          for (final row in _rows)
            {for (final column in _columns) column.id: row[column.id] ?? ''},
        ],
        inquiryLens: _inquiryLensData.selectedLens,
        inquiryLensData: _inquiryLensData,
        assessment: _assessment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: JournalPageLayout.widthFor(
                context,
                mobileWidth: _screenWidth,
              ),
            ),
            child: Column(
              children: [
                _Header(onBack: () => Navigator.of(context).pop()),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 23, 18, 38),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel(label: 'Content'),
                        const SizedBox(height: AppMetrics.labelGap),
                        _FieldLabel(label: 'Title', optional: true),
                        const SizedBox(height: 10),
                        _TitleField(controller: _titleController),
                        const SizedBox(height: 13),
                        const _FieldLabel(label: 'Columns'),
                        const SizedBox(height: 11),
                        _ColumnList(
                          columns: _columns,
                          controllers: _columnControllers,
                          showValidation: _showValidation,
                          onReorder: _reorderColumn,
                          onDelete: _removeColumn,
                        ),
                        const SizedBox(height: 23),
                        Center(
                          child: _OutlineActionButton(
                            label: '+ Add Column',
                            width: 242,
                            onTap: _columns.length >= _maxColumns
                                ? null
                                : _addColumn,
                          ),
                        ),
                        const SizedBox(height: AppMetrics.fieldGap),
                        const _FieldLabel(label: 'Rows'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _RowStepper(
                              value: _rowCount,
                              onIncrement: () => _changeRows(_rowCount + 1),
                              onDecrement: () => _changeRows(_rowCount - 1),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'rows',
                              style: TextStyle(
                                color: Color(0xB3000000),
                                fontSize: AppTypography.helperSize,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _TableGrid(
                          columns: _columns,
                          columnControllers: _columnControllers,
                          rows: _rows,
                          showValidation: _showValidation,
                          onCellChanged: (rowIndex, columnId, value) {
                            setState(() => _rows[rowIndex][columnId] = value);
                          },
                          onDeleteRow: _removeRow,
                        ),
                        const SizedBox(height: AppMetrics.fieldGap),
                        Center(
                          child: _OutlineActionButton(
                            label: '+ Add Row',
                            width: 242,
                            onTap: _rowCount >= _maxRows ? null : _addRow,
                          ),
                        ),
                        const SizedBox(height: 29),

                        if (_showValidation && !_canSave) ...[
                          const SizedBox(height: 9),
                          const Text(
                            'Name each column and enter at least one table value.',
                            style: TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              color: _error,
                              fontSize: AppTypography.helperSize,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                        const SizedBox(height: 39),
                        Center(
                          child: SizedBox(
                            width: 130,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _canSave ? _saveBlock : null,
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: _green,
                                disabledBackgroundColor: const Color(
                                  0xFFB8D8C1,
                                ),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _saving
                                    ? 'Saving...'
                                    : (_isEditing ? 'Save' : 'Add Block'),
                                style: const TextStyle(
                                  fontFamily: AppTypography.bodyFamily,
                                  fontSize: AppTypography.buttonSize,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) =>
      EvidenceBlockHeader(title: 'Table Block', onBack: onBack);
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool optional;

  const _FieldLabel({required this.label, this.optional = false});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: label,
        style: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          color: _TableBlockEditorScreenState._text,
          fontSize: AppTypography.bodySize,
          fontWeight: FontWeight.w500,
        ),
        children: [
          if (optional)
            const TextSpan(
              text: ' (Optional)',
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: _TableBlockEditorScreenState._muted,
                fontSize: AppTypography.helperSize,
              ),
            ),
        ],
      ),
    );
  }
}

class _TitleField extends StatelessWidget {
  final TextEditingController controller;

  const _TitleField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Stack(
        children: [
          SizedBox(
            height: 64,
            child: TextField(
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              controller: controller,
              maxLength: 100,
              decoration: InputDecoration(
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 8,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: _TableBlockEditorScreenState._green,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: _TableBlockEditorScreenState._green,
                  ),
                ),
              ),
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.bodySize,
              ),
            ),
          ),
          Positioned(right: 2, top: 38, child: const SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _ColumnList extends StatelessWidget {
  final List<TableColumnData> columns;
  final List<TextEditingController> controllers;
  final bool showValidation;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<int> onDelete;

  const _ColumnList({
    required this.columns,
    required this.controllers,
    required this.showValidation,
    required this.onReorder,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _TableBlockEditorScreenState._border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorderItem: onReorder,
        itemCount: columns.length,
        itemBuilder: (context, index) {
          return _ColumnRow(
            key: ValueKey(columns[index].id),
            index: index,
            controller: controllers[index],
            showError: showValidation && controllers[index].text.trim().isEmpty,
            onDelete: () => onDelete(index),
          );
        },
      ),
    );
  }
}

class _ColumnRow extends StatelessWidget {
  final int index;
  final TextEditingController controller;
  final bool showError;
  final VoidCallback onDelete;

  const _ColumnRow({
    super.key,
    required this.index,
    required this.controller,
    required this.showError,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 59,
      decoration: BoxDecoration(
        border: index == 0
            ? null
            : const Border(top: BorderSide(color: Color(0xFFE6E6E6))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 27),
          ReorderableDragStartListener(
            index: index,
            child: SvgPicture.asset(
              'assets/learning_module/table_block_toggle.svg',
              width: 12,
              height: 22,
            ),
          ),
          const SizedBox(width: 31),
          Expanded(
            child: TextField(
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              controller: controller,
              maxLength: 40,
              decoration: InputDecoration(
                counterText: '',
                border: InputBorder.none,
                focusedBorder: showError
                    ? const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: _TableBlockEditorScreenState._error,
                        ),
                      )
                    : InputBorder.none,
                enabledBorder: showError
                    ? const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: _TableBlockEditorScreenState._error,
                        ),
                      )
                    : InputBorder.none,
              ),
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: _TableBlockEditorScreenState._text,
                fontSize: AppTypography.bodySize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          AppTapTarget(
            behavior: HitTestBehavior.opaque,
            onTap: onDelete,
            child: SvgPicture.asset(
              'assets/learning_module/table_block_delete.svg',
              width: 13,
              height: 13,
            ),
          ),
          const SizedBox(width: 18),
        ],
      ),
    );
  }
}

class _RowStepper extends StatelessWidget {
  final int value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _RowStepper({
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 89,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE8EBEC)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                '$value',
                style: const TextStyle(
                  color: Color(0xFF323639),
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Container(width: 1, color: const Color(0xFFE8EBEC)),
          SizedBox(
            width: 43,
            child: Stack(
              children: [
                Positioned.fill(
                  child: SvgPicture.asset(
                    'assets/learning_module/table_block_up_down.svg',
                    width: 16,
                    height: 16,
                    fit: BoxFit.scaleDown,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 22,
                  child: AppTapTarget(
                    behavior: HitTestBehavior.translucent,
                    onTap: onIncrement,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 22,
                  child: AppTapTarget(
                    behavior: HitTestBehavior.translucent,
                    onTap: onDecrement,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TableGrid extends StatelessWidget {
  final List<TableColumnData> columns;
  final List<TextEditingController> columnControllers;
  final List<Map<String, String>> rows;
  final bool showValidation;
  final void Function(int rowIndex, String columnId, String value)
  onCellChanged;
  final ValueChanged<int> onDeleteRow;

  const _TableGrid({
    required this.columns,
    required this.columnControllers,
    required this.rows,
    required this.showValidation,
    required this.onCellChanged,
    required this.onDeleteRow,
  });

  @override
  Widget build(BuildContext context) {
    final available =
        JournalPageLayout.widthFor(context, mobileWidth: 393) - 42;
    final cellWidth = ((available - 48) / columns.length).clamp(140.0, 320.0);
    final gridWidth = cellWidth * columns.length + 48;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: gridWidth,
        child: Table(
          border: TableBorder.all(color: const Color(0xFFC9C9C9)),
          columnWidths: {
            for (var index = 0; index < columns.length; index++)
              index: FixedColumnWidth(cellWidth),
            columns.length: const FixedColumnWidth(48),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFCFCFCF)),
              children: [
                for (final label in [
                  for (final controller in columnControllers)
                    _shortHeader(controller.text.trim()),
                  '',
                ])
                  _HeaderCell(label: label),
              ],
            ),
            for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
              TableRow(
                children: [
                  for (final column in columns)
                    _EditableCell(
                      key: ValueKey('$rowIndex-${column.id}'),
                      initialValue: rows[rowIndex][column.id] ?? '',
                      showError: showValidation && false,
                      onChanged: (value) {
                        onCellChanged(rowIndex, column.id, value);
                      },
                    ),
                  _DeleteRowCell(onTap: () => onDeleteRow(rowIndex)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _shortHeader(String value) {
    if (value == 'Plant Height') return 'Height';
    return value;
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;

  const _HeaderCell({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: AppColors.textPrimary,
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _EditableCell extends StatefulWidget {
  final String initialValue;
  final bool showError;
  final ValueChanged<String> onChanged;

  const _EditableCell({
    super.key,
    required this.initialValue,
    required this.showError,
    required this.onChanged,
  });

  @override
  State<_EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<_EditableCell> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _EditableCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.initialValue)
      _controller.text = widget.initialValue;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      color: widget.showError ? const Color(0xFFFFEEEE) : Colors.white,
      alignment: Alignment.center,
      child: EvidenceCellField(
        controller: _controller,
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _DeleteRowCell extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteRowCell({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Center(
        child: AppTapTarget(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SvgPicture.asset(
            'assets/learning_module/table_block_delete.svg',
            width: 13,
            height: 13,
          ),
        ),
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  final String label;
  final double width;
  final VoidCallback? onTap;

  const _OutlineActionButton({
    required this.label,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: _TableBlockEditorScreenState._green,
          disabledForegroundColor: const Color(0xFFB8D8C1),
          side: BorderSide(
            color: onTap == null
                ? const Color(0xFFB8D8C1)
                : _TableBlockEditorScreenState._green,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.buttonSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _DropdownField extends StatelessWidget {
  final String displayValue;
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const _DropdownField({
    required this.displayValue,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onSelected,
      offset: const Offset(0, 47),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<String>(value: option, height: 38, child: Text(option)),
      ],
      child: Container(
        height: 47,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: _TableBlockEditorScreenState._green),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayValue,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: _TableBlockEditorScreenState._text,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SvgPicture.asset(
              'assets/learning_module/text_block_chevron.svg',
              width: 13,
              height: 13,
              colorFilter: const ColorFilter.mode(
                Color(0xFF8BD5A0),
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
