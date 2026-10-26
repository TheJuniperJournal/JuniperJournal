import '../../site/pages/site_information_page.dart';
import '../../../shared/widgets/evidence_cell_field.dart';
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
  final _canvasFocus = FocusNode(debugLabel: 'Free Notes canvas');
  (int, int)? _selectedCell;

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
                if (prev.textController == null) {
                  _selectElement(idx - 1);
                } else if (prev.focusNode != null &&
                    prev.textController != null) {
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
    _canvasFocus.dispose();
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
          existing.readFormatting(row);
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
    if (focused != null && newBlock.textController != null) {
      newBlock.readFormatting(focused.toJson());
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
    setState(() {
      final removed = _blocks.removeAt(index);
      // Controllers may still be attached until this frame has rebuilt.
      WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
      if (_blocks.isEmpty) {
        final blank = _Block.body('');
        _listenToBlock(blank);
        _blocks.add(blank);
      }
      _focusedIndex = index.clamp(0, _blocks.length - 1);
      _selectedCell = null;
      _hasChanges = true;
    });
  }

  void _selectElement(int index) {
    setState(() {
      _focusedIndex = index;
      _selectedCell = null;
    });
    _canvasFocus.requestFocus();
  }

  void _focusCanvasEnd() {
    final last = _blocks.last;
    if (last.textController != null) {
      last.focusNode!.requestFocus();
      last.textController!.selection = TextSelection.collapsed(
        offset: last.textController!.text.length,
      );
    } else {
      _focusedIndex = _blocks.length - 1;
      _insertAfterFocused(_Block.body(''));
    }
  }

  void _moveBlock(int index, int offset) {
    final target = index + offset;
    if (target < 0 || target >= _blocks.length) return;
    setState(() {
      final block = _blocks.removeAt(index);
      _blocks.insert(target, block);
      _focusedIndex = target;
      _selectedCell = null;
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

    final newBlock = _Block.body(after)..readFormatting(block.toJson());
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

            Expanded(
              child: Focus(
                focusNode: _canvasFocus,
                onKeyEvent: (_, event) {
                  if (event is KeyDownEvent &&
                      _canvasFocus.hasPrimaryFocus &&
                      (event.logicalKey == LogicalKeyboardKey.backspace ||
                          event.logicalKey == LogicalKeyboardKey.delete) &&
                      _focusedIndex != null &&
                      _blocks[_focusedIndex!].textController == null) {
                    _removeBlock(_focusedIndex!);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: CustomScrollView(
                  key: const ValueKey('free-notes-scroll'),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < _blocks.length; i++)
                              _buildBlock(i, _blocks[i]),
                            AppTapTarget(
                              key: const ValueKey('free-notes-write-area'),
                              onTap: _focusCanvasEnd,
                              behavior: HitTestBehavior.opaque,
                              child: const SizedBox(
                                height: 36,
                                width: double.infinity,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: AppTapTarget(
                              onTap: _focusCanvasEnd,
                              behavior: HitTestBehavior.opaque,
                              child: const ColoredBox(color: Colors.white),
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ValueListenableBuilder<
                                  List<JournalValidationIssue>
                                >(
                                  valueListenable: journalValidationIssues(
                                    context,
                                  ),
                                  builder: (_, issues, __) => Column(
                                    children: [
                                      for (final issue in issues)
                                        if (issue.isMissing())
                                          Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Text(
                                              issue.message,
                                              style: const TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                    ],
                                  ),
                                ),
                                if (_savedLabel != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      _savedLabel!,
                                      style: AppTypography.helper,
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: FilledButton(
                                    onPressed: _isSaving
                                        ? null
                                        : () => _saveAndPop(submit: true),
                                    child: Text(
                                      _isSaving ? 'Saving...' : 'Submit',
                                    ),
                                  ),
                                ),
                                if (context
                                        .dependOnInheritedWidgetOfExactType<
                                          SiteFooterScope
                                        >() !=
                                    null)
                                  SiteFooter(
                                    compact: true,
                                    onNavigate: (page) =>
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                SiteInformationPage(page: page),
                                          ),
                                        ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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

  Future<void> _editFormula(_Block block) async {
    final latex = await showAppDialog<String>(
      context: context,
      builder: (_) => _MathInputDialog(initialLatex: block.latex),
    );
    if (latex == null || !mounted) return;
    setState(() {
      block.latex = latex;
      _hasChanges = true;
    });
  }

  void _formatBlock(void Function(_Block) change, {bool formatCell = true}) {
    if (_focusedIndex == null || _focusedIndex! >= _blocks.length) return;
    setState(() {
      final block = _blocks[_focusedIndex!];
      if (formatCell && block.cells != null && _selectedCell != null) {
        final cell = block.cellAppearance(_selectedCell!.$1, _selectedCell!.$2);
        change(cell);
        block.cellFormatting['${_selectedCell!.$1}:${_selectedCell!.$2}'] =
            cell.formattingJson;
      } else {
        change(block);
      }
      _hasChanges = true;
    });
  }

  void _changeTable(String action) {
    _formatBlock((block) {
      final cells = block.cells!;
      if (action == 'row' && cells.length < 20) {
        cells.add(
          List.generate(cells.first.length, (_) => TextEditingController()),
        );
      } else if (action == 'column' && cells.first.length < 8) {
        for (final row in cells) {
          row.add(TextEditingController());
        }
      } else if (action == 'header') {
        block.headerRow = !block.headerRow;
      } else if (action == 'remove-row' && cells.length > 1) {
        if (cells.last.any((c) => c.text.isNotEmpty)) {
          showTopSnackBar(context, 'Clear the last row before removing it.');
          return;
        }
        for (final c in cells.removeLast()) {
          c.dispose();
        }
      } else if (action == 'remove-column' && cells.first.length > 1) {
        if (cells.any((row) => row.last.text.isNotEmpty)) {
          showTopSnackBar(context, 'Clear the last column before removing it.');
          return;
        }
        for (final row in cells) {
          row.removeLast().dispose();
        }
      }
    }, formatCell: false);
  }

  Widget _buildToolbar() {
    final focused = _focusedIndex != null && _focusedIndex! < _blocks.length
        ? _blocks[_focusedIndex!]
        : null;
    final isText =
        focused?.textController != null ||
        (focused?.cells != null && _selectedCell != null);
    final format = focused?.cells != null && _selectedCell != null
        ? focused!.cellAppearance(_selectedCell!.$1, _selectedCell!.$2)
        : focused;
    Widget divider() => Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: AppColors.divider,
    );
    Widget select<T>(
      String label,
      T value,
      List<T> choices,
      void Function(T) changed, {
      bool enabled = true,
      Map<T, String>? labels,
    }) => Tooltip(
      message: label,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          key: ValueKey('notes-$label'),
          value: value,
          isDense: true,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: Colors.black87,
          ),
          borderRadius: BorderRadius.circular(10),
          items: choices
              .map(
                (v) => DropdownMenuItem(
                  value: v,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(labels?[v] ?? '$v'),
                  ),
                ),
              )
              .toList(),
          onChanged: enabled
              ? (v) {
                  if (v != null) changed(v);
                }
              : null,
        ),
      ),
    );
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          key: const ValueKey('free-notes-toolbar-row'),
          mainAxisSize: MainAxisSize.min,
          children: [
            select<double>(
              'Font size',
              format?.fontSize ??
                  (focused?.type == _BlockType.header ? 24 : 16),
              {
                ...[
                  10.0,
                  12.0,
                  14.0,
                  16.0,
                  18.0,
                  20.0,
                  24.0,
                  28.0,
                  32.0,
                  36.0,
                  48.0,
                ],
                if (format?.fontSize != null) format!.fontSize!,
              }.toList()..sort(),
              (v) => _formatBlock((b) => b.fontSize = v),
              labels: {
                for (final v in [
                  10.0,
                  12.0,
                  14.0,
                  16.0,
                  18.0,
                  20.0,
                  24.0,
                  28.0,
                  32.0,
                  36.0,
                  48.0,
                ])
                  v: v.toInt().toString(),
              },
              enabled: isText || focused?.cells != null,
            ),
            _ToolbarBtn(
              icon: Icons.format_bold,
              tooltip: 'Bold',
              active: format?.bold ?? false,
              onTap: isText
                  ? () => _formatBlock((b) => b.bold = !b.bold)
                  : null,
            ),
            _ToolbarBtn(
              icon: Icons.format_italic,
              tooltip: 'Italic',
              active: format?.italic ?? false,
              onTap: isText
                  ? () => _formatBlock((b) => b.italic = !b.italic)
                  : null,
            ),
            _ToolbarBtn(
              icon: Icons.format_underlined,
              tooltip: 'Underline',
              active: format?.underline ?? false,
              onTap: isText
                  ? () => _formatBlock((b) => b.underline = !b.underline)
                  : null,
            ),
            divider(),
            for (final item in [
              ('left', Icons.format_align_left),
              ('center', Icons.format_align_center),
              ('right', Icons.format_align_right),
            ])
              _ToolbarBtn(
                icon: item.$2,
                tooltip: 'Align ${item.$1}',
                active: format?.alignment == item.$1,
                onTap: focused == null
                    ? null
                    : () => _formatBlock((b) => b.alignment = item.$1),
              ),
            divider(),
            _ToolbarBtn(
              icon: Icons.image_outlined,
              tooltip: 'Add image from gallery',
              onTap: () => _insertImage(ImageSource.gallery),
            ),
            _ToolbarBtn(
              icon: Icons.camera_alt_outlined,
              tooltip: 'Take photo',
              onTap: () => _insertImage(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  // ── Block builders ──────────────────────────────────────────────────────────

  Widget _buildBlock(int index, _Block block) {
    final child = _buildBlockContent(index, block);
    if (widget.readOnly) return child;
    final selected = _focusedIndex == index;
    final kind = switch (block.type) {
      _BlockType.image => 'image',
      _BlockType.table => 'table',
      _BlockType.math => 'formula',
      _ => 'text',
    };
    return Listener(
      onPointerDown: (_) {
        if (_focusedIndex != index)
          setState(() {
            _focusedIndex = index;
            _selectedCell = null;
          });
      },
      child: AppTapTarget(
        onTap: block.textController == null
            ? () => _selectElement(index)
            : null,
        showHoverHighlight: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (selected && block.textController == null)
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  if (block.cells != null) ...[
                    TextButton.icon(
                      onPressed: () => _changeTable('row'),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Row'),
                    ),
                    TextButton.icon(
                      onPressed: () => _changeTable('column'),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Column'),
                    ),
                  ],
                  if (block.type == _BlockType.math)
                    IconButton(
                      tooltip: 'Edit formula',
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _editFormula(block),
                    ),
                  if (index > 0)
                    IconButton(
                      tooltip: 'Move $kind up',
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      onPressed: () => _moveBlock(index, -1),
                    ),
                  if (index < _blocks.length - 1)
                    IconButton(
                      tooltip: 'Move $kind down',
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      onPressed: () => _moveBlock(index, 1),
                    ),
                  IconButton(
                    tooltip: 'Delete $kind',
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _removeBlock(index),
                  ),
                ],
              ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildBlockContent(int index, _Block block) {
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: widget.readOnly
          ? SelectableText(
              block.textController?.text ?? '',
              textAlign: block.textAlign,
              style: block.textStyle,
            )
          : TextField(
              key: ValueKey('free-notes-body-$index'),
              controller: block.textController,
              focusNode: block.focusNode,
              minLines: 1,
              maxLines: null,
              textAlign: block.textAlign,
              style: block.textStyle,
              textInputAction: TextInputAction.newline,
              onSubmitted: block.type == _BlockType.header
                  ? (_) => _splitLineAtCursor(block)
                  : null,
              onChanged: (_) => setState(() => _hasChanges = true),
              decoration: InputDecoration(
                hintText:
                    index == 0 &&
                        _blocks.every(
                          (b) => (b.textController?.text ?? '').isEmpty,
                        )
                    ? 'Write something…'
                    : null,
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
        onSelect: widget.readOnly ? null : () => _selectElement(index),
        onRemove: null,
        onMarkChanged: widget.readOnly ? null : () => _hasChanges = true,
      ),
    );
  }

  Widget _buildTableBlock(int index, _Block block) {
    final cells = block.cells!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Table(
        key: ValueKey('notes-table-$index'),
        defaultColumnWidth: const FlexColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        border: TableBorder.all(color: const Color(0xFFCCD5CE)),
        children: [
          for (var r = 0; r < cells.length; r++)
            TableRow(
              children: [
                for (var c = 0; c < cells[r].length; c++)
                  ClipRect(
                    child: widget.readOnly
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              cells[r][c].text,
                              textAlign: block.cellAppearance(r, c).textAlign,
                              style: block.cellAppearance(r, c).textStyle,
                            ),
                          )
                        : EvidenceCellField(
                            key: ValueKey('notes-cell-$index-$r-$c'),
                            controller: cells[r][c],
                            style: block.cellAppearance(r, c).textStyle,
                            textAlign: block.cellAppearance(r, c).textAlign,
                            onTap: () => setState(() {
                              _focusedIndex = index;
                              _selectedCell = (r, c);
                            }),
                            onChanged: (_) => setState(() {
                              _focusedIndex = index;
                              _selectedCell = (r, c);
                              _hasChanges = true;
                            }),
                          ),
                  ),
              ],
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
            onTap: widget.readOnly ? null : () => _selectElement(index),
            onDoubleTap: widget.readOnly ? null : () => _editFormula(block),
            child: Container(
              key: ValueKey('notes-formula-$index'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: !widget.readOnly && _focusedIndex == index
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Align(
                alignment: block.elementAlignment,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
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

        return SizedBox(
          width: maxW,
          child: Column(
            crossAxisAlignment: switch (widget.block.alignment) {
              'center' => CrossAxisAlignment.center,
              'right' => CrossAxisAlignment.end,
              _ => CrossAxisAlignment.start,
            },
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
                          loadingBuilder: (_, child, progress) =>
                              progress == null
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
          ),
        );
      },
    );
  }
}

// ── Toolbar button ────────────────────────────────────────────────────────────

class _ToolbarBtn extends StatelessWidget {
  const _ToolbarBtn({this.icon, this.onTap, this.active = false, this.tooltip});

  final IconData? icon;
  final VoidCallback? onTap;
  final bool active;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? Colors.black26
        : active
        ? AppColors.primary
        : Colors.black54;

    Widget inner = Icon(icon, size: 24, color: color);

    Widget content = SizedBox(
      width: 40,
      height: 40,
      child: Center(child: inner),
    );

    if (tooltip != null) {
      content = Tooltip(message: tooltip!, child: content);
    }

    if (onTap == null) return content;

    return AppTapTarget(onTap: onTap, child: content);
  }
}

// ── Formula creator and editor ───────────────────────────────────────────────
class _MathInputDialog extends StatefulWidget {
  const _MathInputDialog({this.initialLatex});
  final String? initialLatex;
  @override
  State<_MathInputDialog> createState() => _MathInputDialogState();
}

class _MathInputDialogState extends State<_MathInputDialog> {
  late final _controller = TextEditingController(
    text: widget.initialLatex ?? '',
  )..addListener(_refresh);
  void _refresh() {
    if (mounted) setState(() {});
  }

  void _insert(String snippet) {
    final value = _controller.value;
    final start = value.selection.isValid
        ? value.selection.start
        : value.text.length;
    final end = value.selection.isValid ? value.selection.end : start;
    _controller.value = TextEditingValue(
      text: value.text.replaceRange(start, end, snippet),
      selection: TextSelection.collapsed(offset: start + snippet.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latex = _controller.text.trim();
    final formula = Math.tex(
      latex,
      textStyle: const TextStyle(fontSize: 22),
      onErrorFallback: (_) => const Text(
        'Check the formula syntax.',
        style: TextStyle(color: Colors.red),
      ),
    );
    final valid = latex.isNotEmpty && formula.parseError == null;
    return AlertDialog(
      title: Text(
        widget.initialLatex == null ? 'Insert Formula' : 'Edit Formula',
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Start with a template or type a formula using LaTeX.',
                style: AppTypography.helper,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final template in [
                    ('Fraction', r'\frac{a}{b}'),
                    ('Power', r'x^{2}'),
                    ('Square root', r'\sqrt{x}'),
                    ('Sum', r'\sum_{i=1}^{n} x_i'),
                    ('Percent', r'\times 100\%'),
                    ('Subscript', r'x_{1}'),
                  ])
                    ActionChip(
                      label: Text(template.$1),
                      onPressed: () => _insert(template.$2),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('notes-formula-input'),
                controller: _controller,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
                decoration: const InputDecoration(
                  labelText: 'Formula (LaTeX)',
                  hintText: r'E = mc^{2}',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Preview', style: AppTypography.helper),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F7F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: latex.isEmpty
                      ? const Text(
                          'Your formula will appear here',
                          style: AppTypography.helper,
                        )
                      : formula,
                ),
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
          onPressed: valid ? () => Navigator.pop(context, latex) : null,
          child: Text(widget.initialLatex == null ? 'Insert' : 'Save'),
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

  String alignment = 'left';
  String? fontFamily;
  double? fontSize;
  bool bold = false, italic = false, underline = false;
  bool headerRow = false;
  Map<String, Map<String, dynamic>> cellFormatting = {};
  Map<String, dynamic> get formattingJson => {
    'alignment': alignment,
    if (fontSize != null) 'fontSize': fontSize,
    if (fontFamily != null) 'fontFamily': fontFamily,
    'bold': bold,
    'italic': italic,
    'underline': underline,
  };
  _Block cellAppearance(int row, int col) =>
      _Block(type: _BlockType.body)
        ..readFormatting({...formattingJson, ...?cellFormatting['$row:$col']});
  TextAlign get textAlign => switch (alignment) {
    'center' => TextAlign.center,
    'right' => TextAlign.right,
    _ => TextAlign.left,
  };
  Alignment get elementAlignment => switch (alignment) {
    'center' => Alignment.topCenter,
    'right' => Alignment.topRight,
    _ => Alignment.topLeft,
  };
  TextStyle get textStyle => TextStyle(
    fontFamily:
        fontFamily ??
        (type == _BlockType.header
            ? AppTypography.headingFamily
            : AppTypography.bodyFamily),
    fontSize: fontSize ?? (type == _BlockType.header ? 24 : 16),
    fontWeight: bold || type == _BlockType.header
        ? FontWeight.w600
        : FontWeight.w400,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    decoration: underline ? TextDecoration.underline : TextDecoration.none,
    color: const Color(0xFF293D31),
    height: 1.6,
  );
  void readFormatting(Map json) {
    alignment = ['left', 'center', 'right'].contains(json['alignment'])
        ? json['alignment'] as String
        : 'left';
    fontFamily = ['Inter', 'Manrope'].contains(json['fontFamily'])
        ? json['fontFamily'] as String
        : null;
    fontSize = json['fontSize'] is num
        ? (json['fontSize'] as num).toDouble().clamp(10, 48)
        : null;
    bold = json['bold'] == true;
    italic = json['italic'] == true;
    underline = json['underline'] == true;
    headerRow = json['headerRow'] == true;
    if (json['cellFormatting'] is Map)
      cellFormatting = {
        for (final entry in (json['cellFormatting'] as Map).entries)
          if (entry.value is Map)
            entry.key.toString(): Map<String, dynamic>.from(entry.value as Map),
      };
  }

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

  Map<String, dynamic> toJson() => {
    ..._contentJson(),
    'alignment': alignment,
    if (fontFamily != null) 'fontFamily': fontFamily,
    if (fontSize != null) 'fontSize': fontSize,
    'bold': bold,
    'italic': italic,
    'underline': underline,
    if (type == _BlockType.table) 'cellFormatting': cellFormatting,
  };
  Map<String, dynamic> _contentJson() {
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

  static _Block fromJson(Map<String, dynamic> json) =>
      _fromContentJson(json)..readFormatting(json);
  static _Block _fromContentJson(Map<String, dynamic> json) {
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
