import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:juniper_journal/src/shared/widgets/journal_section_header.dart';
import '../../../backend/db/models/journal_entry.dart';
import '../../../shared/widgets/currency_amount_input.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/item_action_menu.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import '../../../shared/widgets/content_aligned_back_button.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';

const _green = Color(0xFF5DB075);
const _yellow = Color(0xFFFFC93D);
const _red = Color(0xFFFD1212);
const _text = Color(0xFF1F2024);
const _divider = Color(0xFFE8E8E8);
const _fieldBorder = AppColors.primary;
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
  final Set<String> _components = {};
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
    List<JournalEntry>? entries;
    try {
      entries = await _projectsRepo.getJournalEntries(
        projectId: widget.projectId,
      );
    } catch (_) {
      entries = [];
    }
    void collect(dynamic node) {
      if (node is Map) {
        if (node['features'] is List &&
            node['name'] is String &&
            node['id'] != null)
          _components.add(node['name'] as String);
        for (final value in node.values) collect(value);
      } else if (node is List) {
        for (final value in node) collect(value);
      }
    }

    for (final entry in entries ?? []) collect(entry.content);
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

  Future<void> _addItem() async {
    if (!widget.isOwner) return;
    final item = await showAppModalBottomSheet<_MaterialItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMaterialSheet(
        components: _components.toList()..sort(),
        currency: _allItems.isEmpty ? 'USD' : _allItems.first.currency,
        currencyLocked: _allItems.isNotEmpty,
      ),
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

  Future<void> _editItem(_MaterialItem existing) async {
    if (!widget.isOwner || widget.readOnly) return;
    final updated = await showAppModalBottomSheet<_MaterialItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMaterialSheet(
        components: _components.toList()..sort(),
        item: existing,
        currency: existing.currency,
        currencyLocked: _allItems.length > 1,
      ),
    );
    if (updated == null || !mounted) return;
    setState(
      () =>
          _items[_items.indexWhere((item) => item.id == existing.id)] = updated,
    );
    await _saveMaterials();
  }

  Future<void> _deleteItem(_MaterialItem item) async {
    if (!widget.isOwner || widget.readOnly) return;
    setState(() => _items.removeWhere((existing) => existing.id == item.id));
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
              constraints: BoxConstraints(
                maxWidth: JournalPageLayout.widthFor(
                  context,
                  mobileWidth: _canvasWidth,
                ),
              ),
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
                                const SizedBox(height: 80),
                                Center(
                                  child: _TotalSpentCircle(
                                    total: _totalCost,
                                    currency: _allItems.isEmpty
                                        ? 'USD'
                                        : _allItems.first.currency,
                                    color: _costColor,
                                  ),
                                ),
                                const SizedBox(height: AppMetrics.fieldGap),
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
                                    fontFamily: AppTypography.bodyFamily,
                                    color: AppColors.textPrimary,
                                    fontSize: AppTypography.bodySize,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Input materials and cost of items used to build this component.',
                                  style: TextStyle(
                                    fontFamily: AppTypography.bodyFamily,
                                    color: AppColors.textSecondary,
                                    fontSize: AppTypography.helperSize,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: AppMetrics.fieldGap),
                                for (final item in _items)
                                  _ExpenseRow(
                                    item: item,
                                    indicatorColor: _costLevelFor(
                                      item.cost,
                                    ).color,
                                    onEdit:
                                        widget.isOwner &&
                                            !widget.readOnly &&
                                            !_isEditing
                                        ? () => _editItem(item)
                                        : null,
                                    onDelete:
                                        widget.isOwner &&
                                            !widget.readOnly &&
                                            !_isEditing
                                        ? () => _deleteItem(item)
                                        : null,
                                    onRemove: _isEditing
                                        ? () => _deleteItem(item)
                                        : null,
                                    isEditing: _isEditing,
                                    isSelected: _selectedIds.contains(item.id),
                                    onTap: () => _isEditing
                                        ? _toggleSelected(item.id)
                                        : _editItem(item),
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
                          left: 0,
                          right: 0,
                          top: 0,
                          child: _BudgetHeader(
                            title: widget.componentName == null
                                ? 'Materials & Cost'
                                : 'Component: ${widget.componentName}',
                            onBack: _close,
                            onSave:
                                widget.isOwner && !widget.readOnly && !_isSaving
                                ? () => setState(() {
                                    _isEditing = !_isEditing;
                                    _selectedIds.clear();
                                  })
                                : null,
                            saveLabel: widget.isOwner && !widget.readOnly
                                ? (_isEditing ? 'Done' : 'Edit')
                                : '',
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
                                  fontSize: AppTypography.buttonSize,
                                  fontWeight: FontWeight.w600,
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
  const _TotalSpentCircle({
    required this.total,
    required this.color,
    this.currency = 'USD',
  });
  final String currency;

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
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _formatCurrency(total, currency),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTypography.headingFamily,
                    color: color,
                    fontSize: AppTypography.heroSize,
                    height: 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppMetrics.fieldGap),
            const Text(
              'Total Spent',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFAFAFAF),
                fontSize: AppTypography.bodySize,
                height: 1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
          fontFamily: AppTypography.bodyFamily,
          color: Colors.white,
          fontSize: AppTypography.bodySize,
          height: 1,
          fontWeight: FontWeight.w500,
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
    this.onEdit,
    this.onDelete,
    this.onRemove,
  });

  final VoidCallback? onRemove;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final _MaterialItem item;
  final Color indicatorColor;
  final bool isEditing;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (item.component.isNotEmpty) item.component,
      _shortDate(item.createdAt),
    ].join(' • ');

    return AppTapTarget(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: isEditing
                  ? AppTapTarget(
                      onTap: onRemove,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: _red,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.remove,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: indicatorColor,
                        shape: BoxShape.circle,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.helper,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 88,
              child: Text(
                _formatCurrency(item.cost, item.currency),
                textAlign: TextAlign.right,
                style: AppTypography.body,
              ),
            ),
            if (onEdit != null)
              SizedBox(
                width: 32,
                child: ItemActionMenu(onEdit: onEdit, onDelete: onDelete),
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
    return AppTapTarget(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 180,
        height: 32,
        child: Row(
          children: [
            Transform.translate(
              offset: const Offset(-4, 0),
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                ),
                child: const _PlusIcon(),
              ),
            ),
            const SizedBox(width: 18),
            const Text(
              'Add Item',
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: AppColors.primary,
                fontSize: AppTypography.buttonSize,
                height: 1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMaterialSheet extends StatefulWidget {
  const _AddMaterialSheet({
    this.components = const [],
    this.item,
    this.currency = 'USD',
    this.currencyLocked = false,
  });
  final String currency;
  final bool currencyLocked;
  final List<String> components;

  final _MaterialItem? item;

  @override
  State<_AddMaterialSheet> createState() => _AddMaterialSheetState();
}

class _AddMaterialSheetState extends State<_AddMaterialSheet> {
  final _itemController = TextEditingController();
  final _costController = TextEditingController();
  final _componentController = TextEditingController();
  late String _currency = widget.item?.currency ?? widget.currency;
  bool _saveAttempted = false;

  @override
  void dispose() {
    _itemController.dispose();
    _costController.dispose();
    _componentController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _itemController.text = item.name;
      _costController.text = item.cost.toStringAsFixed(2);
      _componentController.text = item.component;
    }
    _itemController.addListener(_updateValidation);
    _costController.addListener(_updateValidation);
  }

  void _updateValidation() => setState(() {});

  bool get _validCost {
    final cost = double.tryParse(_costController.text.trim());
    return cost != null && cost.isFinite && cost >= 0;
  }

  bool get _canSave => _itemController.text.trim().isNotEmpty && _validCost;

  void _save() {
    final name = _itemController.text.trim();
    if (!_canSave) {
      setState(() => _saveAttempted = true);
      final missing = <String>[
        if (name.isEmpty) 'Item is required.',
        if (_costController.text.trim().isEmpty)
          'Cost is required.'
        else if (!_validCost)
          'Cost only accepts numbers of 0 or more.',
      ];
      showAppDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.error_outline, color: _red),
          title: const Text(
            'Check required fields',
            style: TextStyle(color: _red),
          ),
          content: Text(
            missing.join('\n'),
            style: const TextStyle(color: _red),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    final cost = double.parse(_costController.text.trim());

    Navigator.of(context).pop(
      _MaterialItem(
        id: widget.item?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        currency: _currency,
        cost: cost,
        component: _componentController.text.trim(),
        buildLog: widget.item?.buildLog ?? '',
        createdAt: widget.item?.createdAt ?? DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: (MediaQuery.sizeOf(context).height - bottomInset - 32)
              .clamp(0.0, 600.0),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 30),
        padding: const EdgeInsets.fromLTRB(18, 8, 22, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BudgetHeader(
                title: widget.item == null ? 'Add Item' : 'Edit Item',
                close: true,
                inset: 0,
                onBack: () => Navigator.of(context).pop(),
                onSave: _save,
              ),
              const SizedBox(height: AppMetrics.labelGap),
              _SheetLabel('Item'),
              const SizedBox(height: 8),
              _SheetTextField(
                controller: _itemController,
                invalid: _saveAttempted && _itemController.text.trim().isEmpty,
              ),
              const SizedBox(height: AppMetrics.labelGap),
              _SheetLabel('Cost'),
              const SizedBox(height: 8),
              DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _saveAttempted && !_validCost
                        ? _red
                        : Colors.transparent,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _CostField(
                  controller: _costController,
                  currency: _currency,
                  onCurrencyChanged: widget.currencyLocked
                      ? null
                      : (value) => setState(() => _currency = value),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                (!_saveAttempted || _validCost)
                    ? 'Only numbers are accepted. Use 0 for a free item.'
                    : 'Required — only numbers are accepted (e.g. 1.00 or 0).',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.helperSize,
                  color: _saveAttempted && !_validCost ? _red : _placeholder,
                ),
              ),
              const SizedBox(height: 13),
              _SheetLabel('Component', optional: true),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue:
                    widget.components.contains(_componentController.text)
                    ? _componentController.text
                    : '',
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: '', child: Text('None')),
                  for (final component in widget.components)
                    DropdownMenuItem(
                      value: component,
                      child: Text(component, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => _componentController.text = value ?? '',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(
    this.text, {
    this.optional = false,
    this.requiredField = false,
  });

  final String text;
  final bool optional;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        children: [
          if (requiredField)
            const TextSpan(
              text: ' (Required)',
              style: TextStyle(color: _red),
            ),
          if (optional)
            const TextSpan(
              text: ' (Optional)',
              style: TextStyle(color: _placeholder),
            ),
        ],
      ),
      style: const TextStyle(
        fontFamily: AppTypography.bodyFamily,
        color: AppColors.textPrimary,
        fontSize: AppTypography.bodySize,
        height: 1,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  const _SheetTextField({
    required this.controller,
    this.hintText,
    this.invalid = false,
  });

  final TextEditingController controller;
  final String? hintText;
  final bool invalid;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.next,
        style: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          fontSize: AppTypography.bodySize,
          height: 1.4,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: _placeholder),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 10,
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: invalid ? _red : _fieldBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: invalid ? _red : _fieldBorder),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class _CostField extends StatelessWidget {
  const _CostField({
    required this.controller,
    this.currency = 'USD',
    this.onCurrencyChanged,
  });
  final TextEditingController controller;
  final String currency;
  final ValueChanged<String>? onCurrencyChanged;
  @override
  Widget build(BuildContext context) => CurrencyAmountInput(
    controller: controller,
    currency: currency,
    onCurrencyChanged: onCurrencyChanged,
  );
}

class _PlusIcon extends StatelessWidget {
  const _PlusIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PlusPainter());
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
    this.currency = 'USD',
    required this.component,
    required this.buildLog,
    required this.createdAt,
  });

  final String id;
  final String name;
  final double cost;
  final String currency;
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
      currency: map['currency']?.toString() ?? 'USD',
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
      'currency': currency,
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
      currency: currency,
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

String _formatCurrency(double value, [String currency = 'USD']) =>
    '${currencySymbol(currency)}${value.toStringAsFixed(2)}';

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

class _BudgetHeader extends StatelessWidget {
  const _BudgetHeader({
    required this.title,
    required this.onBack,
    required this.onSave,
    this.saveLabel = 'Save',
    this.close = false,
    this.inset = 24,
  });
  final String title;
  final VoidCallback onBack;
  final VoidCallback? onSave;
  final String saveLabel;
  final bool close;
  final double inset;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 64),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: _text,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: close
                ? IconButton(
                    onPressed: onBack,
                    tooltip: 'Close',
                    iconSize: 18,
                    color: _green,
                    icon: const Icon(Icons.close),
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    padding: EdgeInsets.zero,
                  )
                : ContentAlignedBackButton(onPressed: onBack),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onSave,
              style: TextButton.styleFrom(
                foregroundColor: _green,
                disabledForegroundColor: _placeholder,
                minimumSize: const Size(48, 44),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                saveLabel,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.buttonSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
