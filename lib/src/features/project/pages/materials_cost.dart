import 'package:flutter/material.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';

const _green = Color(0xFF5DB075);
const _yellow = Color(0xFFFFC93D);
const _red = Color(0xFFFD1212);
const _text = Color(0xFF1F2024);
const _divider = Color(0xFFE8E8E8);
const _fieldBorder = Color(0xFFE8EBEC);
const _placeholder = Color(0xFFA0A8AC);
const _canvasWidth = 402.0;

class MaterialsCostPage extends StatefulWidget {
  const MaterialsCostPage({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.tags,
    this.isOwner = true,
    this.projectsRepo,
    this.componentName,
    this.readOnly = false,
    this.onSaveComplete,
  });

  final String projectId;
  final String projectName;
  final List<String> tags;
  final bool isOwner;
  final ProjectsRepo? projectsRepo;
  final String? componentName;

  /// When true, hides editing affordances (used for the Prototyping read-only
  /// Materials preview).
  final bool readOnly;

  /// When provided, the Save action runs this after persisting (used by the
  /// Prototyping preview to continue into the shared Learning flow) instead of
  /// the default in-place save.
  final Future<void> Function()? onSaveComplete;

  @override
  State<MaterialsCostPage> createState() => _MaterialsCostPageState();
}

class _MaterialsCostPageState extends State<MaterialsCostPage> {
  late final ProjectsRepo _projectsRepo;
  final List<_MaterialItem> _allItems = [];
  final List<_MaterialItem> _items = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _projectsRepo = widget.projectsRepo ?? ProjectsRepo();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    final materials = await _projectsRepo.getMaterialsCost(widget.projectId);
    if (!mounted) return;

    setState(() {
      _allItems
        ..clear()
        ..addAll(
          (materials ?? const <Map<String, dynamic>>[]).map(
            _MaterialItem.fromMap,
          ),
        );
      final componentName = widget.componentName?.trim();
      final scopedMaterials = componentName == null || componentName.isEmpty
          ? _allItems
          : _allItems.where((item) => item.component == componentName);
      _items
        ..clear()
        ..addAll(scopedMaterials);
      _isLoading = false;
    });
  }

  double get _totalCost => _items.fold(0, (total, item) => total + item.cost);

  _CostLevel get _costLevel => _costLevelFor(_totalCost);

  Color get _costColor => _costLevel.color;

  String get _costLabel => _costLevel.label;

  Future<bool> _saveMaterials() async {
    setState(() => _isSaving = true);
    final mergedItems = _mergedItemsForSave();
    final ok = await _projectsRepo.updateMaterialsCost(
      id: widget.projectId,
      materials: mergedItems.map((item) => item.toMap()).toList(),
    );
    if (!mounted) return ok;
    setState(() {
      _isSaving = false;
      _allItems
        ..clear()
        ..addAll(mergedItems);
    });
    return ok;
  }

  List<_MaterialItem> _mergedItemsForSave() {
    final componentName = widget.componentName?.trim();
    if (componentName == null || componentName.isEmpty) return [..._items];
    return [
      ..._allItems.where((item) => item.component != componentName),
      ..._items,
    ];
  }

  Future<void> _close() async {
    if (widget.isOwner && !widget.readOnly) await _saveMaterials();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _onSaveTapped() async {
    if (widget.isOwner && !widget.readOnly) await _saveMaterials();
    if (!mounted) return;
    final onComplete = widget.onSaveComplete;
    if (onComplete != null) await onComplete();
  }

  Future<void> _addItem() async {
    if (!widget.isOwner) return;
    final item = await showModalBottomSheet<_MaterialItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddMaterialSheet(),
    );
    if (item == null || !mounted) return;

    final componentName = widget.componentName?.trim();
    setState(
      () => _items.add(
        componentName == null || componentName.isEmpty
            ? item
            : item.copyWith(component: componentName),
      ),
    );
    await _saveMaterials();
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    setState(() {
      _items.removeWhere((item) => _selectedIds.contains(item.id));
      _selectedIds.clear();
      _isEditing = false;
    });
    await _saveMaterials();
  }

  void _toggleSelected(String id) {
    if (!_isEditing) return;
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _canvasWidth),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(50, 0, 51, 96),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 128),
                                Center(
                                  child: _TotalSpentCircle(
                                    total: _totalCost,
                                    color: _costColor,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Center(
                                  child: _CostPill(
                                    label: _costLabel,
                                    color: _costColor,
                                  ),
                                ),
                                const SizedBox(height: 29),
                                const Text(
                                  'Itemized Budget List',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Input materials and cost of items used to build this component.',
                                  style: TextStyle(
                                    color: Color(0x80000000),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 26),
                                for (final item in _items)
                                  _ExpenseRow(
                                    item: item,
                                    indicatorColor: _costLevelFor(
                                      item.cost,
                                    ).color,
                                    isEditing: _isEditing,
                                    isSelected: _selectedIds.contains(item.id),
                                    onTap: () => _toggleSelected(item.id),
                                  ),
                                if (widget.isOwner && !widget.readOnly) ...[
                                  const SizedBox(height: 11),
                                  _AddItemRow(onTap: _addItem),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: _divider),
                          ),
                        ),
                        Positioned(
                          left: 15,
                          top: 22,
                          width: 32,
                          height: 32,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: _close,
                            icon: const SizedBox(
                              width: 20,
                              height: 20,
                              child: _BackChevronIcon(),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 90,
                          right: 90,
                          top: 32,
                          child: Text(
                            'Component: ${widget.componentName ?? widget.projectName}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _text,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 36,
                          top: 32,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _onSaveTapped,
                            child: Text(
                              _isSaving ? 'Saving...' : 'Save',
                              style: const TextStyle(
                                color: _green,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        if (_isEditing && _selectedIds.isNotEmpty)
                          Positioned(
                            right: 22,
                            bottom: 48,
                            child: TextButton(
                              onPressed: _deleteSelected,
                              child: const Text(
                                'Delete',
                                style: TextStyle(
                                  color: Color(0xFFD64545),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TotalSpentCircle extends StatelessWidget {
  const _TotalSpentCircle({required this.total, required this.color});

  final double total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 196,
      height: 196,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _formatCurrency(total),
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 40,
              height: 1,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 35),
          const Text(
            'Total Spent',
            style: TextStyle(
              color: Color(0xFFAFAFAF),
              fontSize: 14,
              height: 1,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CostPill extends StatelessWidget {
  const _CostPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 251,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 1,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.item,
    required this.indicatorColor,
    required this.isEditing,
    required this.isSelected,
    required this.onTap,
  });

  final _MaterialItem item;
  final Color indicatorColor;
  final bool isEditing;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (item.component.isNotEmpty) item.component,
      if (item.buildLog.isNotEmpty) item.buildLog,
      _shortDate(item.createdAt),
    ].join(' • ');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 343,
        height: 51,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 2,
              width: 16,
              height: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFD64545) : indicatorColor,
                  shape: BoxShape.circle,
                ),
                child: isEditing && isSelected ? const _CheckMarkIcon() : null,
              ),
            ),
            Positioned(
              left: 32,
              top: 0,
              width: 210,
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  height: 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Positioned(
              left: 32,
              top: 20,
              width: 210,
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFA1A1A1),
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Text(
                _formatCurrency(item.cost),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Divider(height: 1, thickness: 1, color: _divider),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddItemRow extends StatelessWidget {
  const _AddItemRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 180,
        height: 32,
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: _green,
                shape: BoxShape.circle,
              ),
              child: const _PlusIcon(),
            ),
            const SizedBox(width: 18),
            const Text(
              'Add Item',
              style: TextStyle(
                color: _text,
                fontSize: 16,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMaterialSheet extends StatefulWidget {
  const _AddMaterialSheet();

  @override
  State<_AddMaterialSheet> createState() => _AddMaterialSheetState();
}

class _AddMaterialSheetState extends State<_AddMaterialSheet> {
  final _itemController = TextEditingController();
  final _costController = TextEditingController();
  final _componentController = TextEditingController();
  final _buildLogController = TextEditingController();

  @override
  void dispose() {
    _itemController.dispose();
    _costController.dispose();
    _componentController.dispose();
    _buildLogController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _itemController.text.trim();
    final cost = double.tryParse(_costController.text.trim()) ?? 0;
    if (name.isEmpty) return;

    Navigator.of(context).pop(
      _MaterialItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        cost: cost,
        component: _componentController.text.trim(),
        buildLog: _buildLogController.text.trim(),
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: 399,
        margin: const EdgeInsets.symmetric(horizontal: 30),
        padding: const EdgeInsets.fromLTRB(18, 18, 22, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 24,
              child: Stack(
                children: [
                  Positioned(
                    left: -10,
                    top: -8,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const SizedBox(
                        width: 18,
                        height: 18,
                        child: _CloseIcon(),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: Center(
                      child: Text(
                        'Add Item',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          height: 1,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 4,
                    child: GestureDetector(
                      onTap: _save,
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          color: _green,
                          fontSize: 14,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 17),
            _SheetLabel('Item'),
            const SizedBox(height: 8),
            _SheetTextField(controller: _itemController),
            const SizedBox(height: 18),
            _SheetLabel('Cost'),
            const SizedBox(height: 8),
            _CostField(controller: _costController),
            const SizedBox(height: 13),
            _SheetLabel('Component'),
            const SizedBox(height: 8),
            _SheetTextField(
              controller: _componentController,
              hintText: 'Search for component',
            ),
            const SizedBox(height: 13),
            _SheetLabel('Build Log'),
            const SizedBox(height: 8),
            _SheetTextField(
              controller: _buildLogController,
              hintText: 'Search for Build',
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 14,
        height: 1,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  const _SheetTextField({required this.controller, this.hintText});

  final TextEditingController controller;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.next,
        style: const TextStyle(fontSize: 14, height: 21 / 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: _placeholder),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 10,
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _fieldBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _green),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class _CostField extends StatelessWidget {
  const _CostField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Container(
            width: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: _fieldBorder),
                top: BorderSide(color: _fieldBorder),
                bottom: BorderSide(color: _fieldBorder),
              ),
              borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
            ),
            child: const Text(
              r'$',
              style: TextStyle(
                color: Color(0xFF323639),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              style: const TextStyle(
                color: Color(0xFF323639),
                fontSize: 14,
                height: 21 / 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(color: _placeholder),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _fieldBorder),
                  borderRadius: BorderRadius.zero,
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _green),
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
          ),
          Container(
            width: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: _fieldBorder),
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(8),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🇺🇸', style: TextStyle(fontSize: 14)),
                SizedBox(width: 8),
                Text(
                  'USD',
                  style: TextStyle(
                    color: Color(0xFF323639),
                    fontSize: 14,
                    height: 21 / 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 8),
                SizedBox(width: 15, height: 15, child: _UpDownIcon()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackChevronIcon extends StatelessWidget {
  const _BackChevronIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BackChevronPainter());
  }
}

class _CloseIcon extends StatelessWidget {
  const _CloseIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ClosePainter());
  }
}

class _PlusIcon extends StatelessWidget {
  const _PlusIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PlusPainter());
  }
}

class _CheckMarkIcon extends StatelessWidget {
  const _CheckMarkIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CheckPainter());
  }
}

class _UpDownIcon extends StatelessWidget {
  const _UpDownIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _UpDownPainter());
  }
}

abstract class _MaterialLinePainter extends CustomPainter {
  _MaterialLinePainter(this.color);

  final Color color;

  Paint get stroke => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BackChevronPainter extends _MaterialLinePainter {
  _BackChevronPainter() : super(_green);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width * .68, size.height * .08),
      Offset(size.width * .25, size.height * .5),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * .25, size.height * .5),
      Offset(size.width * .68, size.height * .92),
      stroke,
    );
  }
}

class _ClosePainter extends _MaterialLinePainter {
  _ClosePainter() : super(_green);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), stroke);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), stroke);
  }
}

class _PlusPainter extends _MaterialLinePainter {
  _PlusPainter() : super(Colors.white);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width * .5, size.height * .25),
      Offset(size.width * .5, size.height * .75),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * .25, size.height * .5),
      Offset(size.width * .75, size.height * .5),
      stroke,
    );
  }
}

class _CheckPainter extends _MaterialLinePainter {
  _CheckPainter() : super(Colors.white);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width * .2, size.height * .52),
      Offset(size.width * .42, size.height * .74),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * .42, size.height * .74),
      Offset(size.width * .82, size.height * .28),
      stroke,
    );
  }
}

class _UpDownPainter extends _MaterialLinePainter {
  _UpDownPainter() : super(const Color(0xFF323639));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width * .32, size.height * .42),
      Offset(size.width * .5, size.height * .24),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * .5, size.height * .24),
      Offset(size.width * .68, size.height * .42),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * .32, size.height * .58),
      Offset(size.width * .5, size.height * .76),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * .5, size.height * .76),
      Offset(size.width * .68, size.height * .58),
      stroke,
    );
  }
}

class _MaterialItem {
  const _MaterialItem({
    required this.id,
    required this.name,
    required this.cost,
    required this.component,
    required this.buildLog,
    required this.createdAt,
  });

  final String id;
  final String name;
  final double cost;
  final String component;
  final String buildLog;
  final DateTime createdAt;

  factory _MaterialItem.fromMap(Map<String, dynamic> map) {
    return _MaterialItem(
      id:
          map['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: map['name']?.toString() ?? '',
      cost: (map['cost'] as num?)?.toDouble() ?? 0,
      component: map['component']?.toString() ?? '',
      buildLog: map['buildLog']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'cost': cost,
      'component': component,
      'buildLog': buildLog,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  _MaterialItem copyWith({String? component}) {
    return _MaterialItem(
      id: id,
      name: name,
      cost: cost,
      component: component ?? this.component,
      buildLog: buildLog,
      createdAt: createdAt,
    );
  }
}

class _CostLevel {
  const _CostLevel({required this.label, required this.color});

  final String label;
  final Color color;
}

_CostLevel _costLevelFor(double cost) {
  if (cost < 40) {
    return const _CostLevel(label: 'LOW COST PROJECT', color: _green);
  }
  if (cost <= 100) {
    return const _CostLevel(label: 'MEDIUM COST PROJECT', color: _yellow);
  }
  return const _CostLevel(label: 'HIGH COST PROJECT', color: _red);
}

String _formatCurrency(double value) => '\$${value.toStringAsFixed(2)}';

String _shortDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}';
}
