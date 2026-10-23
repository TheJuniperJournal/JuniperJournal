import 'package:flutter/material.dart';
import '../styling/app_colors.dart';

/// Flexible list editor row. Supply fields or metadata in the body.
class CompactListItem extends StatelessWidget {
  const CompactListItem({
    super.key,
    required this.child,
    this.leading,
    this.onRemove,
    this.removeLabel = 'Remove item',
    this.centerContent = false,
  });
  final bool centerContent;
  final Widget child;
  final Widget? leading;
  final VoidCallback? onRemove;
  final String removeLabel;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      crossAxisAlignment: centerContent
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[
          Padding(
            padding: EdgeInsets.only(top: centerContent ? 0 : 10),
            child: leading!,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(child: child),
        if (onRemove != null) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: removeLabel,
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
          ),
        ],
      ],
    ),
  );
}
