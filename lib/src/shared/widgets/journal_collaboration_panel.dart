import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../features/project/services/journal_collaboration.dart';
import '../../features/project/pages/journal_entry_view.dart';
import '../../backend/db/models/journal_entry.dart';

/// The editor's existing navigation stays intact. This extra section picker is
/// also usable while another collaborator owns the section displayed below it.
class JournalCollaborationPanel extends StatefulWidget {
  const JournalCollaborationPanel({
    super.key,
    required this.collaboration,
    required this.flush,
    required this.child,
    this.sections = const {},
    this.section,
    this.onSectionSelected,
    this.onRemoteEntry,
  });
  final JournalCollaboration collaboration;
  final Future<bool> Function() flush;
  final Widget child;
  final Map<String, String> sections;
  final String? section;
  final ValueChanged<String>? onSectionSelected;
  final ValueChanged<JournalEntry>? onRemoteEntry;
  @override
  State<JournalCollaborationPanel> createState() =>
      _JournalCollaborationPanelState();
}

class _JournalCollaborationPanelState extends State<JournalCollaborationPanel>
    with WidgetsBindingObserver {
  JournalCollaboration get live => widget.collaboration;
  bool _switching = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    live.addListener(_changed);
    unawaited(live.start(widget.section ?? 'free_notes'));
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final entry = live.latest;
    if (entry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRemoteEntry?.call(entry);
      });
    }
  }

  @override
  void didUpdateWidget(JournalCollaborationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.section != oldWidget.section && widget.section != null) {
      unawaited(live.changeSection(widget.section!));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(live.poll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    live.removeListener(_changed);
    super.dispose();
  }

  Future<void> _reviewConflict() async {
    final local = live.conflictingLocal;
    if (local == null) return;
    final lines = <String>[];
    void collect(dynamic node, [String label = '']) {
      if (node is Map) {
        for (final item in node.entries) {
          if (const {
            'id',
            'stage',
            'type',
            'submitted',
            'submittedAt',
            'visitedStages',
            'currentStage',
          }.contains(item.key))
            continue;
          collect(
            item.value,
            item.key.toString().replaceAllMapped(
              RegExp(r'([a-z])([A-Z])'),
              (m) => '${m[1]} ${m[2]}',
            ),
          );
        }
      } else if (node is List) {
        for (final item in node) {
          collect(item, label);
        }
      } else if (node is String && node.trim().isNotEmpty) {
        lines.add('${label.isEmpty ? '' : '$label: '}$node');
      }
    }

    collect(local);
    final text = lines.join('\n\n');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your changes are still here'),
        content: SizedBox(
          width: 500,
          height: 280,
          child: SingleChildScrollView(child: SelectableText(text)),
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: text)),
            child: const Text('Copy my changes'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              // Explicitly choosing the saved version leaves the local recovery in
              // storage until the replacement editor saves. Copy is available above.
              await live.poll();
              final entry = live.latest;
              final project = entry == null
                  ? null
                  : await live.repo.getProjectById(entry.projectId);
              if (!mounted || entry == null || project == null) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) =>
                      editableJournalEntryPage(entry, project, live.repo),
                ),
              );
            },
            child: const Text('Use saved version'),
          ),
        ],
      ),
    );
  }

  Future<void> _reload() async {
    setState(() => _switching = true);
    // Save first. A conflicting local draft must never disappear on reload.
    if ((live.everEditable && !await widget.flush()) || !mounted) {
      if (mounted) setState(() => _switching = false);
      return;
    }
    await live.poll();
    final entry = live.latest;
    final project = await live.repo.getProjectById(entry?.projectId ?? '');
    if (!mounted) return;
    if (entry == null || project == null) {
      setState(() => _switching = false);
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => editableJournalEntryPage(entry, project, live.repo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final green = Theme.of(context).colorScheme.primary;
    final owner = live.owner;
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Leave entry',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back, size: 20),
                      ),
                      for (final person in live.people)
                        Tooltip(
                          message:
                              '${person.name}${person.sessionId == live.sessionId ? ' (you)' : ''} · ${widget.sections[person.section] ?? 'Free Notes'}${person.editing ? ' · editing' : ' · viewing'}',
                          child: CircleAvatar(
                            radius: 15,
                            backgroundColor: green.withValues(alpha: .12),
                            foregroundImage: person.avatar?.isNotEmpty == true
                                ? NetworkImage(person.avatar!)
                                : null,
                            child: Text(
                              person.name.isEmpty
                                  ? '?'
                                  : person.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      Text(
                        live.connected
                            ? '${live.people.length} here now'
                            : 'Connecting collaboration…',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (widget.sections.isNotEmpty)
                        DropdownButton<String>(
                          value: widget.sections.containsKey(widget.section)
                              ? widget.section
                              : null,
                          isDense: true,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final item in widget.sections.entries)
                              DropdownMenuItem(
                                value: item.key,
                                child: Text(
                                  item.value,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                          onChanged: _switching
                              ? null
                              : (value) async {
                                  if (value == null) return;
                                  setState(() => _switching = true);
                                  final ok =
                                      !live.canEdit || await widget.flush();
                                  if (ok && mounted)
                                    widget.onSectionSelected?.call(value);
                                  if (mounted)
                                    setState(() => _switching = false);
                                },
                        ),
                      if (widget.onRemoteEntry == null && live.connected)
                        TextButton(
                          onPressed: _switching ? null : _reload,
                          child: const Text('Load latest changes'),
                        ),
                    ],
                  ),
                  if (live.error != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            live.error!,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: live.poll,
                          child: const Text('Retry'),
                        ),
                        if (live.conflictingLocal != null)
                          TextButton(
                            onPressed: _reviewConflict,
                            child: const Text('Review my changes'),
                          ),
                      ],
                    )
                  else if (owner != null && !live.canEdit)
                    Text(
                      '${owner.name} is editing this section. Choose another section or wait here.',
                      style: const TextStyle(fontSize: 12),
                    )
                  else if (live.connected && widget.sections.isNotEmpty)
                    const Text(
                      'You can edit this section. Others can work in another section.',
                      style: TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: AbsorbPointer(
            absorbing: !live.canEdit || _switching,
            child: ExcludeFocus(
              excluding: !live.canEdit || _switching,
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}
