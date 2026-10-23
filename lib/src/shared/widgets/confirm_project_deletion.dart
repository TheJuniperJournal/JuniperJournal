import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'package:flutter/material.dart';

/// Returns true only after both the warning and typed confirmation succeed.
Future<bool> confirmProjectDeletion(BuildContext context) async {
  final proceed = await showAppDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('Delete Project?'),
      content: const Text(
        'Are you sure you want to delete this project? This permanently deletes its journal entries, impacts and materials. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Yes, continue'),
        ),
      ],
    ),
  );
  if (proceed != true || !context.mounted) return false;
  return await showAppDialog<bool>(
        context: context,
        builder: (_) => const _TypedDeleteConfirmation(),
      ) ==
      true;
}

class _TypedDeleteConfirmation extends StatefulWidget {
  const _TypedDeleteConfirmation();
  @override
  State<_TypedDeleteConfirmation> createState() =>
      _TypedDeleteConfirmationState();
}

class _TypedDeleteConfirmationState extends State<_TypedDeleteConfirmation> {
  final _confirmation = TextEditingController();
  bool get _matches => _confirmation.text.trim().toLowerCase() == 'delete';
  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    title: const Text('Confirm project deletion'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Type '),
              TextSpan(
                text: '(delete)',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              TextSpan(
                text: ' below, then submit to permanently delete this project.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmation,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            label: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Type '),
                  TextSpan(
                    text: '(delete)',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        onPressed: _matches ? () => Navigator.pop(context, true) : null,
        child: const Text('Submit'),
      ),
    ],
  );
}
