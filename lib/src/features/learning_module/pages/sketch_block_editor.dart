import '../../../shared/widgets/evidence_description_field.dart';
import 'package:juniper_journal/src/shared/widgets/journal_section_header.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import '../../../shared/widgets/evidence_media_source.dart';
import 'package:juniper_journal/src/shared/widgets/evidence_block_header.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:juniper_journal/src/backend/db/supabase_database.dart';
import 'package:juniper_journal/src/backend/storage/storage_service.dart';
import 'package:juniper_journal/src/features/learning_module/pages/assessment_block.dart';
import 'package:juniper_journal/src/features/learning_module/pages/inquiry_lens_selector.dart';

enum SketchTool { pen, color, text, shape, erase, arrow, image }

enum _SketchItemKind { text, shape, arrow, image }

enum _SketchResizeHandle { bottomRight, arrowStart, arrowEnd }

class _SketchSelection {
  final _SketchItemKind kind;
  final int index;

  const _SketchSelection(this.kind, this.index);
}

class SketchBlockData {
  final String title;
  final String caption;
  final String inquiryLens;
  final InquiryLensData inquiryLensData;
  final AssessmentBlockData assessment;
  final List<SketchStroke> strokes;
  final List<SketchTextItem> textItems;
  final List<SketchShapeItem> shapes;
  final List<SketchArrowItem> arrows;
  final List<SketchImagePlaceholder> imagePlaceholders;

  const SketchBlockData({
    this.title = '',
    this.caption = '',
    this.inquiryLens = 'None',
    this.inquiryLensData = const InquiryLensData(),
    this.assessment = const AssessmentBlockData(),
    this.strokes = const [],
    this.textItems = const [],
    this.shapes = const [],
    this.arrows = const [],
    this.imagePlaceholders = const [],
  });

  String get cardSubtitle {
    if (title.trim().isNotEmpty) return title.trim();
    if (caption.trim().isNotEmpty) return caption.trim();
    return 'Create sketches.';
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'caption': caption,
    'inquiry_lens': inquiryLens,
    'inquiry_lens_data': inquiryLensData.toJson(),
    'inquiry': inquiryLensData.toPreviewJson(),
    'assessment': assessment.toJson(),
    'strokes': [for (final stroke in strokes) stroke.toJson()],
    'text_items': [for (final item in textItems) item.toJson()],
    'shapes': [for (final shape in shapes) shape.toJson()],
    'arrows': [for (final arrow in arrows) arrow.toJson()],
    'image_placeholders': [
      for (final image in imagePlaceholders) image.toJson(),
    ],
  };

  factory SketchBlockData.fromJson(Map<String, dynamic> json) {
    return SketchBlockData(
      title: json['title']?.toString() ?? '',
      caption: json['caption']?.toString() ?? '',
      inquiryLens: json['inquiry_lens']?.toString() ?? 'None',
      inquiryLensData: InquiryLensData.fromJson(
        json['inquiry_lens_data'],
        legacyLens: json['inquiry_lens']?.toString() ?? 'None',
      ),
      assessment: _decodeAssessment(json),
      strokes: _decodeList(json['strokes'], SketchStroke.fromJson),
      textItems: _decodeList(json['text_items'], SketchTextItem.fromJson),
      shapes: _decodeList(json['shapes'], SketchShapeItem.fromJson),
      arrows: _decodeList(json['arrows'], SketchArrowItem.fromJson),
      imagePlaceholders: _decodeList(
        json['image_placeholders'],
        SketchImagePlaceholder.fromJson,
      ),
    );
  }

  static AssessmentBlockData _decodeAssessment(Map<String, dynamic> json) {
    final assessment = AssessmentBlockData.fromJson(json['assessment']);
    if (!assessment.isEmpty) return assessment;
    final legacyType = AssessmentType.fromStorage(
      json['assessment_type']?.toString(),
    );
    return AssessmentBlockData(type: legacyType);
  }

  static List<T> _decodeList<T>(
    Object? raw,
    T Function(Map<String, dynamic>) decode,
  ) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) decode(Map<String, dynamic>.from(item)),
    ];
  }
}

class SketchStroke {
  final Color color;
  final List<Offset> points;

  const SketchStroke({required this.color, required this.points});

  SketchStroke copyWith({Color? color, List<Offset>? points}) {
    return SketchStroke(
      color: color ?? this.color,
      points: points ?? this.points,
    );
  }

  Map<String, dynamic> toJson() => {
    'color': color.toARGB32(),
    'points': [
      for (final point in points) {'x': point.dx, 'y': point.dy},
    ],
  };

  factory SketchStroke.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    return SketchStroke(
      color: Color((json['color'] as num?)?.toInt() ?? 0xFF000000),
      points: rawPoints is List
          ? [
              for (final point in rawPoints)
                if (point is Map)
                  Offset(
                    ((point['x'] as num?) ?? 0).toDouble(),
                    ((point['y'] as num?) ?? 0).toDouble(),
                  ),
            ]
          : const [],
    );
  }
}

class SketchTextItem {
  final String text;
  final Offset position;
  final Color color;
  final double fontSize;

  const SketchTextItem({
    required this.text,
    required this.position,
    required this.color,
    this.fontSize = 16,
  });

  SketchTextItem copyWith({
    String? text,
    Offset? position,
    Color? color,
    double? fontSize,
  }) {
    return SketchTextItem(
      text: text ?? this.text,
      position: position ?? this.position,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
    );
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'x': position.dx,
    'y': position.dy,
    'color': color.toARGB32(),
    'font_size': fontSize,
  };

  factory SketchTextItem.fromJson(Map<String, dynamic> json) {
    return SketchTextItem(
      text: json['text']?.toString() ?? '',
      position: Offset(
        ((json['x'] as num?) ?? 0).toDouble(),
        ((json['y'] as num?) ?? 0).toDouble(),
      ),
      color: Color((json['color'] as num?)?.toInt() ?? 0xFF000000),
      fontSize: ((json['font_size'] as num?) ?? 16).toDouble(),
    );
  }
}

class SketchShapeItem {
  final String type;
  final Rect rect;
  final Color color;

  const SketchShapeItem({
    required this.type,
    required this.rect,
    required this.color,
  });

  SketchShapeItem copyWith({String? type, Rect? rect, Color? color}) {
    return SketchShapeItem(
      type: type ?? this.type,
      rect: rect ?? this.rect,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'x': rect.left,
    'y': rect.top,
    'width': rect.width,
    'height': rect.height,
    'color': color.toARGB32(),
  };

  factory SketchShapeItem.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString();
    return SketchShapeItem(
      type:
          const [
            'box',
            'rectangle',
            'square',
            'circle',
            'line',
            'triangle',
          ].contains(type)
          ? type!
          : 'circle',
      rect: Rect.fromLTWH(
        ((json['x'] as num?) ?? 0).toDouble(),
        ((json['y'] as num?) ?? 0).toDouble(),
        ((json['width'] as num?) ?? 54).toDouble(),
        ((json['height'] as num?) ?? 42).toDouble(),
      ),
      color: Color((json['color'] as num?)?.toInt() ?? 0xFF000000),
    );
  }
}

class SketchArrowItem {
  final Offset start;
  final Offset end;
  final Color color;

  const SketchArrowItem({
    required this.start,
    required this.end,
    required this.color,
  });

  SketchArrowItem copyWith({Offset? start, Offset? end, Color? color}) {
    return SketchArrowItem(
      start: start ?? this.start,
      end: end ?? this.end,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() => {
    'start_x': start.dx,
    'start_y': start.dy,
    'end_x': end.dx,
    'end_y': end.dy,
    'color': color.toARGB32(),
  };

  factory SketchArrowItem.fromJson(Map<String, dynamic> json) {
    return SketchArrowItem(
      start: Offset(
        ((json['start_x'] as num?) ?? 0).toDouble(),
        ((json['start_y'] as num?) ?? 0).toDouble(),
      ),
      end: Offset(
        ((json['end_x'] as num?) ?? 42).toDouble(),
        ((json['end_y'] as num?) ?? 0).toDouble(),
      ),
      color: Color((json['color'] as num?)?.toInt() ?? 0xFF000000),
    );
  }
}

class SketchImagePlaceholder {
  final Rect rect;
  final String storagePath;
  final String publicUrl;
  final String fileName;

  const SketchImagePlaceholder({
    required this.rect,
    this.storagePath = '',
    this.publicUrl = '',
    this.fileName = '',
  });

  SketchImagePlaceholder copyWith({
    Rect? rect,
    String? storagePath,
    String? publicUrl,
    String? fileName,
  }) {
    return SketchImagePlaceholder(
      rect: rect ?? this.rect,
      storagePath: storagePath ?? this.storagePath,
      publicUrl: publicUrl ?? this.publicUrl,
      fileName: fileName ?? this.fileName,
    );
  }

  Map<String, dynamic> toJson() => {
    'x': rect.left,
    'y': rect.top,
    'width': rect.width,
    'height': rect.height,
    'storage_path': storagePath,
    'public_url': publicUrl,
    'file_name': fileName,
  };

  factory SketchImagePlaceholder.fromJson(Map<String, dynamic> json) {
    return SketchImagePlaceholder(
      rect: Rect.fromLTWH(
        ((json['x'] as num?) ?? 0).toDouble(),
        ((json['y'] as num?) ?? 0).toDouble(),
        ((json['width'] as num?) ?? 82).toDouble(),
        ((json['height'] as num?) ?? 62).toDouble(),
      ),
      storagePath:
          (json['storage_path'] ?? json['storagePath'])?.toString() ?? '',
      publicUrl:
          (json['public_url'] ?? json['publicUrl'] ?? json['url'])
              ?.toString() ??
          '',
      fileName: json['file_name']?.toString() ?? '',
    );
  }
}

class SketchBlockEditorScreen extends StatefulWidget {
  final String moduleId;
  final SketchBlockData? initialData;

  const SketchBlockEditorScreen({
    super.key,
    required this.moduleId,
    this.initialData,
  });

  @override
  State<SketchBlockEditorScreen> createState() =>
      _SketchBlockEditorScreenState();
}

class _SketchBlockEditorScreenState extends State<SketchBlockEditorScreen> {
  static const _green = Color(0xFF5DB075);
  static const _text = Color(0xFF141414);
  static const _muted = Color(0xFFCECECE);
  static const _screenWidth = 393.0;
  static const _canvasHeight = 254.0;
  static const _toolbarHeight = 48.0;
  late final TextEditingController _titleController;
  late final TextEditingController _captionController;
  SketchTool _activeTool = SketchTool.pen;
  Color _selectedColor = Colors.black;
  String _shapeType = 'box';
  InquiryLensData _inquiryLensData = const InquiryLensData();
  AssessmentBlockData _assessment = const AssessmentBlockData();
  List<SketchStroke> _strokes = [];
  List<SketchTextItem> _textItems = [];
  List<SketchShapeItem> _shapes = [];
  List<SketchArrowItem> _arrows = [];
  List<SketchImagePlaceholder> _imagePlaceholders = [];
  final List<_CanvasSnapshot> _undoStack = [];
  final List<_CanvasSnapshot> _redoStack = [];
  final _picker = ImagePicker();
  final _storage = StorageService();
  Offset? _pendingArrowStart;
  Offset? _draftArrowEnd;
  _SketchSelection? _selection;
  bool _uploadingImage = false;
  String? _uploadError;
  bool _showContentError = false;
  bool get _hasCanvasContent =>
      _strokes.any((stroke) => stroke.points.isNotEmpty) ||
      _textItems.any((item) => item.text.trim().isNotEmpty) ||
      _shapes.isNotEmpty ||
      _arrows.isNotEmpty ||
      _imagePlaceholders.any(
        (image) =>
            image.storagePath.trim().isNotEmpty ||
            image.publicUrl.trim().isNotEmpty,
      );

  bool get _isEditing => widget.initialData != null;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _titleController = TextEditingController(text: data?.title ?? '');
    _captionController = TextEditingController(text: data?.caption ?? '');
    _inquiryLensData = data == null
        ? const InquiryLensData()
        : data.inquiryLensData.selectLens(data.inquiryLens);
    _assessment = data?.assessment ?? const AssessmentBlockData();
    _strokes = List<SketchStroke>.from(data?.strokes ?? const []);
    _textItems = List<SketchTextItem>.from(data?.textItems ?? const []);
    _shapes = List<SketchShapeItem>.from(data?.shapes ?? const []);
    _arrows = List<SketchArrowItem>.from(data?.arrows ?? const []);
    _imagePlaceholders = List<SketchImagePlaceholder>.from(
      data?.imagePlaceholders ?? const [],
    );
    _titleController.addListener(_refresh);
    _captionController.addListener(_refresh);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _save() {
    if (!_hasCanvasContent) {
      setState(() => _showContentError = true);
      return;
    }
    Navigator.of(context).pop(
      SketchBlockData(
        title: _titleController.text.trim(),
        caption: _captionController.text.trim(),
        inquiryLens: _inquiryLensData.selectedLens,
        inquiryLensData: _inquiryLensData,
        assessment: _assessment,
        strokes: _strokes,
        textItems: _textItems,
        shapes: _shapes,
        arrows: _arrows,
        imagePlaceholders: _imagePlaceholders,
      ),
    );
  }

  void _selectTool(SketchTool tool) {
    if (tool == SketchTool.color) {
      _showColorChooser();
      return;
    }
    if (tool == SketchTool.shape) {
      _showShapeChooser();
    }
    setState(() {
      _activeTool = tool;
      _pendingArrowStart = null;
      _draftArrowEnd = null;
      _selection = null;
    });
  }

  void _showColorChooser() {
    showAppModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colors = [
          Colors.black,
          const Color(0xFFD12E2E),
          _green,
          const Color(0xFF2F6FED),
        ];
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Container(
              height: 92,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final color in colors)
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        setState(() {
                          _selectedColor = color;
                          _activeTool = SketchTool.pen;
                        });
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color == _selectedColor
                                ? _green
                                : const Color(0xFFE1E1E1),
                            width: color == _selectedColor ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showShapeChooser() {
    showAppModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final shape in const [
                    ('Square', 'square'),
                    ('Rectangle', 'rectangle'),
                    ('Circle', 'circle'),
                    ('Straight Line', 'line'),
                    ('Triangle', 'triangle'),
                  ]) ...[
                    _SheetOption(
                      label: shape.$1,
                      onTap: () {
                        Navigator.of(context).pop();
                        setState(() => _shapeType = shape.$2);
                      },
                    ),
                    if (shape.$2 != 'triangle') const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _pushHistory() {
    _undoStack.add(_snapshot());
    _redoStack.clear();
  }

  _CanvasSnapshot _snapshot() {
    return _CanvasSnapshot(
      strokes: List<SketchStroke>.from(_strokes),
      textItems: List<SketchTextItem>.from(_textItems),
      shapes: List<SketchShapeItem>.from(_shapes),
      arrows: List<SketchArrowItem>.from(_arrows),
      imagePlaceholders: List<SketchImagePlaceholder>.from(_imagePlaceholders),
    );
  }

  void _restoreSnapshot(_CanvasSnapshot snapshot) {
    _strokes = List<SketchStroke>.from(snapshot.strokes);
    _textItems = List<SketchTextItem>.from(snapshot.textItems);
    _shapes = List<SketchShapeItem>.from(snapshot.shapes);
    _arrows = List<SketchArrowItem>.from(snapshot.arrows);
    _imagePlaceholders = List<SketchImagePlaceholder>.from(
      snapshot.imagePlaceholders,
    );
    _pendingArrowStart = null;
    _draftArrowEnd = null;
    _selection = null;
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(_snapshot());
      _restoreSnapshot(_undoStack.removeLast());
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(_snapshot());
      _restoreSnapshot(_redoStack.removeLast());
    });
  }

  Offset _clampPoint(Offset point, Size size) {
    return Offset(
      point.dx.clamp(0, size.width).toDouble(),
      point.dy.clamp(0, size.height).toDouble(),
    );
  }

  void _startPan(DragStartDetails details, Size canvasSize) {
    final point = _clampPoint(details.localPosition, canvasSize);
    if (_activeTool == SketchTool.pen) {
      _pushHistory();
      setState(() {
        _strokes.add(SketchStroke(color: _selectedColor, points: [point]));
      });
    } else if (_activeTool == SketchTool.erase) {
      _eraseAt(point);
    } else if (_activeTool == SketchTool.arrow) {
      setState(() {
        _pendingArrowStart = point;
        _draftArrowEnd = point;
      });
    }
  }

  void _updatePan(DragUpdateDetails details, Size canvasSize) {
    final point = _clampPoint(details.localPosition, canvasSize);
    if (_activeTool == SketchTool.pen && _strokes.isNotEmpty) {
      setState(() {
        final stroke = _strokes.last;
        _strokes[_strokes.length - 1] = stroke.copyWith(
          points: [...stroke.points, point],
        );
      });
    } else if (_activeTool == SketchTool.erase) {
      _eraseAt(point);
    } else if (_activeTool == SketchTool.arrow && _pendingArrowStart != null) {
      setState(() => _draftArrowEnd = point);
    }
  }

  void _endPan(DragEndDetails details, Size canvasSize) {
    if (_activeTool != SketchTool.arrow ||
        _pendingArrowStart == null ||
        _draftArrowEnd == null) {
      return;
    }
    final start = _pendingArrowStart!;
    final end = _draftArrowEnd!;
    if ((end - start).distance < 8) {
      setState(() {
        _pendingArrowStart = null;
        _draftArrowEnd = null;
      });
      return;
    }
    _pushHistory();
    setState(() {
      _arrows.add(SketchArrowItem(start: start, end: end, color: Colors.black));
      _selection = _SketchSelection(_SketchItemKind.arrow, _arrows.length - 1);
      _pendingArrowStart = null;
      _draftArrowEnd = null;
    });
  }

  Future<void> _handleTap(TapUpDetails details, Size canvasSize) async {
    final point = _clampPoint(details.localPosition, canvasSize);
    final hit = _hitTest(point);
    if (hit != null && _activeTool != SketchTool.erase) {
      setState(() {
        _selection = hit;
        _pendingArrowStart = null;
      });
      return;
    }

    switch (_activeTool) {
      case SketchTool.text:
        await _placeText(point);
        break;
      case SketchTool.shape:
        _placeShape(point, canvasSize);
        break;
      case SketchTool.arrow:
        setState(() => _selection = null);
        break;
      case SketchTool.image:
        await _placeImage(point, canvasSize);
        break;
      case SketchTool.erase:
        _eraseAt(point);
        break;
      case SketchTool.pen:
      case SketchTool.color:
        setState(() => _selection = null);
        break;
    }
  }

  _SketchSelection? _hitTest(Offset point) {
    for (var index = _textItems.length - 1; index >= 0; index--) {
      if (_textBounds(_textItems[index]).inflate(8).contains(point)) {
        return _SketchSelection(_SketchItemKind.text, index);
      }
    }
    for (var index = _imagePlaceholders.length - 1; index >= 0; index--) {
      if (_imagePlaceholders[index].rect.inflate(8).contains(point)) {
        return _SketchSelection(_SketchItemKind.image, index);
      }
    }
    for (var index = _shapes.length - 1; index >= 0; index--) {
      final shape = _shapes[index];
      if (shape.type == 'box' ||
          shape.type == 'rectangle' ||
          shape.type == 'square') {
        if (shape.rect.inflate(8).contains(point)) {
          return _SketchSelection(_SketchItemKind.shape, index);
        }
      } else if (_pointNearOval(point, shape.rect.inflate(8))) {
        return _SketchSelection(_SketchItemKind.shape, index);
      } else if (shape.type == 'line' &&
          _distanceToSegment(
                point,
                shape.rect.centerLeft,
                shape.rect.centerRight,
              ) <=
              12) {
        return _SketchSelection(_SketchItemKind.shape, index);
      } else if (shape.type == 'triangle' &&
          shape.rect.inflate(8).contains(point)) {
        return _SketchSelection(_SketchItemKind.shape, index);
      }
    }
    for (var index = _arrows.length - 1; index >= 0; index--) {
      final arrow = _arrows[index];
      if (_distanceToSegment(point, arrow.start, arrow.end) <= 12) {
        return _SketchSelection(_SketchItemKind.arrow, index);
      }
    }
    return null;
  }

  Rect _textBounds(SketchTextItem item) {
    final painter = TextPainter(
      text: TextSpan(
        text: item.text,
        style: TextStyle(fontSize: item.fontSize, fontWeight: FontWeight.w600),
      ),
      maxLines: 3,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 220);
    return item.position & painter.size;
  }

  bool _pointNearOval(Offset point, Rect rect) {
    final center = rect.center;
    final radiusX = rect.width / 2;
    final radiusY = rect.height / 2;
    if (radiusX == 0 || radiusY == 0) return false;
    final value =
        math.pow((point.dx - center.dx) / radiusX, 2) +
        math.pow((point.dy - center.dy) / radiusY, 2);
    return value <= 1.18;
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    if (dx == 0 && dy == 0) return (point - start).distance;
    final t =
        (((point.dx - start.dx) * dx) + ((point.dy - start.dy) * dy)) /
        ((dx * dx) + (dy * dy));
    final clamped = t.clamp(0.0, 1.0);
    final projection = Offset(start.dx + clamped * dx, start.dy + clamped * dy);
    return (point - projection).distance;
  }

  Future<void> _placeText(Offset point) async {
    final controller = TextEditingController();
    final text = await showAppDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Add Text'),
          content: TextField(
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
            controller: controller,
            autofocus: true,
            maxLength: 80,
            decoration: const InputDecoration(hintText: ''),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty || !mounted) return;
    _pushHistory();
    setState(() {
      final item = SketchTextItem(
        text: text.trim(),
        position: point,
        color: _selectedColor,
      );
      _textItems.add(item);
      _selection = _SketchSelection(
        _SketchItemKind.text,
        _textItems.length - 1,
      );
    });
  }

  void _deleteSelection() {
    final selection = _selection;
    if (selection == null || !_selectionIsValid(selection)) return;
    _pushHistory();
    setState(() {
      switch (selection.kind) {
        case _SketchItemKind.text:
          _textItems.removeAt(selection.index);
          break;
        case _SketchItemKind.shape:
          _shapes.removeAt(selection.index);
          break;
        case _SketchItemKind.arrow:
          _arrows.removeAt(selection.index);
          break;
        case _SketchItemKind.image:
          _imagePlaceholders.removeAt(selection.index);
          break;
      }
      _selection = null;
    });
  }

  void _beginSelectionResize() {
    final selection = _selection;
    if (selection == null || !_selectionIsValid(selection)) return;
    _pushHistory();
  }

  void _resizeSelection(
    _SketchResizeHandle handle,
    DragUpdateDetails details,
    Size canvasSize,
  ) {
    final selection = _selection;
    if (selection == null || !_selectionIsValid(selection)) return;
    setState(() {
      switch (selection.kind) {
        case _SketchItemKind.text:
          final item = _textItems[selection.index];
          final delta = (details.delta.dx + details.delta.dy) / 3;
          final nextSize = (item.fontSize + delta).clamp(10.0, 48.0);
          _textItems[selection.index] = item.copyWith(fontSize: nextSize);
          break;
        case _SketchItemKind.shape:
          final shape = _shapes[selection.index];
          final rect = _resizeRect(shape.rect, details.delta, canvasSize);
          final nextRect = switch (shape.type) {
            'square' => _squareFromTopLeft(rect, canvasSize),
            'circle' => _squareFromTopLeft(rect, canvasSize),
            'line' => Rect.fromLTWH(rect.left, rect.top, rect.width, 1),
            _ => rect,
          };
          _shapes[selection.index] = shape.copyWith(rect: nextRect);
          break;
        case _SketchItemKind.arrow:
          final arrow = _arrows[selection.index];
          if (handle == _SketchResizeHandle.arrowStart) {
            final point = _clampPoint(arrow.start + details.delta, canvasSize);
            _arrows[selection.index] = arrow.copyWith(start: point);
          } else if (handle == _SketchResizeHandle.arrowEnd) {
            final point = _clampPoint(arrow.end + details.delta, canvasSize);
            _arrows[selection.index] = arrow.copyWith(end: point);
          }
          break;
        case _SketchItemKind.image:
          final image = _imagePlaceholders[selection.index];
          _imagePlaceholders[selection.index] = image.copyWith(
            rect: _resizeRect(image.rect, details.delta, canvasSize),
          );
          break;
      }
    });
  }

  Rect _resizeRect(Rect rect, Offset delta, Size canvasSize) {
    const minSize = 24.0;
    final width = (rect.width + delta.dx)
        .clamp(minSize, canvasSize.width - rect.left)
        .toDouble();
    final height = (rect.height + delta.dy)
        .clamp(minSize, canvasSize.height - rect.top)
        .toDouble();
    return Rect.fromLTWH(rect.left, rect.top, width, height);
  }

  Rect _squareFromTopLeft(Rect rect, Size canvasSize) {
    final side = math
        .min(rect.width, rect.height)
        .clamp(
          24.0,
          math.min(canvasSize.width - rect.left, canvasSize.height - rect.top),
        )
        .toDouble();
    return Rect.fromLTWH(rect.left, rect.top, side, side);
  }

  bool _selectionIsValid(_SketchSelection selection) {
    return switch (selection.kind) {
      _SketchItemKind.text =>
        selection.index >= 0 && selection.index < _textItems.length,
      _SketchItemKind.shape =>
        selection.index >= 0 && selection.index < _shapes.length,
      _SketchItemKind.arrow =>
        selection.index >= 0 && selection.index < _arrows.length,
      _SketchItemKind.image =>
        selection.index >= 0 && selection.index < _imagePlaceholders.length,
    };
  }

  void _placeShape(Offset point, Size canvasSize) {
    _pushHistory();
    setState(() {
      final size = switch (_shapeType) {
        'square' => const Size(54, 54),
        'circle' => const Size(52, 52),
        'line' => const Size(78, 1),
        'triangle' => const Size(62, 54),
        _ => const Size(72, 48),
      };
      _shapes.add(
        SketchShapeItem(
          type: _shapeType,
          rect: _clampedRect(point, size, canvasSize),
          color: _selectedColor,
        ),
      );
      _selection = _SketchSelection(_SketchItemKind.shape, _shapes.length - 1);
    });
  }

  Rect _clampedRect(Offset center, Size itemSize, Size canvasSize) {
    final left = (center.dx - itemSize.width / 2)
        .clamp(0, canvasSize.width - itemSize.width)
        .toDouble();
    final top = (center.dy - itemSize.height / 2)
        .clamp(0, canvasSize.height - itemSize.height)
        .toDouble();
    return Rect.fromLTWH(left, top, itemSize.width, itemSize.height);
  }

  Future<void> _placeImage(Offset point, Size canvasSize) async {
    final source = await showAppModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetOption(
                  label: 'Open Library',
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
                const Divider(height: 1),
                _SheetOption(
                  label: 'Take Photo',
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    final userId = SupabaseDatabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _uploadError = 'Sign in before uploading an image.');
      return;
    }

    setState(() {
      _uploadingImage = true;
      _uploadError = null;
    });
    try {
      final uploaded = await _storage.uploadImageFile(
        picked,
        bucketName: 'images',
        folder:
            'learning-modules/$userId/${widget.moduleId}/concept-exploration/sketch',
      );
      if (!mounted) return;
      _pushHistory();
      setState(() {
        _imagePlaceholders.add(
          SketchImagePlaceholder(
            rect: _clampedRect(point, const Size(86, 62), canvasSize),
            storagePath: uploaded.path,
            publicUrl: uploaded.publicUrl,
            fileName: uploaded.fileName,
          ),
        );
        _selection = _SketchSelection(
          _SketchItemKind.image,
          _imagePlaceholders.length - 1,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadError = 'Image upload failed. Your draft remains.');
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  void _eraseAt(Offset point) {
    final hitIndex = _strokes.indexWhere((stroke) {
      return stroke.points.any((strokePoint) {
        return (strokePoint - point).distance <= 14;
      });
    });
    if (hitIndex == -1) return;
    _pushHistory();
    setState(() => _strokes.removeAt(hitIndex));
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
                _Header(
                  onBack: () => Navigator.of(context).pop<SketchBlockData?>(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(0, 24, 0, 27),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(24, 0, 23, 0),
                          child: _FieldLabel(label: 'Content'),
                        ),
                        const SizedBox(height: AppMetrics.labelGap),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 23, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel(label: 'Title', optional: true),
                              const SizedBox(height: 11),
                              _TextFieldBox(
                                controller: _titleController,
                                maxLength: 100,
                                height: 64,
                                singleLine: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(25, 0, 25, 0),
                          child: Row(
                            children: [
                              const Expanded(
                                child: _FieldLabel(label: 'Canvas'),
                              ),
                              _UndoButton(
                                asset:
                                    'assets/learning_module/sketch_block_undo.svg',
                                onTap: _undo,
                                enabled: _undoStack.isNotEmpty,
                              ),
                              const SizedBox(width: 15),
                              _UndoButton(
                                asset:
                                    'assets/learning_module/sketch_block_redo.svg',
                                onTap: _redo,
                                enabled: _redoStack.isNotEmpty,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(25, 0, 23, 0),
                          child: _CanvasBox(
                            activeTool: _activeTool,
                            selectedColor: _selectedColor,
                            strokes: _strokes,
                            textItems: _textItems,
                            shapes: _shapes,
                            arrows: _arrows,
                            imagePlaceholders: _imagePlaceholders,
                            pendingArrowStart: _pendingArrowStart,
                            draftArrowEnd: _draftArrowEnd,
                            selection: _selection,
                            uploadingImage: _uploadingImage,
                            onDeleteSelected: _deleteSelection,
                            onResizeStart: _beginSelectionResize,
                            onResizeUpdate: _resizeSelection,
                            onPanStart: _startPan,
                            onPanUpdate: _updatePan,
                            onPanEnd: _endPan,
                            onTapUp: _handleTap,
                            onToolSelected: _selectTool,
                          ),
                        ),
                        if (_showContentError && !_hasCanvasContent) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(25, 8, 23, 0),
                            child: Text(
                              'Add a drawing, text, shape, or image to the canvas.',
                              style: AppTypography.requirement,
                            ),
                          ),
                        ],
                        if (_uploadError != null) ...[
                          const SizedBox(height: 7),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 25),
                            child: Text(
                              _uploadError!,
                              style: const TextStyle(
                                color: Color(0xFFD12E2E),
                                fontSize: AppTypography.helperSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 11),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 22, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel(label: 'Caption', optional: true),
                              const SizedBox(height: 11),
                              _TextFieldBox(
                                controller: _captionController,
                                maxLength: 300,
                                height: 56,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppMetrics.fieldGap),

                        Center(
                          child: SizedBox(
                            width: 130,
                            height: 32,
                            child: ElevatedButton(
                              onPressed: _save,
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: _green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              child: Text(
                                _isEditing ? 'Save' : 'Add Block',
                                style: const TextStyle(
                                  fontFamily: AppTypography.bodyFamily,
                                  fontSize: AppTypography.buttonSize,
                                  height: 1,
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

class _CanvasSnapshot {
  final List<SketchStroke> strokes;
  final List<SketchTextItem> textItems;
  final List<SketchShapeItem> shapes;
  final List<SketchArrowItem> arrows;
  final List<SketchImagePlaceholder> imagePlaceholders;

  const _CanvasSnapshot({
    required this.strokes,
    required this.textItems,
    required this.shapes,
    required this.arrows,
    required this.imagePlaceholders,
  });
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) =>
      EvidenceBlockHeader(title: 'Sketch Block', onBack: onBack);
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool optional;

  const _FieldLabel({required this.label, this.optional = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          color: _SketchBlockEditorScreenState._text,
          fontSize: AppTypography.bodySize,
          height: 1,
          fontWeight: FontWeight.w500,
        ),
        children: [
          if (optional)
            const TextSpan(
              text: ' (Optional)',
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: _SketchBlockEditorScreenState._muted,
                fontSize: AppTypography.helperSize,
                height: 1,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
    );
  }
}

class _TextFieldBox extends StatelessWidget {
  final TextEditingController controller;
  final int maxLength;
  final double height;
  final bool singleLine;
  final int? maxLines;

  const _TextFieldBox({
    required this.controller,
    required this.maxLength,
    required this.height,
    this.singleLine = false,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    if (!singleLine) return EvidenceDescriptionField(controller: controller);
    return SizedBox(
      height: height + (singleLine ? 13 : 0),
      child: Stack(
        children: [
          SizedBox(
            height: height,
            child: TextField(
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              controller: controller,
              maxLength: maxLength,
              minLines: singleLine ? 1 : null,
              maxLines: singleLine ? 1 : maxLines,
              textAlignVertical: singleLine
                  ? TextAlignVertical.center
                  : TextAlignVertical.top,
              decoration: InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.fromLTRB(
                  12,
                  singleLine ? 0 : 10,
                  12,
                  8,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(
                    color: _SketchBlockEditorScreenState._green,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(
                    color: _SketchBlockEditorScreenState._green,
                  ),
                ),
              ),
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: _SketchBlockEditorScreenState._text,
                fontSize: AppTypography.bodySize,
                height: 1.2,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Positioned(
            right: 2,
            bottom: singleLine ? 0 : 7,
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _CanvasBox extends StatelessWidget {
  final SketchTool activeTool;
  final Color selectedColor;
  final List<SketchStroke> strokes;
  final List<SketchTextItem> textItems;
  final List<SketchShapeItem> shapes;
  final List<SketchArrowItem> arrows;
  final List<SketchImagePlaceholder> imagePlaceholders;
  final Offset? pendingArrowStart;
  final Offset? draftArrowEnd;
  final _SketchSelection? selection;
  final bool uploadingImage;
  final VoidCallback onDeleteSelected;
  final VoidCallback onResizeStart;
  final void Function(
    _SketchResizeHandle handle,
    DragUpdateDetails details,
    Size canvasSize,
  )
  onResizeUpdate;
  final void Function(DragStartDetails details, Size canvasSize) onPanStart;
  final void Function(DragUpdateDetails details, Size canvasSize) onPanUpdate;
  final void Function(DragEndDetails details, Size canvasSize) onPanEnd;
  final Future<void> Function(TapUpDetails details, Size canvasSize) onTapUp;
  final ValueChanged<SketchTool> onToolSelected;

  const _CanvasBox({
    required this.activeTool,
    required this.selectedColor,
    required this.strokes,
    required this.textItems,
    required this.shapes,
    required this.arrows,
    required this.imagePlaceholders,
    required this.pendingArrowStart,
    required this.draftArrowEnd,
    required this.selection,
    required this.uploadingImage,
    required this.onDeleteSelected,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onTapUp,
    required this.onToolSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _SketchBlockEditorScreenState._canvasHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final drawingSize = Size(
            constraints.maxWidth,
            _SketchBlockEditorScreenState._canvasHeight -
                _SketchBlockEditorScreenState._toolbarHeight,
          );
          final canPan =
              activeTool == SketchTool.pen ||
              activeTool == SketchTool.erase ||
              activeTool == SketchTool.arrow;
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _SketchBlockEditorScreenState._green),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: constraints.maxWidth,
                    height: drawingSize.height,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: canPan
                                ? (details) => onPanStart(details, drawingSize)
                                : null,
                            onPanUpdate: canPan
                                ? (details) => onPanUpdate(details, drawingSize)
                                : null,
                            onPanEnd: canPan
                                ? (details) => onPanEnd(details, drawingSize)
                                : null,
                            onTapUp: (details) => onTapUp(details, drawingSize),
                            child: CustomPaint(
                              painter: _SketchPainter(
                                strokes: strokes,
                                textItems: textItems,
                                shapes: shapes,
                                arrows: arrows,
                                imagePlaceholders: imagePlaceholders,
                                pendingArrowStart: pendingArrowStart,
                                draftArrowEnd: draftArrowEnd,
                                selection: selection,
                              ),
                              size: drawingSize,
                            ),
                          ),
                        ),
                        for (final image in imagePlaceholders)
                          if (image.publicUrl.isNotEmpty)
                            Positioned.fromRect(
                              rect: image.rect,
                              child: IgnorePointer(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    image.publicUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                        if (_selectionBounds(selection) case final bounds?)
                          Positioned(
                            left: _deleteButtonPosition(bounds, drawingSize).dx,
                            top: _deleteButtonPosition(bounds, drawingSize).dy,
                            child: _DeleteSelectionButton(
                              onTap: onDeleteSelected,
                            ),
                          ),
                        ..._resizeHandles(drawingSize),
                        if (uploadingImage)
                          const Positioned.fill(
                            child: ColoredBox(
                              color: Color(0x22FFFFFF),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: _SketchBlockEditorScreenState._green,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE6E6E6)),
                  SizedBox(
                    height: _SketchBlockEditorScreenState._toolbarHeight - 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ToolButton(
                          asset: 'assets/learning_module/sketch_block_pen.svg',
                          tool: SketchTool.pen,
                          activeTool: activeTool,
                          selectedColor: selectedColor,
                          onSelected: onToolSelected,
                        ),
                        _ToolButton(
                          asset:
                              'assets/learning_module/sketch_block_color.svg',
                          tool: SketchTool.color,
                          activeTool: activeTool,
                          selectedColor: selectedColor,
                          onSelected: onToolSelected,
                        ),
                        _ToolButton(
                          asset: 'assets/learning_module/sketch_block_text.svg',
                          tool: SketchTool.text,
                          activeTool: activeTool,
                          selectedColor: selectedColor,
                          onSelected: onToolSelected,
                        ),
                        _ToolButton(
                          asset:
                              'assets/learning_module/sketch_block_shape.svg',
                          tool: SketchTool.shape,
                          activeTool: activeTool,
                          selectedColor: selectedColor,
                          onSelected: onToolSelected,
                        ),
                        _ToolButton(
                          asset:
                              'assets/learning_module/sketch_block_erase.svg',
                          tool: SketchTool.erase,
                          activeTool: activeTool,
                          selectedColor: selectedColor,
                          onSelected: onToolSelected,
                        ),
                        _ToolButton(
                          asset:
                              'assets/learning_module/sketch_block_arrow.svg',
                          tool: SketchTool.arrow,
                          activeTool: activeTool,
                          selectedColor: selectedColor,
                          onSelected: onToolSelected,
                        ),
                        _ToolButton(
                          asset:
                              'assets/learning_module/sketch_block_image.svg',
                          tool: SketchTool.image,
                          activeTool: activeTool,
                          selectedColor: selectedColor,
                          onSelected: onToolSelected,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Rect? _selectionBounds(_SketchSelection? selection) {
    if (selection == null || !_selectionIsValid(selection)) return null;
    return switch (selection.kind) {
      _SketchItemKind.text => _textBounds(textItems[selection.index]),
      _SketchItemKind.shape => shapes[selection.index].rect,
      _SketchItemKind.arrow => Rect.fromPoints(
        arrows[selection.index].start,
        arrows[selection.index].end,
      ).inflate(6),
      _SketchItemKind.image => imagePlaceholders[selection.index].rect,
    };
  }

  bool _selectionIsValid(_SketchSelection selection) {
    return switch (selection.kind) {
      _SketchItemKind.text =>
        selection.index >= 0 && selection.index < textItems.length,
      _SketchItemKind.shape =>
        selection.index >= 0 && selection.index < shapes.length,
      _SketchItemKind.arrow =>
        selection.index >= 0 && selection.index < arrows.length,
      _SketchItemKind.image =>
        selection.index >= 0 && selection.index < imagePlaceholders.length,
    };
  }

  Rect _textBounds(SketchTextItem item) {
    final painter = TextPainter(
      text: TextSpan(
        text: item.text,
        style: TextStyle(fontSize: item.fontSize, fontWeight: FontWeight.w600),
      ),
      maxLines: 3,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 220);
    return item.position & painter.size;
  }

  Offset _deleteButtonPosition(Rect bounds, Size canvasSize) {
    final x = (bounds.right - 60).clamp(4.0, canvasSize.width - 64).toDouble();
    final y = (bounds.top - 34).clamp(4.0, canvasSize.height - 32).toDouble();
    return Offset(x, y);
  }

  List<Widget> _resizeHandles(Size drawingSize) {
    final selected = selection;
    if (selected == null || !_selectionIsValid(selected)) return const [];
    if (selected.kind == _SketchItemKind.arrow) {
      final arrow = arrows[selected.index];
      return [
        _positionedResizeHandle(
          arrow.start,
          _SketchResizeHandle.arrowStart,
          drawingSize,
        ),
        _positionedResizeHandle(
          arrow.end,
          _SketchResizeHandle.arrowEnd,
          drawingSize,
        ),
      ];
    }
    final bounds = _selectionBounds(selected);
    if (bounds == null) return const [];
    return [
      _positionedResizeHandle(
        bounds.bottomRight,
        _SketchResizeHandle.bottomRight,
        drawingSize,
      ),
    ];
  }

  Widget _positionedResizeHandle(
    Offset center,
    _SketchResizeHandle handle,
    Size drawingSize,
  ) {
    final left = (center.dx - 8).clamp(0.0, drawingSize.width - 16).toDouble();
    final top = (center.dy - 8).clamp(0.0, drawingSize.height - 16).toDouble();
    return Positioned(
      left: left,
      top: top,
      child: _ResizeHandleButton(
        onPanStart: (_) => onResizeStart(),
        onPanUpdate: (details) => onResizeUpdate(handle, details, drawingSize),
      ),
    );
  }
}

class _ResizeHandleButton extends StatelessWidget {
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;

  const _ResizeHandleButton({
    required this.onPanStart,
    required this.onPanUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: _SketchBlockEditorScreenState._green,
            width: 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteSelectionButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteSelectionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 60,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD12E2E)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Text(
          'Delete',
          style: TextStyle(
            color: Color(0xFFD12E2E),
            fontSize: AppTypography.buttonSize,
            height: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final String asset;
  final SketchTool tool;
  final SketchTool activeTool;
  final Color selectedColor;
  final ValueChanged<SketchTool> onSelected;

  const _ToolButton({
    required this.asset,
    required this.tool,
    required this.activeTool,
    required this.selectedColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selected = activeTool == tool;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelected(tool),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: SvgPicture.asset(
          asset,
          width: 20,
          height: 20,
          colorFilter: ColorFilter.mode(
            selected ? _SketchBlockEditorScreenState._green : Colors.black,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

class _UndoButton extends StatelessWidget {
  final String asset;
  final VoidCallback onTap;
  final bool enabled;

  const _UndoButton({
    required this.asset,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: 1,
        child: SvgPicture.asset(
          asset,
          width: 17,
          height: 16,
          colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
        ),
      ),
    );
  }
}

class _SketchPainter extends CustomPainter {
  final List<SketchStroke> strokes;
  final List<SketchTextItem> textItems;
  final List<SketchShapeItem> shapes;
  final List<SketchArrowItem> arrows;
  final List<SketchImagePlaceholder> imagePlaceholders;
  final Offset? pendingArrowStart;
  final Offset? draftArrowEnd;
  final _SketchSelection? selection;

  const _SketchPainter({
    required this.strokes,
    required this.textItems,
    required this.shapes,
    required this.arrows,
    required this.imagePlaceholders,
    required this.pendingArrowStart,
    required this.draftArrowEnd,
    required this.selection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      for (var index = 1; index < stroke.points.length; index++) {
        canvas.drawLine(stroke.points[index - 1], stroke.points[index], paint);
      }
      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first, 1.5, paint);
      }
    }
    for (final shape in shapes) {
      final paint = Paint()
        ..color = shape.color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke;
      if (shape.type == 'box' ||
          shape.type == 'rectangle' ||
          shape.type == 'square') {
        canvas.drawRRect(
          RRect.fromRectAndRadius(shape.rect, const Radius.circular(4)),
          paint,
        );
      } else if (shape.type == 'circle') {
        canvas.drawOval(shape.rect, paint);
      } else if (shape.type == 'line') {
        canvas.drawLine(shape.rect.centerLeft, shape.rect.centerRight, paint);
      } else if (shape.type == 'triangle') {
        final path = Path()
          ..moveTo(shape.rect.center.dx, shape.rect.top)
          ..lineTo(shape.rect.right, shape.rect.bottom)
          ..lineTo(shape.rect.left, shape.rect.bottom)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
    for (final arrow in arrows) {
      _drawArrow(canvas, arrow.start, arrow.end, arrow.color);
    }
    if (pendingArrowStart != null && draftArrowEnd != null) {
      _drawArrow(
        canvas,
        pendingArrowStart!,
        draftArrowEnd!,
        const Color(0x805DB075),
      );
    } else if (pendingArrowStart != null) {
      final paint = Paint()
        ..color = const Color(0x805DB075)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pendingArrowStart!, 5, paint);
    }
    for (final image in imagePlaceholders) {
      _drawImagePlaceholder(canvas, image.rect);
    }
    for (final item in textItems) {
      final painter = TextPainter(
        text: TextSpan(
          text: item.text,
          style: TextStyle(
            color: item.color,
            fontSize: item.fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        maxLines: 3,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - item.position.dx - 8);
      painter.paint(canvas, item.position);
    }
    _drawSelection(canvas);
  }

  void _drawSelection(Canvas canvas) {
    final bounds = _selectionBounds();
    if (bounds == null) return;
    final outline = Paint()
      ..color = const Color(0xFF5DB075)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final handle = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleBorder = Paint()
      ..color = const Color(0xFF5DB075)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final inflated = bounds.inflate(5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inflated, const Radius.circular(7)),
      outline,
    );
    for (final point in [
      inflated.topLeft,
      inflated.topRight,
      inflated.bottomLeft,
      inflated.bottomRight,
    ]) {
      canvas.drawCircle(point, 3.5, handle);
      canvas.drawCircle(point, 3.5, handleBorder);
    }
  }

  Rect? _selectionBounds() {
    final selected = selection;
    if (selected == null || !_selectionIsValid(selected)) return null;
    return switch (selected.kind) {
      _SketchItemKind.text => _textBounds(textItems[selected.index]),
      _SketchItemKind.shape => shapes[selected.index].rect,
      _SketchItemKind.arrow => Rect.fromPoints(
        arrows[selected.index].start,
        arrows[selected.index].end,
      ).inflate(6),
      _SketchItemKind.image => imagePlaceholders[selected.index].rect,
    };
  }

  bool _selectionIsValid(_SketchSelection selected) {
    return switch (selected.kind) {
      _SketchItemKind.text =>
        selected.index >= 0 && selected.index < textItems.length,
      _SketchItemKind.shape =>
        selected.index >= 0 && selected.index < shapes.length,
      _SketchItemKind.arrow =>
        selected.index >= 0 && selected.index < arrows.length,
      _SketchItemKind.image =>
        selected.index >= 0 && selected.index < imagePlaceholders.length,
    };
  }

  Rect _textBounds(SketchTextItem item) {
    final painter = TextPainter(
      text: TextSpan(
        text: item.text,
        style: TextStyle(fontSize: item.fontSize, fontWeight: FontWeight.w600),
      ),
      maxLines: 3,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 220);
    return item.position & painter.size;
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, end, paint);
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const length = 11.0;
    final left = Offset(
      end.dx - length * math.cos(angle - math.pi / 6),
      end.dy - length * math.sin(angle - math.pi / 6),
    );
    final right = Offset(
      end.dx - length * math.cos(angle + math.pi / 6),
      end.dy - length * math.sin(angle + math.pi / 6),
    );
    canvas.drawLine(end, left, paint);
    canvas.drawLine(end, right, paint);
  }

  void _drawImagePlaceholder(Canvas canvas, Rect rect) {
    final fill = Paint()..color = const Color(0xFFF7F7F7);
    final border = Paint()
      ..color = const Color(0xFF5DB075)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, fill);
    canvas.drawRRect(rrect, border);
    final iconPaint = Paint()
      ..color = const Color(0xFF5DB075)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final iconRect = Rect.fromCenter(
      center: rect.center,
      width: 28,
      height: 22,
    );
    canvas.drawRect(iconRect, iconPaint);
    canvas.drawCircle(
      Offset(iconRect.right - 7, iconRect.top + 6),
      2.2,
      iconPaint,
    );
    final path = Path()
      ..moveTo(iconRect.left + 3, iconRect.bottom - 4)
      ..lineTo(iconRect.left + 11, iconRect.center.dy)
      ..lineTo(iconRect.left + 18, iconRect.bottom - 4);
    canvas.drawPath(path, iconPaint);
  }

  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.textItems != textItems ||
        oldDelegate.shapes != shapes ||
        oldDelegate.arrows != arrows ||
        oldDelegate.imagePlaceholders != imagePlaceholders ||
        oldDelegate.pendingArrowStart != pendingArrowStart ||
        oldDelegate.draftArrowEnd != draftArrowEnd ||
        oldDelegate.selection != selection;
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
      tooltip: '',
      initialValue: value,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<String>(
            value: option,
            height: 38,
            child: Text(
              option.isEmpty ? 'None' : option,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: _SketchBlockEditorScreenState._text,
                fontSize: AppTypography.bodySize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
      child: Container(
        height: 47,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _SketchBlockEditorScreenState._green),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayValue,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: _SketchBlockEditorScreenState._text,
                  fontSize: AppTypography.bodySize,
                  height: 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SvgPicture.asset(
              'assets/learning_module/text_block_chevron.svg',
              width: 13,
              height: 13,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SheetOption({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: _SketchBlockEditorScreenState._text,
              fontSize: AppTypography.bodySize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Reuses the editor's drawing renderer without drawing or selection controls.
class SketchEvidencePreview extends StatelessWidget {
  const SketchEvidencePreview({super.key, required this.data});
  final SketchBlockData data;
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 345 / 206,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 345,
          height: 206,
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.white,
                  child: CustomPaint(
                    painter: _SketchPainter(
                      strokes: data.strokes,
                      textItems: data.textItems,
                      shapes: data.shapes,
                      arrows: data.arrows,
                      imagePlaceholders: data.imagePlaceholders,
                      pendingArrowStart: null,
                      draftArrowEnd: null,
                      selection: null,
                    ),
                  ),
                ),
              ),
              for (final image in data.imagePlaceholders)
                if (image.publicUrl.isNotEmpty || image.storagePath.isNotEmpty)
                  Positioned.fromRect(
                    rect: image.rect,
                    child: SavedEvidenceImage(source: image.toJson()),
                  ),
            ],
          ),
        ),
      ),
    ),
  );
}
