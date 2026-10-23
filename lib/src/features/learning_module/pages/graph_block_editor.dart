import '../../../shared/widgets/evidence_cell_field.dart';
import 'package:juniper_journal/src/shared/widgets/journal_section_header.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'package:juniper_journal/src/shared/widgets/evidence_block_header.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:juniper_journal/src/features/learning_module/pages/assessment_block.dart';
import 'package:juniper_journal/src/features/learning_module/pages/inquiry_lens_selector.dart';

enum GraphType {
  bar('bar', 'Bar Graph', 'Compare values across different categories.'),
  scatter(
    'scatter',
    'Scatter Plot',
    'Identify relationships and patterns between variables.',
  ),
  line('line', 'Line Graph', 'Show changes and trends over time.'),
  pie('pie', 'Pie Chart', 'Display parts of a whole or percentage breakdowns.');

  final String storageValue;
  final String label;
  final String description;

  const GraphType(this.storageValue, this.label, this.description);

  static GraphType fromStorage(String? value) {
    for (final type in values) {
      if (type.storageValue == value || type.label == value) return type;
    }
    return GraphType.line;
  }
}

class GraphBlockData {
  final String id;
  final String title;
  final GraphType graphType;
  final String xAxisLabel;
  final String yAxisLabel;
  final String caption;
  final List<GraphDataRow> rows;
  final String inquiryLens;
  final InquiryLensData inquiryLensData;
  final AssessmentBlockData assessment;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GraphBlockData({
    required this.id,
    this.title = '',
    this.graphType = GraphType.line,
    this.xAxisLabel = '',
    this.yAxisLabel = '',
    this.caption = '',
    this.rows = const [],
    this.inquiryLens = 'None',
    this.inquiryLensData = const InquiryLensData(),
    this.assessment = const AssessmentBlockData(),
    required this.createdAt,
    required this.updatedAt,
  });

  String get cardSubtitle {
    if (title.trim().isNotEmpty) return title.trim();
    return graphType.label;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'graph_type': graphType.storageValue,
    'x_axis_label': xAxisLabel,
    'y_axis_label': yAxisLabel,
    'caption': caption,
    'rows': [for (final row in rows) row.toJson()],
    'inquiry_lens': inquiryLens,
    'inquiry_lens_data': inquiryLensData.toJson(),
    'inquiry': inquiryLensData.toPreviewJson(),
    'assessment': assessment.toJson(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory GraphBlockData.fromJson(Map<String, dynamic> json) {
    final rawRows = json['rows'];
    return GraphBlockData(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      graphType: GraphType.fromStorage(json['graph_type']?.toString()),
      xAxisLabel: json['x_axis_label']?.toString() ?? '',
      yAxisLabel: json['y_axis_label']?.toString() ?? '',
      caption: json['caption']?.toString() ?? '',
      rows: rawRows is List
          ? [
              for (final item in rawRows)
                if (item is Map)
                  GraphDataRow.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
      inquiryLens: json['inquiry_lens']?.toString() ?? 'None',
      inquiryLensData: InquiryLensData.fromJson(
        json['inquiry_lens_data'],
        legacyLens: json['inquiry_lens']?.toString() ?? 'None',
      ),
      assessment: AssessmentBlockData.fromJson(json['assessment']),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class GraphDataRow {
  final String x;
  final String y;

  const GraphDataRow({this.x = '', this.y = ''});

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory GraphDataRow.fromJson(Map<String, dynamic> json) {
    return GraphDataRow(
      x: json['x']?.toString() ?? '',
      y: json['y']?.toString() ?? '',
    );
  }
}

class GraphBlockEditorScreen extends StatefulWidget {
  final GraphBlockData? initialData;

  const GraphBlockEditorScreen({super.key, this.initialData});

  @override
  State<GraphBlockEditorScreen> createState() => _GraphBlockEditorScreenState();
}

class _GraphBlockEditorScreenState extends State<GraphBlockEditorScreen> {
  static const _green = Color(0xFF5DB075);
  static const _text = Color(0xFF141414);
  static const _muted = Color(0xFF666666);
  static const _error = Color(0xFFD12E2E);
  static const _screenWidth = 393.0;

  late final TextEditingController _titleController;
  late final TextEditingController _xAxisController;
  late final TextEditingController _yAxisController;
  late final TextEditingController _captionController;
  late List<TextEditingController> _xControllers;
  late List<TextEditingController> _yControllers;
  late GraphType _graphType;
  late InquiryLensData _inquiryLensData;
  late AssessmentBlockData _assessment;
  bool _showValidation = false;
  bool _saving = false;

  bool get _isEditing => widget.initialData != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final data =
        widget.initialData ??
        GraphBlockData(
          id: 'graph-${now.microsecondsSinceEpoch}',
          createdAt: now,
          updatedAt: now,
          rows: const [GraphDataRow()],
        );
    _titleController = TextEditingController(text: data.title)
      ..addListener(_refresh);
    _xAxisController = TextEditingController(text: data.xAxisLabel)
      ..addListener(_refresh);
    _yAxisController = TextEditingController(text: data.yAxisLabel)
      ..addListener(_refresh);
    _captionController = TextEditingController(text: data.caption)
      ..addListener(_refresh);
    _graphType = data.graphType;
    _inquiryLensData = data.inquiryLensData.selectLens(data.inquiryLens);
    _assessment = data.assessment;
    final rows = data.rows.isEmpty ? const [GraphDataRow()] : data.rows;
    _xControllers = [
      for (final row in rows)
        TextEditingController(text: row.x)..addListener(_refresh),
    ];
    _yControllers = [
      for (final row in rows)
        TextEditingController(text: row.y)..addListener(_refresh),
    ];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _xAxisController.dispose();
    _yAxisController.dispose();
    _captionController.dispose();
    for (final controller in [..._xControllers, ..._yControllers]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool get _hasValidRows {
    final rows = _rows;
    if (rows.length < (_graphType == GraphType.pie ? 2 : 1)) return false;
    if (_graphType == GraphType.pie) {
      var total = 0.0;
      for (final row in rows) {
        if (row.x.trim().isEmpty) return false;
        final percent = double.tryParse(row.y.trim());
        if (percent == null || percent <= 0) return false;
        total += percent;
      }
      return (total - 100).abs() <= 0.01;
    }
    for (final row in rows) {
      if (double.tryParse(row.x.trim()) == null ||
          double.tryParse(row.y.trim()) == null) {
        return false;
      }
    }
    return true;
  }

  bool get _hasAxisLabels =>
      _xAxisController.text.trim().isNotEmpty &&
      _yAxisController.text.trim().isNotEmpty;
  bool get _canSave => _hasValidRows && _hasAxisLabels && !_saving;

  List<GraphDataRow> get _rows => [
    for (var index = 0; index < _xControllers.length; index++)
      if (_xControllers[index].text.trim().isNotEmpty ||
          _yControllers[index].text.trim().isNotEmpty)
        GraphDataRow(
          x: _xControllers[index].text.trim(),
          y: _yControllers[index].text.trim(),
        ),
  ];

  void _addRow() {
    setState(() {
      _xControllers.add(TextEditingController()..addListener(_refresh));
      _yControllers.add(TextEditingController()..addListener(_refresh));
    });
  }

  void _removeRow(int index) {
    if (_xControllers.length <= 1) return;
    setState(() {
      _xControllers.removeAt(index).dispose();
      _yControllers.removeAt(index).dispose();
    });
  }

  Future<void> _selectGraphType() async {
    final selected = await showAppModalBottomSheet<GraphType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _GraphTypeSheet(selected: _graphType),
    );
    if (selected != null) {
      setState(() => _graphType = selected);
    }
  }

  void _save() {
    setState(() => _showValidation = true);
    if (!_canSave) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final existing = widget.initialData;
    Navigator.of(context).pop(
      GraphBlockData(
        id: existing?.id ?? 'graph-${now.microsecondsSinceEpoch}',
        title: _titleController.text.trim(),
        graphType: _graphType,
        xAxisLabel: _xAxisController.text.trim(),
        yAxisLabel: _yAxisController.text.trim(),
        caption: _captionController.text.trim(),
        rows: _rows,
        inquiryLens: _inquiryLensData.selectedLens,
        inquiryLensData: _inquiryLensData,
        assessment: _assessment,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chartRows = _rows;
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
                    padding: const EdgeInsets.fromLTRB(24, 22, 18, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel('Content'),
                        const SizedBox(height: AppMetrics.labelGap),
                        const _Label('Title', optional: true),
                        const SizedBox(height: 10),
                        _Input(
                          controller: _titleController,
                          maxLength: 100,
                          height: 64,
                          maxLines: 1,
                        ),
                        const SizedBox(height: AppMetrics.fieldGap),
                        const _Label('Graph Type'),
                        const SizedBox(height: 10),
                        _SelectBox(
                          label: _graphType.label,
                          icon: _GraphGlyph(type: _graphType),
                          onTap: _selectGraphType,
                        ),
                        const SizedBox(height: 12),
                        _GraphTable(
                          graphType: _graphType,
                          xControllers: _xControllers,
                          yControllers: _yControllers,
                          showValidation: _showValidation,
                          onDelete: _removeRow,
                        ),
                        const SizedBox(height: AppMetrics.fieldGap),
                        Center(
                          child: _OutlineButton(
                            label: '+ Add Row',
                            onTap: _addRow,
                          ),
                        ),
                        const SizedBox(height: 25),
                        const _Label('Axis Labels'),
                        const SizedBox(height: AppMetrics.labelGap),
                        _SmallInput(
                          label: _graphType == GraphType.pie
                              ? 'Label Column Name'
                              : 'X-Axis Label',
                          controller: _xAxisController,
                          showError: _showValidation,
                        ),
                        const SizedBox(height: 12),
                        _SmallInput(
                          label: _graphType == GraphType.pie
                              ? 'Percent Column Name'
                              : 'Y-Axis Label',
                          controller: _yAxisController,
                          showError: _showValidation,
                        ),
                        const SizedBox(height: 25),
                        const _Label('Preview'),
                        const SizedBox(height: 12),
                        _ChartPreview(
                          rows: chartRows,
                          graphType: _graphType,
                          title: _titleController.text.trim(),
                          xAxisLabel: _xAxisController.text.trim(),
                          yAxisLabel: _yAxisController.text.trim(),
                        ),
                        const SizedBox(height: 25),
                        const _Label('Caption', optional: true),
                        const SizedBox(height: 8),
                        const Text(
                          'Add specific description of the graph.',
                          style: AppTypography.helper,
                        ),
                        const SizedBox(height: 12),
                        _Input(
                          controller: _captionController,
                          maxLength: 300,
                          height: 92,
                          maxLines: 4,
                          hintText: '',
                        ),
                        const SizedBox(height: AppMetrics.fieldGap),

                        if (_showValidation && !_canSave) ...[
                          const SizedBox(height: 10),
                          Text(
                            !_hasAxisLabels
                                ? 'Enter both axis or column labels.'
                                : _graphType == GraphType.pie
                                ? 'Enter at least two pie rows and make percentages total 100.'
                                : 'Enter valid numeric graph values before saving.',
                            style: const TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              color: _error,
                              fontSize: AppTypography.helperSize,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                        const SizedBox(height: 34),
                        Center(
                          child: SizedBox(
                            width: 130,
                            height: 32,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _save,
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
      EvidenceBlockHeader(title: 'Graph Block', onBack: onBack);
}

class _GraphTypeSheet extends StatelessWidget {
  final GraphType selected;

  const _GraphTypeSheet({required this.selected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 385,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _GraphBlockEditorScreenState._green),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
                  child: _Label('Graph Type'),
                ),
                for (final type in GraphType.values) ...[
                  ListTile(
                    leading: _GraphGlyph(type: type),
                    title: Text(
                      type.label,
                      style: const TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        fontSize: AppTypography.bodySize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      type.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        fontSize: AppTypography.helperSize,
                      ),
                    ),
                    trailing: type == selected
                        ? const Icon(
                            Icons.check,
                            color: _GraphBlockEditorScreenState._green,
                          )
                        : const Icon(Icons.chevron_right, size: 18),
                    onTap: () => Navigator.of(context).pop(type),
                  ),
                  if (type != GraphType.values.last)
                    const Divider(height: 1, color: Color(0xFFE6E6E6)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GraphTable extends StatelessWidget {
  final GraphType graphType;
  final List<TextEditingController> xControllers;
  final List<TextEditingController> yControllers;
  final bool showValidation;
  final ValueChanged<int> onDelete;

  const _GraphTable({
    required this.graphType,
    required this.xControllers,
    required this.yControllers,
    required this.showValidation,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final left = graphType == GraphType.pie ? 'Item/Label' : 'X-Value';
    final right = graphType == GraphType.pie ? 'Percent of Pie' : 'Y-Value';
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCFCFCF)),
      ),
      child: Column(
        children: [
          Container(
            height: 49,
            color: const Color(0xFFD8D8D8),
            child: Row(
              children: [
                Expanded(child: Center(child: _TableHeader(left))),
                const VerticalDivider(width: 1, color: Color(0xFFBFBFBF)),
                Expanded(child: Center(child: _TableHeader(right))),
                const SizedBox(width: 38),
              ],
            ),
          ),
          for (var index = 0; index < xControllers.length; index++)
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: _CellField(
                      controller: xControllers[index],
                      numeric: graphType != GraphType.pie,
                      error:
                          showValidation &&
                          xControllers[index].text.trim().isNotEmpty &&
                          graphType != GraphType.pie &&
                          double.tryParse(xControllers[index].text.trim()) ==
                              null,
                    ),
                  ),
                  const VerticalDivider(width: 1, color: Color(0xFFD2D2D2)),
                  Expanded(
                    child: _CellField(
                      controller: yControllers[index],
                      numeric: true,
                      error:
                          showValidation &&
                          yControllers[index].text.trim().isNotEmpty &&
                          double.tryParse(yControllers[index].text.trim()) ==
                              null,
                    ),
                  ),
                  SizedBox(
                    width: 38,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: xControllers.length > 1
                          ? () => onDelete(index)
                          : null,
                      icon: SvgPicture.asset(
                        'assets/learning_module/learning_objective_trash.svg',
                        width: 14,
                        height: 14,
                      ),
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

class _ChartPreview extends StatelessWidget {
  final List<GraphDataRow> rows;
  final GraphType graphType;
  final String title;
  final String xAxisLabel;
  final String yAxisLabel;

  const _ChartPreview({
    required this.rows,
    required this.graphType,
    required this.title,
    required this.xAxisLabel,
    required this.yAxisLabel,
  });

  @override
  Widget build(BuildContext context) {
    final legendRows = rows
        .where(
          (row) => row.x.trim().isNotEmpty && double.tryParse(row.y) != null,
        )
        .toList();
    return Container(
      width: double.infinity,

      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD8D0D0)),
        borderRadius: BorderRadius.circular(9),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).width >= 1000 ? 380 : 315,
            width: double.infinity,
            child: Tooltip(
              message: rows
                  .where((row) => row.x.isNotEmpty && row.y.isNotEmpty)
                  .map((row) => '${row.x}: ${row.y}')
                  .join('\n'),
              child: CustomPaint(
                painter: _GraphPainter(
                  rows: rows,
                  type: graphType,
                  title: title.isEmpty ? 'Blank' : title,
                  xLabel: xAxisLabel.isEmpty ? 'Blank' : xAxisLabel,
                  yLabel: yAxisLabel.isEmpty ? 'Blank' : yAxisLabel,
                ),
              ),
            ),
          ),
          if (graphType == GraphType.pie)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  for (var index = 0; index < legendRows.length; index++)
                    if (legendRows[index].x.isNotEmpty &&
                        double.tryParse(legendRows[index].y) != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            color: const [
                              Color(0xFF5DB075),
                              Color(0xFF49ACC7),
                              Color(0xFFC9A64A),
                              Color(0xFF9B6AD6),
                              Color(0xFF7FBF7A),
                            ][index % 5],
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(
                              '${legendRows[index].x}: ${legendRows[index].y}%',
                              style: AppTypography.helper,
                            ),
                          ),
                        ],
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final List<GraphDataRow> rows;
  final GraphType type;
  final String title;
  final String xLabel;
  final String yLabel;

  const _GraphPainter({
    required this.rows,
    required this.type,
    required this.title,
    required this.xLabel,
    required this.yLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _GraphBlockEditorScreenState._green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    _drawText(canvas, title, const Offset(28, 22), 18, FontWeight.w700);
    if (type == GraphType.pie) {
      _drawPie(canvas, size, paint);
      return;
    }
    final points = [
      for (final row in rows)
        if (double.tryParse(row.x) != null && double.tryParse(row.y) != null)
          Offset(double.parse(row.x), double.parse(row.y)),
    ];
    final left = 82.0;
    final top = 70.0;
    final width = size.width - 126;
    final height = size.height - 128;
    final axis = Paint()
      ..color = Colors.black
      ..strokeWidth = 1;
    final grid = Paint()
      ..color = const Color(0xFFE2E2E2)
      ..strokeWidth = 1;
    for (var i = 0; i <= 5; i++) {
      final y = top + height * i / 5;
      canvas.drawLine(Offset(left, y), Offset(left + width, y), grid);
    }
    canvas.drawLine(Offset(left, top), Offset(left, top + height), axis);
    canvas.drawLine(
      Offset(left, top + height),
      Offset(left + width, top + height),
      axis,
    );
    _drawText(
      canvas,
      xLabel,
      Offset(size.width / 2 - 24, size.height - 34),
      14,
      FontWeight.w700,
    );
    canvas.save();
    canvas.translate(28, size.height - 84);
    canvas.rotate(-math.pi / 2);
    _drawText(canvas, yLabel, Offset.zero, 14, FontWeight.w700);
    canvas.restore();
    if (points.isEmpty) return;
    final minX = points.map((p) => p.dx).reduce(math.min);
    final maxX = points.map((p) => p.dx).reduce(math.max);
    final maxY = points.map((p) => p.dy).reduce(math.max);
    Offset mapPoint(Offset point) {
      final xRange = maxX == minX ? 1 : maxX - minX;
      final yRange = maxY <= 0 ? 1 : maxY;
      return Offset(
        left + ((point.dx - minX) / xRange) * width,
        top + height - (point.dy / yRange) * height,
      );
    }

    if (type == GraphType.bar) {
      final barWidth = math.min(26.0, width / (points.length * 2));
      for (final point in points) {
        final mapped = mapPoint(point);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              mapped.dx - barWidth / 2,
              mapped.dy,
              barWidth,
              top + height - mapped.dy,
            ),
            const Radius.circular(2),
          ),
          Paint()..color = _GraphBlockEditorScreenState._green,
        );
      }
      return;
    }
    final mapped = points.map(mapPoint).toList();
    if (type == GraphType.line && mapped.length > 1) {
      final path = Path()..moveTo(mapped.first.dx, mapped.first.dy);
      for (final point in mapped.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
    for (final point in mapped) {
      canvas.drawCircle(
        point,
        4.5,
        Paint()..color = _GraphBlockEditorScreenState._green,
      );
    }
  }

  void _drawPie(Canvas canvas, Size size, Paint paint) {
    final valid = [
      for (final row in rows)
        if (row.x.trim().isNotEmpty && double.tryParse(row.y) != null)
          MapEntry(row.x.trim(), double.parse(row.y)),
    ];
    final total = valid.fold<double>(0, (sum, row) => sum + row.value);
    final colors = [
      const Color(0xFF5DB075),
      const Color(0xFF49ACC7),
      const Color(0xFFC9A64A),
      const Color(0xFF9B6AD6),
      const Color(0xFF7FBF7A),
    ];
    if (valid.isEmpty || total <= 0) return;
    final diameter = math.min(size.width - 48, size.height - 96);
    final rect = Rect.fromLTWH(
      (size.width - diameter) / 2,
      64,
      diameter,
      diameter,
    );
    var start = -math.pi / 2;
    for (var index = 0; index < valid.length; index++) {
      final sweep = valid[index].value / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = colors[index % colors.length],
      );
      start += sweep;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    double size,
    FontWeight weight,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black,
          fontSize: size,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: 240);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) => true;
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool optional;

  const _SectionLabel(this.label, {this.optional = false});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: label,
        children: [
          if (optional)
            const TextSpan(
              text: ' (Optional)',
              style: TextStyle(color: Color(0xFFCECECE)),
            ),
        ],
      ),
      style: const TextStyle(
        fontFamily: AppTypography.bodyFamily,
        color: _GraphBlockEditorScreenState._text,
        fontSize: AppTypography.bodySize,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String label;
  final bool optional;

  const _Label(this.label, {this.optional = false});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: label,
        children: [
          if (optional)
            const TextSpan(
              text: ' (Optional)',
              style: TextStyle(color: Color(0xFFCECECE)),
            ),
        ],
      ),
      style: const TextStyle(
        fontFamily: AppTypography.bodyFamily,
        color: _GraphBlockEditorScreenState._text,
        fontSize: AppTypography.bodySize,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String label;

  const _TableHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: AppTypography.bodyFamily,
        fontSize: AppTypography.bodySize,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _CellField extends StatelessWidget {
  final TextEditingController controller;
  final bool numeric;
  final bool error;

  const _CellField({
    required this.controller,
    required this.numeric,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return EvidenceCellField(controller: controller, numeric: numeric);
  }
}

class _SmallInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  final bool showError;
  const _SmallInput({
    required this.label,
    required this.controller,
    this.showError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: _GraphBlockEditorScreenState._muted,
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        _Input(controller: controller, maxLength: 50, height: 34, maxLines: 1),
        if (showError && controller.text.trim().isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Required', style: AppTypography.requirement),
          ),
      ],
    );
  }
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final int maxLength;
  final double height;
  final int maxLines;
  final String? hintText;

  const _Input({
    required this.controller,
    required this.maxLength,
    required this.height,
    required this.maxLines,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      buildCounter:
          (_, {required currentLength, required isFocused, maxLength}) => null,
      controller: controller,
      minLines: maxLines > 1 ? 5 : 1,
      maxLines: maxLines > 1 ? null : 1,
      textAlignVertical: TextAlignVertical.top,
      maxLength: maxLength,
      decoration: InputDecoration(
        hintText: hintText,
        counterStyle: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          fontSize: AppTypography.helperSize,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        constraints: BoxConstraints(minHeight: height),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(
            color: _GraphBlockEditorScreenState._green,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(
            color: _GraphBlockEditorScreenState._green,
          ),
        ),
      ),
    );
  }
}

class _SelectBox extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;

  const _SelectBox({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 47,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: _GraphBlockEditorScreenState._green),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              color: _GraphBlockEditorScreenState._green,
            ),
          ],
        ),
      ),
    );
  }
}

class _GraphGlyph extends StatelessWidget {
  final GraphType type;

  const _GraphGlyph({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 33,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(
        switch (type) {
          GraphType.bar => Icons.bar_chart,
          GraphType.scatter => Icons.scatter_plot,
          GraphType.line => Icons.show_chart,
          GraphType.pie => Icons.pie_chart_outline,
        },
        size: 22,
        color: Colors.black,
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OutlineButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 242,
      height: 33,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: _GraphBlockEditorScreenState._green,
          side: const BorderSide(color: _GraphBlockEditorScreenState._green),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
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
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem(value: option, child: Text(option)),
      ],
      child: Container(
        height: 47,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: _GraphBlockEditorScreenState._green),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayValue,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              color: _GraphBlockEditorScreenState._green,
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays saved graph data without editor controls.
class GraphEvidencePreview extends StatelessWidget {
  const GraphEvidencePreview({super.key, required this.data});
  final GraphBlockData data;
  @override
  Widget build(BuildContext context) => _ChartPreview(
    rows: data.rows,
    graphType: data.graphType,
    title: data.title,
    xAxisLabel: data.xAxisLabel,
    yAxisLabel: data.yAxisLabel,
  );
}
