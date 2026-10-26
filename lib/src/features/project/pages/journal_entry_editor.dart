import '../../../shared/widgets/image_resize_frame.dart';
import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'package:juniper_journal/src/shared/widgets/protected_image.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'dart:convert';
import '../services/journal_text_selection.dart';
import '../services/journal_collaboration.dart';
import '../../../backend/db/models/user_profile.dart';
import '../../../shared/widgets/journal_entry_menu.dart';
import '../../../shared/widgets/journal_draft_session.dart';
import '../../../shared/widgets/journal_entry_title.dart';
import '../../../shared/widgets/journal_action_footer.dart';
import '../../../shared/widgets/journal_publication.dart';
import '../../../backend/security/input_validator.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'project_development_flow.dart';
import '../utils/journal_completion.dart';
import '../../../backend/db/models/journal_entry.dart';
import '../../../shared/widgets/content_aligned_back_button.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:image_picker/image_picker.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/services/media_service.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

// ── Public screen ─────────────────────────────────────────────────────────────

class JournalEntryEditorScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final List<String> tags;
  final String entryId;
  final String? entryAuthorId;
  final String initialTitle;
  final List<dynamic> initialContent;
  final String? initialProgress;
  final bool readOnly;
  final ProjectsRepo? projectsRepo;
  final bool freeNotes;
  final bool canvasOnly;
  final Future<String?> Function(ImageSource)? uploadImage;

  const JournalEntryEditorScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.tags,
    required this.entryId,
    this.entryAuthorId,
    required this.initialTitle,
    required this.initialContent,
    this.initialProgress,
    this.readOnly = false,
    this.projectsRepo,
    this.freeNotes = false,
    this.canvasOnly = false,
    this.uploadImage,
  });

  @override
  State<JournalEntryEditorScreen> createState() =>
      _JournalEntryEditorScreenState();
}

class _JournalEntryEditorScreenState extends State<JournalEntryEditorScreen> {
  late final _projectsRepo = widget.projectsRepo ?? ProjectsRepo();
  late String _entryId;
  late final _draftSession = JournalDraftSession(
    _projectsRepo,
    widget.projectId,
    onKept: (id) {
      if (mounted) setState(() => _entryId = id);
    },
    initial: widget.entryId.isEmpty
        ? null
        : JournalEntry(
            id: widget.entryId,
            authorId: widget.entryAuthorId,
            projectId: widget.projectId,
            title: widget.initialTitle,
            content: widget.initialContent,
            progress: widget.initialProgress,
          ),
  );
  List<Map<String, dynamic>> _participants = [];
  late final _participantMembers = _projectsRepo.getProjectMembers(
    projectId: widget.projectId,
  );
  bool _submitted = false;
  int _entryNumber = 1;
  bool get _isFreeNotes =>
      widget.freeNotes ||
      widget.initialContent.whereType<Map>().any(
        (row) => row['stage'] == 'free_notes',
      );
  late final _mediaService = MediaService();

  late final TextEditingController _titleController;
  final _titleFocus = FocusNode();
  String? _progress;

  final List<_Block> _blocks = [];
  int? _focusedIndex;

  bool _applyingRemote = false;
  bool _isSaving = false;
  bool _hasChanges = false;
  bool _showTitleValidation = false;
  DateTime? _lastSavedAt;
  Timer? _autoSaveTimer;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _participants = [
      for (final row in widget.initialContent.whereType<Map>())
        if (row['involved'] is List)
          for (final person in (row['involved'] as List).whereType<Map>())
            Map<String, dynamic>.from(person),
    ];
    _titleController = TextEditingController(
      text: RegExp(r'^Entry \d+:').hasMatch(widget.initialTitle)
          ? ''
          : widget.initialTitle,
    );
    journalEntryNumber(
      _projectsRepo,
      widget.projectId,
      widget.initialProgress ?? 'Discovery',
      widget.entryId.isEmpty
          ? null
          : JournalEntry(
              id: widget.entryId,
              projectId: widget.projectId,
              title: widget.initialTitle,
              content: widget.initialContent,
            ),
    ).then((number) {
      if (mounted) setState(() => _entryNumber = number);
    });
    _titleController.addListener(() {
      if (!_applyingRemote) _hasChanges = true;
    });
    _progress = switch (normalizePhase(widget.initialProgress)) {
      'discover' => 'Discovery',
      'ideating' => 'Ideation',
      'prototyping' => 'Prototyping',
      'implementation' => 'Implementation',
      _ => widget.initialProgress,
    };
    _entryId = widget.entryId;
    _submitted = widget.initialContent.whereType<Map>().any(
      (row) => row['stage'] == 'free_notes' && row['submitted'] == true,
    );

    _initBlocks();

    if (!widget.readOnly) {
      _autoSaveTimer = Timer.periodic(
        const Duration(milliseconds: 700),
        (_) => _autoSave(),
      );
    }
  }

  void _initBlocks() {
    var legacyIndex = 0;
    for (final item in widget.initialContent.whereType<Map>()) {
      if (!item.containsKey('type')) continue;
      final block = _Block.fromJson(Map<String, dynamic>.from(item));
      block.id = item['id']?.toString() ?? 'legacy-${legacyIndex++}';
      _listenToBlock(block);
      _blocks.add(block);
    }

    // Always have at least one body block
    if (_blocks.isEmpty) {
      final block = _Block.body('');
      _listenToBlock(block);
      _blocks.add(block);
    }
    _focusedIndex = 0;
  }

  void _listenToBlock(_Block block) {
    block.textController?.addListener(() {
      if (!_applyingRemote) _hasChanges = true;
    });
    block.captionController?.addListener(() {
      if (!_applyingRemote) _hasChanges = true;
    });
    for (final row in block.cells ?? <List<TextEditingController>>[]) {
      for (final cell in row) {
        cell.addListener(() {
          if (!_applyingRemote) _hasChanges = true;
        });
      }
    }
    if (block.focusNode != null) {
      block.focusNode!.addListener(() {
        if (block.focusNode!.hasFocus) {
          final currentIdx = _blocks.indexOf(block);
          if (currentIdx != -1) setState(() => _focusedIndex = currentIdx);
        }
      });
      // Backspace at position 0: move cursor to the end of the previous line
      // without merging or deleting any content.
      block.focusNode!.onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace) {
          final ctrl = block.textController;
          if (ctrl != null) {
            final sel = ctrl.selection;
            if (sel.isCollapsed && sel.start == 0) {
              final idx = _blocks.indexOf(block);
              if (idx > 0) {
                final prev = _blocks[idx - 1];
                if (prev.focusNode != null && prev.textController != null) {
                  prev.focusNode!.requestFocus();
                  // Defer selection so it runs after the focus-in handler
                  // (which would otherwise select-all the newly focused field).
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final end = prev.textController!.text.length;
                    prev.textController!.selection = TextSelection.collapsed(
                      offset: end,
                    );
                  });
                }
              }
              return KeyEventResult
                  .handled; // always consume — never delete content
            }
          }
        }
        return KeyEventResult.ignored;
      };
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleFocus.dispose();
    _titleController.dispose();
    for (final b in _blocks) {
      b.dispose();
    }
    super.dispose();
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  List<dynamic> _blocksToJson() => [
    if (_isFreeNotes)
      {
        'stage': 'free_notes',
        'submitted': _submitted,
        'involved': _participants,
      }
    else
      {'stage': 'participants', 'involved': _participants},
    ..._blocks.map((b) => {...b.toJson(), 'id': b.id}),
  ];

  void _receiveSharedNotes(JournalEntry entry) {
    if (!mounted ||
        _hasChanges ||
        _isSaving ||
        _blocks.any(
          (block) =>
              block.textController?.value.composing.isValid == true &&
              block.textController?.value.composing.isCollapsed == false,
        ))
      return;
    // Only acknowledged snapshots may replace local controls. Pending edits are
    // submitted first and merged atomically by the database.
    _applyingRemote = true;
    setState(() {
      _titleController.value = remoteJournalTextValue(
        _titleController.value,
        RegExp(r'^Entry \d+:').hasMatch(entry.title) ? '' : entry.title,
      );
      _progress = switch (normalizePhase(entry.progress)) {
        'discover' => 'Discovery',
        'ideating' => 'Ideation',
        'prototyping' => 'Prototyping',
        'implementation' => 'Implementation',
        _ => entry.progress,
      };
      final next = <_Block>[];
      var legacyIndex = 0;
      for (final row in entry.content.whereType<Map>()) {
        if (!row.containsKey('type')) continue;
        final id = row['id']?.toString() ?? 'legacy-${legacyIndex++}';
        _Block? existing;
        for (final block in _blocks) {
          if (block.id == id && block.toJson()['type'] == row['type']) {
            existing = block;
            break;
          }
        }
        // Preserve the focused text controller and selection for remote edits.
        if (existing?.textController != null) {
          final ctrl = existing!.textController!;
          final text = row['text']?.toString() ?? '';
          ctrl.value = remoteJournalTextValue(ctrl.value, text);
          next.add(existing);
        } else {
          final block = _Block.fromJson(Map<String, dynamic>.from(row))
            ..id = id;
          _listenToBlock(block);
          next.add(block);
        }
      }
      for (final block in _blocks) {
        if (!next.contains(block)) block.dispose();
      }
      _blocks
        ..clear()
        ..addAll(next);
      final meta = entry.content.whereType<Map>().where(
        (r) => r['stage'] == 'free_notes' || r['stage'] == 'participants',
      );
      if (meta.isNotEmpty) {
        _participants = (meta.first['involved'] as List? ?? [])
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
        _submitted = meta.first['submitted'] == true;
      }
      _draftSession.collaboration?.hydrated(entry);
    });
    _applyingRemote = false;
  }

  Future<bool> _persist() async {
    final content = _blocksToJson();
    final title = journalEntryTitle(
      _titleController.text,
      _entryNumber,
      _progress ?? 'Discovery',
    );
    if (await _draftSession.skipEmpty(title, content)) {
      _entryId = '';
      return true;
    }
    if (title.isEmpty) return false;
    try {
      if (_entryId.isEmpty) {
        final created = await _draftSession.createJournalEntry(
          projectId: widget.projectId,
          title: title,
          content: content,
          progress: _progress,
        );
        if (created == null) return false;
        _entryId = created.id;
        return true;
      }
      return await _draftSession.updateJournalEntry(
        entryId: _entryId,
        title: title,
        content: content,
        progress: _progress,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _autoSave() async {
    if (_isSaving || !_hasChanges) {
      return;
    }
    final savingFingerprint = jsonEncode([
      _titleController.text,
      _progress,
      _blocksToJson(),
    ]);
    setState(() => _isSaving = true);
    final ok = await _persist();
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (ok) {
        _lastSavedAt = DateTime.now();
        _hasChanges =
            savingFingerprint !=
            jsonEncode([_titleController.text, _progress, _blocksToJson()]);
      }
    });
  }

  Future<void> _saveAndPop({bool submit = false}) async {
    if (_isSaving) return;
    final hasContent = freeNotesHaveContent(_blocksToJson());
    final titleError = _titleController.text.trim().isEmpty
        ? null
        : InputValidator.journalTitle(_titleController.text);
    if ((hasContent || _entryId.isNotEmpty) && titleError != null) {
      journalValidationIssues(context).value = [
        JournalValidationIssue(
          titleError,
          () =>
              mounted &&
              InputValidator.journalTitle(_titleController.text) != null,
          changes: _titleController,
        ),
      ];
      _titleFocus.requestFocus();
      setState(() => _showTitleValidation = true);
      return;
    }
    setState(() => _isSaving = true);
    final previouslySubmitted = _submitted;
    if (submit) _submitted = true;
    final ok = await _persist() && await _draftSession.keep();
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (!ok) {
      _submitted = previouslySubmitted;
      showTopSnackBar(
        context,
        _projectsRepo.lastJournalSaveError ??
            'Failed to save entry. Your notes are still here.',
        isError: true,
      );
      return;
    }
    if (submit) {
      JournalPublication.returnHome(context);
    } else {
      Navigator.of(context).pop(true);
    }
  }

  String? get _savedLabel {
    if (_lastSavedAt == null ||
        (!_draftSession.kept && _draftSession.current == null))
      return null;
    final h = _lastSavedAt!.hour % 12 == 0 ? 12 : _lastSavedAt!.hour % 12;
    final m = _lastSavedAt!.minute.toString().padLeft(2, '0');
    final ampm = _lastSavedAt!.hour < 12 ? 'AM' : 'PM';
    return '${!_draftSession.kept
        ? 'Saved'
        : _isFreeNotes && !_submitted
        ? 'Draft saved'
        : 'Saved'} $h:$m $ampm';
  }

  // ── Block operations ────────────────────────────────────────────────────────

  void _insertAfterFocused(_Block newBlock) {
    final focused = _focusedIndex == null ? null : _blocks[_focusedIndex!];
    if (newBlock.type == _BlockType.body &&
        focused?.type == _BlockType.body &&
        focused!.textController!.text.isEmpty) {
      newBlock.dispose();
      focused.focusNode?.requestFocus();
      return;
    }
    _listenToBlock(newBlock);
    final insertAt = (_focusedIndex ?? _blocks.length - 1) + 1;
    setState(() {
      _blocks.insert(insertAt, newBlock);
      _focusedIndex = insertAt;
      _hasChanges = true;
    });
    // Request focus for text blocks
    WidgetsBinding.instance.addPostFrameCallback((_) {
      newBlock.focusNode?.requestFocus();
    });
  }

  void _removeBlock(int index) {
    if (_blocks.length <= 1) return; // always keep at least one block
    setState(() {
      _blocks[index].dispose();
      _blocks.removeAt(index);
      _focusedIndex = null;
      _hasChanges = true;
    });
  }

  Future<void> _showBlockActions() async {
    final index = _focusedIndex;
    if (index == null || index >= _blocks.length) return;
    final action = await showAppModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index > 0)
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: const Text('Move up'),
                onTap: () => Navigator.pop(context, 'up'),
              ),
            if (index < _blocks.length - 1)
              ListTile(
                leading: const Icon(Icons.arrow_downward),
                title: const Text('Move down'),
                onTap: () => Navigator.pop(context, 'down'),
              ),
            if (_blocks.length > 1)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove block'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            ListTile(
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'remove') {
      _removeBlock(index);
      return;
    }
    setState(() {
      final destination = action == 'up' ? index - 1 : index + 1;
      final block = _blocks.removeAt(index);
      _blocks.insert(destination, block);
      _focusedIndex = destination;
      _hasChanges = true;
    });
  }

  void _toggleHeaderBody() {
    final idx = _focusedIndex;
    if (idx == null || idx >= _blocks.length) return;
    final block = _blocks[idx];
    if (block.type != _BlockType.header && block.type != _BlockType.body)
      return;
    setState(() {
      block.type = block.type == _BlockType.header
          ? _BlockType.body
          : _BlockType.header;
      _hasChanges = true;
    });
  }

  // Split the line at the cursor: text before cursor stays in this line, text
  // after moves to a new body line inserted directly below.
  // Uses indexOf(block) instead of the closure-captured index so it stays
  // correct even if blocks were inserted/removed since the last rebuild.
  void _splitLineAtCursor(_Block block) {
    final idx = _blocks.indexOf(block);
    if (idx == -1) return;

    final ctrl = block.textController!;
    final cursor = ctrl.selection.isValid
        ? ctrl.selection.baseOffset
        : ctrl.text.length;
    final before = ctrl.text.substring(0, cursor);
    final after = ctrl.text.substring(cursor);

    ctrl.value = TextEditingValue(
      text: before,
      selection: TextSelection.collapsed(offset: before.length),
    );

    final newBlock = _Block.body(after);
    _listenToBlock(newBlock);
    setState(() {
      _blocks.insert(idx + 1, newBlock);
      _focusedIndex = idx + 1;
      _hasChanges = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      newBlock.focusNode?.requestFocus();
      newBlock.textController?.selection = const TextSelection.collapsed(
        offset: 0,
      );
    });
  }

  Future<void> _insertImage(ImageSource source) async {
    try {
      final url = widget.uploadImage != null
          ? await widget.uploadImage!(source)
          : await _mediaService.pickAndUploadImage(
              source,
              folder: 'journal-images',
              projectId: widget.projectId,
            );
      if (url == null || !mounted) return;
      _insertAfterFocused(_Block.image(url: url));
    } catch (_) {
      if (mounted)
        showTopSnackBar(
          context,
          'Could not add image. Please try again.',
          isError: true,
        );
    }
  }

  Future<void> _showInsertTableDialog() async {
    final result = await showAppDialog<({int rows, int cols})>(
      context: context,
      builder: (_) => const _TableSizeDialog(),
    );
    if (result == null || !mounted) return;
    _insertAfterFocused(_Block.table(rows: result.rows, cols: result.cols));
  }

  Future<void> _showInsertMathDialog() async {
    final latex = await showAppDialog<String>(
      context: context,
      builder: (_) => const _MathInputDialog(),
    );
    if (latex == null || latex.isEmpty || !mounted) return;
    _insertAfterFocused(_Block.math(latex));
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.readOnly && widget.canvasOnly)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _blocks.length; i++) _buildBlock(i, _blocks[i]),
        ],
      );
    if (widget.readOnly)
      return JournalReadingPage(
        entry: JournalEntry(
          id: widget.entryId,
          projectId: widget.projectId,
          title: widget.initialTitle,
          content: widget.initialContent,
          progress: widget.initialProgress,
        ),
        projectsRepo: _projectsRepo,
      );
    if (widget.initialContent.whereType<Map>().any(
      (row) => row['stage'] == 'prototyping' && row['entryType'] != null,
    )) {
      return PrototypingJournalEntryPage(
        projectId: widget.projectId,
        projectsRepo: _projectsRepo,
        entry: JournalEntry(
          id: widget.entryId,
          title: widget.initialTitle,
          content: widget.initialContent,
          projectId: widget.projectId,
          progress: widget.initialProgress,
        ),
        readOnly: widget.readOnly,
      );
    }

    if (widget.readOnly &&
        widget.initialContent.whereType<Map>().any(
          (stage) => stage['stage'] == 'analyze',
        )) {
      return DiscoveryEntryPreviewPage(
        entry: JournalEntry(
          id: widget.entryId,
          title: widget.initialTitle,
          content: widget.initialContent,
          projectId: widget.projectId,
          progress: widget.initialProgress,
        ),
      );
    }
    if (widget.readOnly) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            if (_progress != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Text(
                      _isFreeNotes ? 'Free Notes · Phase' : 'Phase',
                      style: const TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        fontSize: AppTypography.helperSize,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _progress!,
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: AppTypography.bodySize,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: PageScrollWithFooter(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < _blocks.length; i++)
                        _buildBlock(i, _blocks[i]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return JournalDraftGuard(
      session: _draftSession,
      flush: _persist,
      section: 'free_notes',
      onRemoteEntry: _receiveSharedNotes,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            if (!widget.readOnly)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 22,
                ),
                child: FutureBuilder<List<UserProfile>>(
                  future: _participantMembers,
                  builder: (context, snapshot) {
                    final members = snapshot.data ?? const <UserProfile>[];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        JournalInvolvedPeopleField(
                          creatorId:
                              widget.entryAuthorId ??
                              journalRepoUserId(_projectsRepo),
                          members: members,
                          selectedIds: _participants
                              .map((p) => p['id'].toString())
                              .toSet(),
                          onToggle: (id) => setState(() {
                            if (_participants.any((p) => p['id'] == id)) {
                              _participants.removeWhere((p) => p['id'] == id);
                            } else {
                              final person = members.firstWhere(
                                (p) => p.id == id,
                              );
                              _participants.add({
                                'id': id,
                                'name': person.resolvedDisplayName,
                                'avatarUrl': person.avatarUrl,
                              });
                            }
                            _hasChanges = true;
                          }),
                        ),
                      ],
                    );
                  },
                ),
              ),
            const Divider(height: 1, color: AppColors.divider),

            // Toolbar
            _buildToolbar(),
            const Divider(height: 1, color: AppColors.divider),

            // Block content
            Expanded(
              child: PageScrollWithFooter(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < _blocks.length; i++)
                        _buildBlock(i, _blocks[i]),
                      // Tap empty space to focus last text block
                      AppTapTarget(
                        onTap: () {
                          final lastText = _blocks.lastWhere(
                            (b) => b.focusNode != null,
                            orElse: () => _blocks.last,
                          );
                          lastText.focusNode?.requestFocus();
                        },
                        behavior: HitTestBehavior.translucent,
                        child: const SizedBox(
                          height: 80,
                          width: double.infinity,
                        ),
                      ),
                      JournalActionFooter(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton(
                                  onPressed: _isSaving
                                      ? null
                                      : () => Navigator.of(context).maybePop(),
                                  child: const Text('Back'),
                                ),
                                const SizedBox(width: 16),
                                FilledButton(
                                  onPressed: _isSaving
                                      ? null
                                      : () => _saveAndPop(submit: !_submitted),
                                  child: Text(
                                    _isSaving
                                        ? 'Saving...'
                                        : _submitted
                                        ? 'Done'
                                        : 'Submit',
                                  ),
                                ),
                              ],
                            ),
                            if (!widget.readOnly && _savedLabel != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    _savedLabel!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: AppTypography.bodyFamily,
                                      fontSize: AppTypography.helperSize,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      toolbarHeight: 72,
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      leadingWidth: 88,
      titleSpacing: 8,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: ContentAlignedBackButton(
          onPressed: widget.readOnly
              ? () => Navigator.of(context).pop()
              : () async {
                  await _persist();
                  if (mounted) Navigator.of(context).maybePop();
                },
        ),
      ),
      title: widget.readOnly
          ? Text(
              _titleController.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTypography.headingFamily,
                color: Colors.black87,
                fontSize: AppTypography.pageTitleSize,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            )
          : TextField(
              controller: _titleController,
              onChanged: (_) => setState(() {}),
              focusNode: _titleFocus,
              style: const TextStyle(
                fontFamily: AppTypography.headingFamily,
                color: Colors.black87,
                fontSize: AppTypography.pageTitleSize,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                errorText:
                    _showTitleValidation &&
                        _titleController.text.trim().isNotEmpty
                    ? InputValidator.journalTitle(_titleController.text)
                    : null,
                errorStyle: AppTypography.requirement,
                errorBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.red),
                ),
                focusedErrorBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 1.5),
                ),
                hintText: journalEntryTitle(
                  '',
                  _entryNumber,
                  _progress ?? 'Discovery',
                ),
                constraints: BoxConstraints(minHeight: 48),
                filled: false,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
      actions: widget.readOnly
          ? [
              JournalEntryMenu(
                repo: _projectsRepo,
                entry: JournalEntry(
                  id: _entryId,
                  authorId: widget.entryAuthorId,
                  projectId: widget.projectId,
                  title: widget.initialTitle,
                  content: widget.initialContent,
                  progress: widget.initialProgress,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    'Preview',
                    style: TextStyle(
                      fontFamily: AppTypography.headingFamily,
                      fontSize: AppTypography.helperSize,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
            ]
          : const [],
      shape: const Border(
        bottom: BorderSide(color: AppColors.divider, width: 0.6),
      ),
    );
  }

  Widget _buildToolbar() {
    final focusedBlock =
        _focusedIndex != null && _focusedIndex! < _blocks.length
        ? _blocks[_focusedIndex!]
        : null;
    final isTextBlock =
        focusedBlock?.type == _BlockType.header ||
        focusedBlock?.type == _BlockType.body;
    final isHeader = focusedBlock?.type == _BlockType.header;

    return PageScrollWithFooter(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // TT — toggle header/body
            _ToolbarBtn(
              child: _TtIcon(active: isHeader, enabled: isTextBlock),
              active: isHeader,
              onTap: isTextBlock ? _toggleHeaderBody : null,
              tooltip: 'Toggle header / body',
            ),
            _ToolbarBtn(
              icon: Icons.notes_outlined,
              onTap: () => _insertAfterFocused(_Block.body('')),
              tooltip: 'Add text',
            ),
            _ToolbarBtn(
              icon: Icons.more_vert,
              onTap: _showBlockActions,
              tooltip: 'Move or remove block',
            ),
            Container(width: 1, height: 28, color: AppColors.divider),
            // Camera
            _ToolbarBtn(
              icon: Icons.camera_alt_outlined,
              onTap: () => _insertImage(ImageSource.camera),
              tooltip: 'Take photo',
            ),
            // Gallery image
            _ToolbarBtn(
              icon: Icons.image_outlined,
              onTap: () => _insertImage(ImageSource.gallery),
              tooltip: 'Add image from gallery',
            ),
            // Table
            _ToolbarBtn(
              icon: Icons.table_chart_outlined,
              onTap: _showInsertTableDialog,
              tooltip: 'Insert table',
            ),
            // Math / π
            _ToolbarBtn(
              icon: Icons.functions_outlined,
              onTap: _showInsertMathDialog,
              tooltip: 'Insert formula',
            ),
          ],
        ),
      ),
    );
  }

  // ── Block builders ──────────────────────────────────────────────────────────

  Widget _buildBlock(int index, _Block block) {
    switch (block.type) {
      case _BlockType.header:
      case _BlockType.body:
        return _buildTextBlock(index, block);
      case _BlockType.image:
        return _buildImageBlock(index, block);
      case _BlockType.table:
        return _buildTableBlock(index, block);
      case _BlockType.math:
        return _buildMathBlock(index, block);
    }
  }

  Widget _buildTextBlock(int index, _Block block) {
    final isHeader = block.type == _BlockType.header;
    return Padding(
      padding: EdgeInsets.only(bottom: isHeader ? 6 : 2),
      child: widget.readOnly
          ? SelectableText(
              block.textController?.text ?? '',
              style: isHeader
                  ? const TextStyle(
                      fontFamily: AppTypography.headingFamily,
                      fontSize: AppTypography.displaySize,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    )
                  : const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: 16,
                      color: Color(0xFF293D31),
                      height: 1.65,
                    ),
            )
          : TextField(
              key: ValueKey('free-notes-body-$index'),
              controller: block.textController,
              focusNode: block.focusNode,
              minLines: isHeader ? 1 : 5,
              maxLines: isHeader ? 1 : null,
              textInputAction: isHeader
                  ? TextInputAction.newline
                  : TextInputAction.newline,
              onSubmitted: isHeader ? (_) => _splitLineAtCursor(block) : null,
              onChanged: (_) => setState(() => _hasChanges = true),
              style: isHeader
                  ? const TextStyle(
                      fontFamily: AppTypography.headingFamily,
                      fontSize: AppTypography.sectionTitleSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    )
                  : const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.bodySize,
                      color: Colors.black87,
                      height: 1.55,
                    ),
              decoration: InputDecoration(
                hintText:
                    index == 0 &&
                        _blocks.every(
                          (b) =>
                              (b.type == _BlockType.body ||
                                  b.type == _BlockType.header) &&
                              b.textController!.text.isEmpty,
                        )
                    ? 'Write something…'
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
    );
  }

  Widget _buildImageBlock(int index, _Block block) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _ImageBlockWidget(
        block: block,
        isSelected: !widget.readOnly && _focusedIndex == index,
        onSelect: widget.readOnly
            ? null
            : () => setState(() => _focusedIndex = index),
        onRemove: widget.readOnly ? null : () => _removeBlock(index),
        onMarkChanged: widget.readOnly ? null : () => _hasChanges = true,
      ),
    );
  }

  Widget _buildTableBlock(int index, _Block block) {
    final cells = block.cells!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: PageScrollWithFooter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: cells.asMap().entries.map((rowEntry) {
                    final r = rowEntry.key;
                    final row = rowEntry.value;
                    return Row(
                      children: row.asMap().entries.map((colEntry) {
                        final c = colEntry.key;
                        final isFirstRow = r == 0;
                        return Container(
                          width: 110,
                          decoration: BoxDecoration(
                            color: isFirstRow
                                ? AppColors.primary.withValues(alpha: 0.06)
                                : Colors.white,
                            border: Border(
                              right: c < row.length - 1
                                  ? BorderSide(color: Colors.grey.shade300)
                                  : BorderSide.none,
                              bottom: r < cells.length - 1
                                  ? BorderSide(color: Colors.grey.shade300)
                                  : BorderSide.none,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: widget.readOnly
                              ? Text(
                                  colEntry.value.text,
                                  style: AppTypography.body.copyWith(
                                    fontSize: 16,
                                    fontWeight: isFirstRow
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                )
                              : TextField(
                                  controller: colEntry.value,
                                  readOnly: widget.readOnly,
                                  style: TextStyle(
                                    fontFamily: AppTypography.bodyFamily,
                                    fontSize: AppTypography.bodySize,
                                    fontWeight: isFirstRow
                                        ? FontWeight.w500
                                        : FontWeight.w400,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: widget.readOnly
                                      ? null
                                      : (_) => _hasChanges = true,
                                ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          if (!widget.readOnly)
            Positioned(
              top: 4,
              right: 4,
              child: AppTapTarget(
                onTap: () => _removeBlock(index),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMathBlock(int index, _Block block) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          AppTapTarget(
            onTap: widget.readOnly
                ? null
                : () async {
                    final newLatex = await showAppDialog<String>(
                      context: context,
                      builder: (_) =>
                          _MathInputDialog(initialLatex: block.latex),
                    );
                    if (newLatex != null && mounted) {
                      setState(() {
                        block.latex = newLatex;
                        _hasChanges = true;
                      });
                    }
                  },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Center(
                child: Math.tex(
                  block.latex ?? '',
                  textStyle: const TextStyle(
                    fontFamily: AppTypography.headingFamily,
                    fontSize: AppTypography.sectionTitleSize,
                    color: Colors.black87,
                  ),
                  onErrorFallback: (err) => Text(
                    block.latex ?? '',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!widget.readOnly)
            Positioned(
              top: 4,
              right: 4,
              child: AppTapTarget(
                onTap: () => _removeBlock(index),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Image block with cursor-following resize handle ───────────────────────────

class _ImageBlockWidget extends StatefulWidget {
  const _ImageBlockWidget({
    required this.block,
    required this.isSelected,
    required this.onSelect,
    required this.onRemove,
    required this.onMarkChanged,
  });

  final _Block block;
  final bool isSelected;
  final VoidCallback? onSelect;
  final VoidCallback? onRemove;
  final VoidCallback? onMarkChanged;

  @override
  State<_ImageBlockWidget> createState() => _ImageBlockWidgetState();
}

class _ImageBlockWidgetState extends State<_ImageBlockWidget> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final imgW = (maxW * widget.block.widthFraction).clamp(
          maxW * 0.25,
          maxW,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTapTarget(
              onTap: widget.onSelect,
              child: ImageResizeFrame(
                width: imgW,
                maxWidth: maxW,
                selected: widget.isSelected,
                onResize: widget.onMarkChanged == null
                    ? null
                    : (fraction) {
                        setState(() => widget.block.widthFraction = fraction);
                        widget.onMarkChanged?.call();
                      },
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ProtectedImage.network(
                        widget.block.imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(
                          height: 160,
                          child: Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Container(
                                  color: Colors.grey.shade100,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    if (widget.onRemove != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: AppTapTarget(
                          onTap: widget.onRemove,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            SizedBox(
              width: imgW,
              child: widget.onMarkChanged == null
                  ? Text(
                      widget.block.captionController?.text ?? '',
                      textAlign: TextAlign.center,
                      style: AppTypography.helper,
                    )
                  : TextField(
                      controller: widget.block.captionController,
                      readOnly: widget.onMarkChanged == null,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        fontSize: AppTypography.bodySize,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: '',
                        hintStyle: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: Colors.grey.shade400,
                          fontSize: AppTypography.helperSize,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Toolbar button ────────────────────────────────────────────────────────────

class _ToolbarBtn extends StatelessWidget {
  const _ToolbarBtn({
    this.icon,
    this.child,
    this.onTap,
    this.active = false,
    this.tooltip,
  });

  final IconData? icon;
  final Widget? child;
  final VoidCallback? onTap;
  final bool active;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? Colors.black26 : AppColors.primary;

    Widget inner = child ?? Icon(icon, size: 24, color: color);

    Widget content = active
        ? Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: inner),
          )
        : SizedBox(width: 44, height: 44, child: Center(child: inner));

    if (tooltip != null) {
      content = Tooltip(message: tooltip!, child: content);
    }

    if (onTap == null) return content;

    return AppTapTarget(onTap: onTap, child: content);
  }
}

// ── TT icon — mimics the typography toggle in the reference ──────────────────

class _TtIcon extends StatelessWidget {
  const _TtIcon({required this.active, required this.enabled});

  final bool active;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.primary;
    final inactiveColor = enabled ? AppColors.primary : Colors.black26;

    // Big "T" on the left, small "T" on the right, baseline-aligned
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'T',
          style: TextStyle(
            fontSize: active ? 22 : 18,
            fontWeight: FontWeight.w500,
            color: active ? activeColor : inactiveColor,
            height: 1,
          ),
        ),
        Text(
          'T',
          style: TextStyle(
            fontSize: active ? 13 : 11,
            fontWeight: FontWeight.w500,
            color: active ? activeColor : inactiveColor,
            height: 1,
          ),
        ),
      ],
    );
  }
}

// ── Table size dialog ─────────────────────────────────────────────────────────

class _TableSizeDialog extends StatefulWidget {
  const _TableSizeDialog();

  @override
  State<_TableSizeDialog> createState() => _TableSizeDialogState();
}

class _TableSizeDialogState extends State<_TableSizeDialog> {
  int _rows = 3;
  int _cols = 3;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Insert Table'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _counter('Rows', _rows, (v) => setState(() => _rows = v), 2, 8),
          const SizedBox(height: 16),
          _counter('Columns', _cols, (v) => setState(() => _cols = v), 2, 6),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (rows: _rows, cols: _cols)),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Insert'),
        ),
      ],
    );
  }

  Widget _counter(
    String label,
    int value,
    ValueChanged<int> onChanged,
    int min,
    int max,
  ) {
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label)),
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.bodySize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

// ── Math input dialog ─────────────────────────────────────────────────────────

class _MathInputDialog extends StatefulWidget {
  const _MathInputDialog({this.initialLatex});

  final String? initialLatex;

  @override
  State<_MathInputDialog> createState() => _MathInputDialogState();
}

class _MathInputDialogState extends State<_MathInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialLatex ?? '');
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latex = _controller.text;
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Insert Formula'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '',
              labelText: 'LaTeX',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
            ),
          ),
          if (latex.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Preview',
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.helperSize,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Math.tex(
                  latex,
                  textStyle: const TextStyle(
                    fontFamily: AppTypography.headingFamily,
                    fontSize: AppTypography.pageTitleSize,
                  ),
                  onErrorFallback: (err) => Text(
                    'Invalid formula',
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: AppColors.error,
                      fontSize: AppTypography.bodySize,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: latex.isNotEmpty
              ? () => Navigator.pop(context, latex)
              : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Insert'),
        ),
      ],
    );
  }
}

// ── _Block model ──────────────────────────────────────────────────────────────

enum _BlockType { header, body, image, table, math }

class _Block {
  String id = journalEditorSessionId();
  _BlockType type;

  // text / header
  TextEditingController? textController;
  FocusNode? focusNode;

  // image
  String? imageUrl;
  TextEditingController? captionController;
  double widthFraction = 1.0; // 0.25 – 1.0

  // table
  List<List<TextEditingController>>? cells;

  // math
  String? latex;

  _Block({required this.type});

  factory _Block.header(String text) {
    final b = _Block(type: _BlockType.header);
    b.textController = TextEditingController(text: text);
    b.focusNode = FocusNode();
    return b;
  }

  factory _Block.body(String text) {
    final b = _Block(type: _BlockType.body);
    b.textController = TextEditingController(text: text);
    b.focusNode = FocusNode();
    return b;
  }

  factory _Block.image({required String url, String caption = ''}) {
    final b = _Block(type: _BlockType.image);
    b.imageUrl = url;
    b.captionController = TextEditingController(text: caption);
    return b;
  }

  factory _Block.table({required int rows, required int cols}) {
    final b = _Block(type: _BlockType.table);
    b.cells = List.generate(
      rows,
      (_) => List.generate(cols, (_) => TextEditingController()),
    );
    return b;
  }

  factory _Block.math(String latexStr) {
    final b = _Block(type: _BlockType.math);
    b.latex = latexStr;
    return b;
  }

  void dispose() {
    textController?.dispose();
    focusNode?.dispose();
    captionController?.dispose();
    cells?.forEach((row) => row.forEach((c) => c.dispose()));
  }

  Map<String, dynamic> toJson() {
    switch (type) {
      case _BlockType.header:
        return {'type': 'header', 'text': textController?.text ?? ''};
      case _BlockType.body:
        return {'type': 'body', 'text': textController?.text ?? ''};
      case _BlockType.image:
        return {
          'type': 'image',
          'url': imageUrl ?? '',
          'caption': captionController?.text ?? '',
          'widthFraction': widthFraction,
        };
      case _BlockType.table:
        return {
          'type': 'table',
          'rows':
              cells?.map((row) => row.map((c) => c.text).toList()).toList() ??
              [],
        };
      case _BlockType.math:
        return {'type': 'math', 'latex': latex ?? ''};
    }
  }

  static _Block fromJson(Map<String, dynamic> json) {
    switch (json['type'] as String?) {
      case 'header':
        return _Block.header((json['text'] as String?) ?? '');
      case 'image':
        final b = _Block.image(
          url: (json['url'] as String?) ?? '',
          caption: (json['caption'] as String?) ?? '',
        );
        b.widthFraction = (json['widthFraction'] as num?)?.toDouble() ?? 1.0;
        return b;
      case 'table':
        final rowsData = json['rows'] as List?;
        if (rowsData == null || rowsData.isEmpty) {
          return _Block.table(rows: 2, cols: 2);
        }
        final rows = rowsData.length;
        final cols = (rowsData.first as List?)?.length ?? 2;
        final b = _Block.table(rows: rows, cols: cols);
        for (int r = 0; r < rows; r++) {
          final rowData = rowsData[r] as List?;
          for (int c = 0; c < cols; c++) {
            b.cells![r][c].text = (rowData?[c] as String?) ?? '';
          }
        }
        return b;
      case 'math':
        return _Block.math((json['latex'] as String?) ?? '');
      default: // 'body' or unknown
        return _Block.body((json['text'] as String?) ?? '');
    }
  }
}
