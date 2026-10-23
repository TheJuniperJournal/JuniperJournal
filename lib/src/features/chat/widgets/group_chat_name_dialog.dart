import 'package:flutter/material.dart';
import '../../../shared/styling/app_typography.dart';

class GroupChatNameDialog extends StatefulWidget {
  const GroupChatNameDialog({
    super.key,
    required this.initialName,
    this.title = 'Rename group chat',
    this.confirmLabel = 'Save',
    this.onSave,
  });
  final String initialName;
  final String title;
  final String confirmLabel;
  final Future<bool> Function(String)? onSave;
  @override
  State<GroupChatNameDialog> createState() => _GroupChatNameDialogState();
}

class _GroupChatNameDialogState extends State<GroupChatNameDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final name = _name.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    var ok = true;
    try {
      if (widget.onSave != null) ok = await widget.onSave!(name);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, name);
    } else {
      setState(() {
        _saving = false;
        _error = 'Could not save the group name. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a name everyone in this group will see.',
              style: AppTypography.helper,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              autofocus: true,
              enabled: !_saving,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Group name',
                counterText: '',
              ),
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? 'Enter a group name'
                  : value!.trim().length > 80
                  ? 'Use 80 characters or fewer'
                  : null,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: AppTypography.requirement),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.confirmLabel),
        ),
      ],
    ),
  );
}
