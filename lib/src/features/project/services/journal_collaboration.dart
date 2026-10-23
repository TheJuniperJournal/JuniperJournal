import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../backend/db/models/journal_entry.dart';
import '../../../backend/db/repositories/projects_repo.dart';

Map<String, dynamic> _snapshot(Map<String, dynamic> document) =>
    jsonDecode(jsonEncode(document)) as Map<String, dynamic>;

/// One browser editor, not one account: two tabs never share a lease token.
String journalEditorSessionId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

Map<String, dynamic> journalDocument(JournalEntry entry) => {
  'title': entry.title,
  'content': entry.content,
  'progress': entry.progress,
};

class JournalCollaborator {
  JournalCollaborator.fromMap(Map row)
    : sessionId = row['session_id'].toString(),
      userId = row['user_id'].toString(),
      name = row['name']?.toString() ?? 'Collaborator',
      avatar = row['avatar_url']?.toString(),
      section = row['section']?.toString() ?? '',
      editing = row['editing'] == true;
  final String sessionId, userId, name, section;
  final String? avatar;
  final bool editing;
}

/// Server-authorized presence and expiring section leases. Polling is deliberate:
/// correctness comes from transactional RPCs, not delivery of broadcast events.
class JournalCollaboration extends ChangeNotifier {
  JournalCollaboration(this.repo, this.entryId, JournalEntry initial)
    : base = _snapshot(journalDocument(initial)),
      localBase = _snapshot(journalDocument(initial));
  final ProjectsRepo repo;
  final String entryId;
  final String sessionId = journalEditorSessionId();
  Map<String, dynamic> base;
  // The snapshot last produced by this editor. Remote fields must not turn into
  // apparent local edits when the editor has not hydrated them yet.
  Map<String, dynamic> localBase;
  JournalEntry? latest;
  List<JournalCollaborator> people = [];
  String section = '';
  bool connected = false, ownsSection = false, disposed = false;
  bool everEditable = false;
  Map<String, dynamic>? conflictingLocal;
  String? error;
  DateTime? _confirmedAt;
  Timer? _timer;
  Future<void>? _polling;
  Future<Map<String, dynamic>>? _saving;
  bool get canEdit =>
      connected &&
      (_confirmedAt != null &&
          DateTime.now().difference(_confirmedAt!) <
              const Duration(seconds: 12)) &&
      (section == 'free_notes' || ownsSection);
  JournalCollaborator? get owner {
    for (final person in people) {
      if (person.section == section &&
          person.editing &&
          person.sessionId != sessionId)
        return person;
    }
    return null;
  }

  Future<void> start(String activeSection) async {
    section = activeSection;
    _timer ??= Timer.periodic(const Duration(seconds: 3), (_) => poll());
    await poll();
  }

  Future<void> changeSection(String value) async {
    if (section == value) return;
    section = value;
    ownsSection = false;
    connected = false;
    notifyListeners();
    await poll();
  }

  Future<void> poll() =>
      _polling ??= _poll().whenComplete(() => _polling = null);
  Future<void> _poll() async {
    final requestedSection = section;
    try {
      final data = await repo.journalCollaborationHeartbeat(
        entryId,
        sessionId,
        requestedSection,
      );
      if (disposed) return;
      latest = JournalEntry.fromMap(
        Map<String, dynamic>.from(data['entry'] as Map),
      );
      people = (data['people'] as List)
          .whereType<Map>()
          .map(JournalCollaborator.fromMap)
          .toList();
      connected = requestedSection == section;
      ownsSection = data['owns_section'] == true && connected;
      _confirmedAt = DateTime.now();
      everEditable = everEditable || canEdit;
      if (conflictingLocal == null) error = null;
    } catch (_) {
      if (disposed) return;
      connected = false;
      ownsSection = false;
      error =
          'Collaboration is unavailable. Your changes stay on this device. Retry to reconnect.';
    }
    if (!disposed) notifyListeners();
    if (!disposed && requestedSection != section) scheduleMicrotask(poll);
  }

  Future<Map<String, dynamic>> save(
    Map<String, dynamic> desired,
    bool complete,
  ) {
    final submitted = _snapshot(desired);
    final previous = _saving;
    final next = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {}
      }
      return _save(submitted, complete);
    }();
    _saving = next;
    return next.whenComplete(() {
      if (identical(_saving, next)) _saving = null;
    });
  }

  Future<Map<String, dynamic>> _save(
    Map<String, dynamic> desired,
    bool complete,
  ) async {
    if (disposed || !canEdit)
      throw StateError(
        'Reconnect or choose an available section before saving.',
      );
    // Submit the previous local snapshot rather than an unseen remote snapshot.
    final submitted = _snapshot(desired);
    late JournalEntry result;
    try {
      result = await repo.saveCollaborativeJournal(
        entryId,
        sessionId,
        _snapshot(localBase),
        submitted,
        complete,
      );
    } catch (failure) {
      conflictingLocal = _snapshot(submitted);
      error =
          'Could not merge your changes. Your local work is preserved. Review it before loading the saved version.';
      if (!disposed) notifyListeners();
      rethrow;
    }
    conflictingLocal = null;
    localBase = _snapshot(submitted);
    base = journalDocument(result);
    latest = result;
    error = null;
    if (!disposed) notifyListeners();
    return base;
  }

  void hydrated(JournalEntry entry) {
    base = journalDocument(entry);
    localBase = _snapshot(base);
  }

  @override
  void dispose() {
    disposed = true;
    _timer?.cancel();
    unawaited(
      repo.releaseJournalCollaboration(entryId, sessionId).catchError((_) {}),
    );
    super.dispose();
  }
}
