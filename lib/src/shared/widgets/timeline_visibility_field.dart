import 'package:flutter/material.dart';
import '../styling/app_typography.dart';

/// Both timeline creation flows share the same audience choices.
class TimelineVisibilityField extends StatelessWidget {
  const TimelineVisibilityField({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Visibility', style: AppTypography.fieldLabel),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: value,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        items: const [
          DropdownMenuItem(
            value: 'members',
            child: Text('Project members only'),
          ),
          DropdownMenuItem(value: 'public', child: Text('Public')),
        ],
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
      const SizedBox(height: 16),
    ],
  );
}
