import '../../../shared/widgets/compact_list_item.dart';
import '../../../shared/widgets/currency_amount_input.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/journal_section_header.dart';
import '../../../shared/styling/app_metrics.dart';
import 'package:flutter/material.dart';
import '../../../shared/styling/app_typography.dart';
import '../../../shared/styling/app_colors.dart';
import '../../../shared/widgets/modal_actions.dart';
import '../../../shared/widgets/item_action_menu.dart';

/// Journal-owned budget, kept with its build rather than a mutable project list.
class BuildMaterialsStage extends StatelessWidget {
  const BuildMaterialsStage({
    super.key,
    required this.items,
    required this.currency,
    this.noMaterials = false,
    this.showHeading = true,
    this.onChanged,
    this.onNoMaterials,
    this.componentName,
  });
  final List<Map> items;
  final String currency;
  final String? componentName;
  final bool noMaterials;
  final bool showHeading;
  final void Function(List<Map<String, dynamic>>, String)? onChanged;
  final ValueChanged<bool>? onNoMaterials;

  Future<void> _edit(BuildContext context, [int? index]) async {
    final item = index == null ? null : items[index];
    final name = TextEditingController(text: item?['name']?.toString() ?? '');
    final cost = TextEditingController(text: item?['cost']?.toString() ?? '');
    var selectedCurrency = currency;
    final form = GlobalKey<FormState>();
    final result = await showAppDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(index == null ? 'Add Item' : 'Edit Item'),
          content: SizedBox(
            width: 360,
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Item', style: AppTypography.fieldLabel),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: name,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Enter an item name.'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  const Text('Cost', style: AppTypography.fieldLabel),
                  const SizedBox(height: 8),
                  CurrencyAmountInput(
                    controller: cost,
                    currency: selectedCurrency,
                    onCurrencyChanged: items.isEmpty
                        ? (value) => update(() => selectedCurrency = value)
                        : null,
                    validator: (value) {
                      final number = double.tryParse((value ?? '').trim());
                      return number == null || !number.isFinite || number < 0
                          ? 'Enter a valid cost of zero or more.'
                          : null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate())
                  Navigator.pop(context, {
                    'name': name.text.trim(),
                    'cost': double.parse(cost.text.trim()),
                    'currency': selectedCurrency,
                    'createdAt':
                        item?['createdAt'] ?? DateTime.now().toIso8601String(),
                  });
              },
              child: Text(index == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      name.dispose();
      cost.dispose();
    });
    // Controllers remain alive until the dialog's exit animation has completed.
    if (result == null) return;
    final updated = items
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (index == null) {
      updated.add(result);
    } else {
      updated[index] = result;
    }
    onChanged?.call(updated, selectedCurrency);
  }

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(
      0,
      (sum, item) => sum + ((item['cost'] as num?)?.toDouble() ?? 0),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeading) const JournalSectionHeader(title: 'Materials & Cost'),
        Center(
          child: Container(
            width: 184,
            height: 184,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$currency ${total.toStringAsFixed(2)}',
                  style: AppTypography.pageTitle.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Total Spent', style: AppTypography.helper),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppMetrics.sectionGap),
        const Text('Itemized Budget List', style: AppTypography.fieldLabel),
        const SizedBox(height: 8),
        Text(
          onChanged == null
              ? 'Materials and costs recorded for this build.'
              : 'Add the materials and costs used for this build.',
          style: AppTypography.helper,
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < items.length; i++)
          Column(
            children: [
              CompactListItem(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.circle,
                    color: AppColors.primary,
                    size: 12,
                  ),
                  title: Text('${items[i]['name']}', style: AppTypography.body),
                  subtitle: Text(
                    [
                      if ((componentName ?? '').isNotEmpty) componentName!,
                      if (DateTime.tryParse(
                            items[i]['createdAt']?.toString() ?? '',
                          )
                          case final date?)
                        DateFormat('MMM d').format(date),
                    ].join(' • '),
                    style: AppTypography.helper,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$currency ${((items[i]['cost'] as num?) ?? 0).toStringAsFixed(2)}',
                        style: AppTypography.body,
                      ),
                      if (onChanged != null)
                        ItemActionMenu(
                          onEdit: () => _edit(context, i),
                          onDelete: () {
                            final updated = [...items]..removeAt(i);
                            onChanged!([
                              for (final item in updated)
                                Map<String, dynamic>.from(item),
                            ], currency);
                          },
                        ),
                    ],
                  ),
                ),
              ),
              if (i < items.length - 1) const Divider(height: 1),
            ],
          ),
        if (items.isEmpty && onChanged == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No materials or costs recorded.',
              style: AppTypography.helper,
            ),
          ),
        if (onChanged != null) ...[
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
          ),
          if (items.isEmpty)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'No materials or costs for this build',
                style: AppTypography.body,
              ),
              value: noMaterials,
              onChanged: (value) => onNoMaterials?.call(value ?? false),
            ),
        ],
      ],
    );
  }
}
