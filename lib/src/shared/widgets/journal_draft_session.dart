import 'restored_navigation.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'journal_navigation.dart';
import '../../features/project/services/journal_collaboration.dart';
import 'journal_collaboration_panel.dart';
import '../../features/project/pages/project_development_flow.dart'
    show prototypingRefreshType;
import '../../features/project/pages/journal_entry_editor.dart'
    show JournalEntryEditorScreen;
import 'page_refresh_state.dart';
import 'journal_browser_storage.dart';
import '../../features/project/services/project_activity.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../backend/db/models/journal_entry.dart';
import '../../backend/db/repositories/projects_repo.dart';
import '../../features/project/utils/journal_completion.dart';

/// Ignores generated scaffolding, navigation state and the automatic author.
bool journalHasUserInput(
  String title,
  List<dynamic> content, {
  String? authorId,
}) {
  bool meaningful(Object? value, [String? key]) {
    const metadata = {
      'stage',
      'id',
      'entryType',
      'type',
      'visitedStages',
      'currentStage',
      'created_at',
      'updated_at',
      'updatedAt',
      'submittedAt',
      'submitted',
      'complete',
      'formula',
      'scores',
      'materialsWorkflow',
      'analysisWorkflow',
      'testingWorkflow',
      'buildingWorkflow',
      'currency',
      'assessment_id',
      'alignment',
      'fontFamily',
      'fontSize',
      'bold',
      'italic',
      'underline',
      'headerRow',
      'cellFormatting',
      'widthFraction',
    };
    if (metadata.contains(key)) return false;
    if (value is Map) {
      if (value['stage'] == '_navigation') return false;
      return value.entries.any((e) => meaningful(e.value, e.key.toString()));
    }
    if (value is List) {
      return value.any((item) {
        if (key == 'involved' ||
            key == 'involvedIds' ||
            key == 'involved_ids') {
          final id = item is Map ? item['id'] ?? item['user_id'] : item;
          if (id == authorId) return false;
        }
        return meaningful(item);
      });
    }
    if (value is String) {
      final text = value.trim();
      return text.isNotEmpty &&
          text.toLowerCase() != 'none' &&
          !(key == 'title' && RegExp(r'^Entry \d+:').hasMatch(text));
    }
    return value is num || value == true;
  }

  return meaningful(title, 'title') || meaningful(content);
}

/// New work is recoverable on this device, but is not a project entry until kept.
class JournalDraftSession extends ChangeNotifier {
  JournalDraftSession(
    this.repo,
    this.projectId, {
    JournalEntry? initial,
    this.onKept,
  }) : current = initial,
       kept = initial != null && !initial.id.startsWith(prefix);
  static const prefix = 'recovery-';
  static String _user(ProjectsRepo repo) {
    try {
      return repo.currentUserId ?? 'local';
    } catch (_) {
      return 'local';
    }
  }

  static String _key(ProjectsRepo repo) => 'journal-recovery-v1-${_user(repo)}';
  final ValueChanged<String>? onKept;
  final ProjectsRepo repo;
  final String projectId;
  JournalEntry? current;
  JournalCollaboration? collaboration;
  bool kept;
  bool locallyProtected = false;
  String? lastSaveError;
  String get failureLabel =>
      collaboration?.error ??
      (locallyProtected && kept
          ? 'Saved on this device. Retrying sync…'
          : 'Could not save on this device. Please keep this page open.');
  Future<bool>? _keeping;
  String? _persistentId;
  String? _recoveryId;

  static Map<String, dynamic> _map(JournalEntry entry) => {
    'id': entry.id,
    'project_id': entry.projectId,
    'title': entry.title,
    'content': entry.content,
    'progress': entry.progress,
    'user_id': entry.authorId,
    'created_at': entry.createdAt?.toIso8601String(),
    'updated_at': entry.updatedAt?.toIso8601String(),
  };
  static Future<List<JournalEntry>> recoveries(
    ProjectsRepo repo,
    String projectId,
  ) async {
    final rows =
        jsonDecode(await JournalBrowserStorage.read(_key(repo)) ?? '{}') as Map;
    return rows.values
        .whereType<Map>()
        .map((row) => JournalEntry.fromMap(Map<String, dynamic>.from(row)))
        .where((e) => e.projectId == projectId)
        .toList();
  }

  static Future<void> removeRecovery(ProjectsRepo repo, String id) async {
    final rows = Map<String, dynamic>.from(
      jsonDecode(await JournalBrowserStorage.read(_key(repo)) ?? '{}') as Map,
    );
    rows.remove(id);
    await JournalBrowserStorage.write(_key(repo), jsonEncode(rows));
  }

  static Future<void> forgetEntry(ProjectsRepo repo, String id) async {
    try {
      final active = await JournalBrowserStorage.read(_activeKey(repo));
      if (active != null &&
          (jsonDecode(active) as Map)['entry'] is Map &&
          ((jsonDecode(active) as Map)['entry'] as Map)['id'] == id) {
        await JournalBrowserStorage.write(
          _activeKey(repo),
          jsonEncode({'closed': true}),
        );
      }
      await removeRecovery(repo, id);
    } catch (error) {
      debugPrint('Deleted entry snapshot cleanup: $error');
    }
  }

  static String _activeKey(ProjectsRepo repo) => '${_key(repo)}-active';

  /// A reload reopens the interrupted editor directly; no recovery list is shown.
  static Future<JournalEntry?> interruptedEntry(ProjectsRepo repo) async {
    final active = await JournalBrowserStorage.read(_activeKey(repo));
    if (active != null) {
      final record = jsonDecode(active) as Map;
      if (record['closed'] == true) return null;
      final raw = record['entry'];
      if (raw is Map)
        return JournalEntry.fromMap(Map<String, dynamic>.from(raw));
      return null;
    }
    // Preserve interrupted work created before automatic reopening was added.
    final rows =
        jsonDecode(await JournalBrowserStorage.read(_key(repo)) ?? '{}') as Map;
    final entries =
        rows.values
            .whereType<Map>()
            .map((row) => JournalEntry.fromMap(Map<String, dynamic>.from(row)))
            .where(
              (e) => journalHasUserInput(
                e.title,
                e.content,
                authorId: _user(repo),
              ),
            )
            .toList()
          ..sort(
            (a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(1970)).compareTo(
              a.updatedAt ?? a.createdAt ?? DateTime(1970),
            ),
          );
    return entries.isEmpty ? null : entries.first;
  }

  Future<void> _rememberEditor() async {
    if (current == null) return;
    await JournalBrowserStorage.write(
      _activeKey(repo),
      jsonEncode({'entry': _map(current!)}),
    );
    locallyProtected = true;
  }

  Future<void> finishEditing() async {
    await JournalBrowserStorage.write(
      _activeKey(repo),
      jsonEncode({'closed': true}),
    );
  }

  Future<void> _recover() async {
    final entry = current!;
    _recoveryId = entry.id;
    final rows = Map<String, dynamic>.from(
      jsonDecode(await JournalBrowserStorage.read(_key(repo)) ?? '{}') as Map,
    );
    rows[entry.id] = _map(entry);
    await _rememberEditor();
    await JournalBrowserStorage.write(_key(repo), jsonEncode(rows));
  }

  Future<bool> skipEmpty(String title, List<dynamic> content) async {
    if (kept || journalHasUserInput(title, content, authorId: _user(repo)))
      return false;
    await discard();
    return true;
  }

  Future<JournalEntry?> createJournalEntry({
    required String projectId,
    required String title,
    required List<dynamic> content,
    String? progress,
  }) async {
    final id = '$prefix${DateTime.now().microsecondsSinceEpoch}';
    current = JournalEntry(
      id: id,
      title: title,
      content: content,
      projectId: projectId,
      progress: progress,
      createdAt: DateTime.now(),
      authorId: _user(repo),
    );
    final ok = await _write();
    return ok ? current : null;
  }

  Future<bool> updateJournalEntry({
    required String entryId,
    String? title,
    List<dynamic>? content,
    String? progress,
  }) async {
    current = JournalEntry(
      id: current?.id ?? entryId,
      projectId: projectId,
      title: title ?? current?.title ?? '',
      content: content ?? current?.content ?? [],
      progress: progress ?? current?.progress,
      createdAt: current?.createdAt,
      authorId: current?.authorId ?? _user(repo),
      updatedAt: DateTime.now(),
    );
    return _write();
  }

  Future<bool> _write() async {
    lastSaveError = null;
    try {
      if (kept) {
        await _rememberEditor();
        final live = collaboration;
        if (live != null) {
          await live.save(
            journalDocument(current!),
            journalEntryIsComplete(current!),
          );
          return true;
        }
        final ok = await repo.updateJournalEntry(
          entryId: _persistentId ?? current!.id,
          title: current!.title,
          content: current!.content,
          progress: current!.progress,
        );
        if (!ok) lastSaveError = repo.lastJournalSaveError;
        return ok;
      }
      await _recover();
      notifyListeners();
      if (journalEntryIsComplete(current!)) return await keep();
      return true;
    } catch (error) {
      lastSaveError = error.toString();
      debugPrint('Journal local save failed: $error');
      notifyListeners();
      return false;
    }
  }

  Future<bool> keep() =>
      _keeping ??= _keep().whenComplete(() => _keeping = null);
  Future<bool> _keep() async {
    if (kept) return true;
    if (current == null) return false;
    final entry = current!;
    final saved = await repo.createJournalEntry(
      projectId: projectId,
      title: entry.title,
      content: entry.content,
      progress: entry.progress,
    );
    if (saved == null) return false;
    _persistentId = saved.id;
    current = saved;
    kept = true;
    onKept?.call(saved.id);
    try {
      await removeRecovery(repo, _recoveryId ?? entry.id);
      await _rememberEditor();
    } catch (error) {
      // The database save succeeded. A local cleanup failure must not report
      // that the entry failed or cause a second insert on retry.
      debugPrint('Journal saved; local snapshot cleanup deferred: $error');
    }
    notifyListeners();
    return true;
  }

  Future<void> discard() async {
    if (kept) return;
    if (current != null) await removeRecovery(repo, _recoveryId ?? current!.id);
    current = null;
    await finishEditing();
    notifyListeners();
  }
}

class JournalDraftScope extends InheritedWidget {
  const JournalDraftScope({
    super.key,
    required this.session,
    this.saveStatus,
    required this.save,
    required super.child,
  });
  final JournalDraftSession session;
  final ValueListenable<String>? saveStatus;
  final Future<bool> Function() save;
  static JournalDraftScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<JournalDraftScope>();
  @override
  bool updateShouldNotify(JournalDraftScope oldWidget) =>
      oldWidget.session != session;
}

class JournalDraftGuard extends StatefulWidget {
  const JournalDraftGuard({
    super.key,
    required this.session,
    this.saveStatus,
    required this.flush,
    required this.child,
    this.section,
    this.sections = const {},
    this.onSectionSelected,
    this.onRemoteEntry,
  });
  final String? section;
  final Map<String, String> sections;
  final ValueChanged<String>? onSectionSelected;
  final ValueChanged<JournalEntry>? onRemoteEntry;
  final JournalDraftSession session;
  final ValueListenable<String>? saveStatus;
  final Future<bool> Function() flush;
  final Widget child;
  static final _active = <ModalRoute<dynamic>, _JournalDraftGuardState>{};
  static Future<bool> leaveCurrent(NavigatorState navigator) async {
    for (final entry in _active.entries.toList()) {
      if (entry.key.isCurrent &&
          entry.value.mounted &&
          Navigator.of(entry.value.context) == navigator) {
        final state = entry.value;
        if (!await state._prepare()) return false;
        if (!state.mounted) return false;
        state._allowExit();
        await WidgetsBinding.instance.endOfFrame;
        if (navigator.mounted && navigator.canPop()) navigator.pop(true);
        await WidgetsBinding.instance.endOfFrame;
        return true;
      }
    }
    return true;
  }

  static bool isExternalNavigation(
    BuildContext context,
    NavigatorState navigator,
  ) => _active.entries.any(
    (e) =>
        e.key.isCurrent &&
        e.key != ModalRoute.of(context) &&
        e.value.mounted &&
        Navigator.of(e.value.context) == navigator,
  );
  static Future<void> allowPublished(BuildContext context) async {
    final state = _active[ModalRoute.of(context)];
    if (state != null && state.mounted) {
      await state.widget.session.finishEditing();
      state._allowExit();
    }
    await WidgetsBinding.instance.endOfFrame;
  }

  @override
  State<JournalDraftGuard> createState() => _JournalDraftGuardState();
}

class _JournalDraftGuardState extends State<JournalDraftGuard> {
  @override
  void initState() {
    super.initState();
    widget.session.addListener(_attachCollaboration);
    _attachCollaboration();
  }

  void _attachCollaboration() {
    final session = widget.session;
    if (session.collaboration != null ||
        !session.kept ||
        session.current == null ||
        !session.repo.journalCollaborationEnabled)
      return;
    session.collaboration = JournalCollaboration(
      session.repo,
      session.current!.id,
      session.current!,
    );
    if (mounted) setState(() {});
  }

  bool _allow = false, _asking = false;
  void _allowExit() {
    if (mounted) setState(() => _allow = true);
  }

  ModalRoute<dynamic>? _route;
  bool _restoredSection = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    if (_route != null) JournalDraftGuard._active[_route!] = this;
    if (!_restoredSection) {
      _restoredSection = true;
      final args = _route?.settings.arguments;
      final step = args is Map ? args['step'] : null;
      if (step is String && widget.sections.containsKey(step)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onSectionSelected?.call(step);
        });
      }
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_attachCollaboration);
    widget.session.collaboration?.dispose();
    widget.session.collaboration = null;
    if (JournalDraftGuard._active[_route] == this)
      JournalDraftGuard._active.remove(_route);
    super.dispose();
  }

  Future<bool> _save() async {
    if (!await widget.flush()) return false;
    if (widget.session.current == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add something before saving a draft.')),
        );
      return false;
    }
    final ok = await widget.session.keep();
    if (!ok && mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save draft. Your work is still here.'),
        ),
      );
    return ok;
  }

  Future<bool> _prepare() async {
    if (_asking) return false;
    _asking = true;
    if (widget.session.collaboration case final live? when !live.everEditable) {
      await widget.session.finishEditing();
      _asking = false;
      return true;
    }
    if (!await widget.flush() || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save your journal. Your work is still here. Please try again before leaving.',
            ),
          ),
        );
      }
      _asking = false;
      return false;
    }
    String? choice;
    if (!widget.session.kept && widget.session.current != null) {
      choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save this draft?'),
          content: const Text(
            'Keep this entry to continue later, or discard this new entry.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'edit'),
              child: const Text('Keep Editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('Save Draft & Exit'),
            ),
          ],
        ),
      );
      if (choice == 'save' && !await _save()) {
        _asking = false;
        return false;
      }
      if (choice == 'discard') await widget.session.discard();
      if (choice != 'save' && choice != 'discard') {
        _asking = false;
        return false;
      }
    }
    await widget.session.finishEditing();
    _asking = false;
    return mounted;
  }

  Future<void> _leave(Object? result) async {
    if (!await _prepare() || !mounted) return;
    setState(() => _allow = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) exitJournalRoute(context, result: result ?? true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final routePage = route is RestoredDetailRoute
        ? route.page
        : route is MaterialPageRoute
        ? route.builder(context)
        : null;
    final pageType =
        routePage?.runtimeType.toString().toLowerCase() ??
        route?.settings.name ??
        '';
    final phase =
        widget.session.current?.progress ??
        (routePage is JournalEntryEditorScreen
            ? routePage.initialProgress
            : null) ??
        (pageType.contains('discovery')
            ? 'discover'
            : pageType.contains('ideating')
            ? 'ideating'
            : pageType.contains('implementation')
            ? 'implementation'
            : 'prototyping');
    PageRefreshState.remember(context, {
      'kind': 'journal',
      if (widget.section != null) 'step': widget.section,
      'project': widget.session.projectId,
      'phase': phase,
      'entry': widget.session.current?.id,
      'prototypeType': routePage == null
          ? null
          : prototypingRefreshType(routePage),
      'freeNotes': routePage is JournalEntryEditorScreen && routePage.freeNotes,
    });
    return ProjectActivityScope(
      projectId: widget.session.projectId,
      repo: widget.session.repo,
      child: JournalDraftScope(
        session: widget.session,
        save: _save,
        saveStatus: widget.saveStatus,
        child: ListenableBuilder(
          listenable: widget.session,
          builder: (context, _) => PopScope(
            canPop: _allow,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) _leave(result);
            },
            child: widget.session.collaboration == null
                ? widget.child
                : JournalCollaborationPanel(
                    collaboration: widget.session.collaboration!,
                    flush: widget.flush,
                    section: widget.section,
                    sections: widget.sections,
                    onSectionSelected: widget.onSectionSelected,
                    onRemoteEntry: widget.onRemoteEntry,
                    child: widget.child,
                  ),
          ),
        ),
      ),
    );
  }
}
