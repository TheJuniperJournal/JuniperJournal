import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:flutter/material.dart';

/// Shared overflow actions for content cards. Pass only authorized actions.
/// Editable content always presents Edit before Delete; extra actions follow.
class ItemActionMenu extends StatelessWidget {
  const ItemActionMenu({
    super.key,
    this.onEdit,
    this.onDelete,
    this.editLabel = 'Edit',
    this.deleteLabel = 'Delete',
    this.extraActions = const [],
    this.icon,
  });

  final VoidCallback? onEdit, onDelete;
  final String editLabel, deleteLabel;
  final List<ItemMenuAction> extraActions;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final actions = [
      if (onEdit != null)
        ItemMenuAction(editLabel, onEdit!, color: const Color(0xFF5DB075)),
      if (onDelete != null)
        ItemMenuAction(deleteLabel, onDelete!, color: const Color(0xFFFD1212)),
      ...extraActions,
    ];
    if (actions.isEmpty) return const SizedBox.shrink();
    return Theme(
      data: Theme.of(context).copyWith(
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
      ),
      child: PopupMenuButton<String>(
        clipBehavior: Clip.antiAlias,
        tooltip: 'More options',
        padding: EdgeInsets.zero,
        menuPadding: EdgeInsets.zero,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        constraints: const BoxConstraints.tightFor(width: 160),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        style: const ButtonStyle(),
        icon:
            icon ??
            const Icon(Icons.more_horiz, color: Color(0xFF8B8B8B), size: 20),
        onSelected: (index) => actions[int.parse(index)].onSelected(),
        itemBuilder: (_) => [
          for (var index = 0; index < actions.length; index++) ...[
            if (index > 0) const PopupMenuDivider(height: 1),
            PopupMenuItem<String>(
              value: index.toString(),
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  actions[index].label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    color: actions[index].color,
                    fontSize: AppTypography.bodySize,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ItemMenuAction {
  const ItemMenuAction(
    this.label,
    this.onSelected, {
    this.color = const Color(0xFF1C1C1C),
  });
  final String label;
  final VoidCallback onSelected;
  final Color color;
}
