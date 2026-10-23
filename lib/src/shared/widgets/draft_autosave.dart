import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

/// Polls the complete draft so text, selection and evidence changes all persist.
mixin DraftAutosave<T extends StatefulWidget> on State<T> {
  Timer? _draftTimer;
  Future<bool>? _activeWrite;
  String? _savedFingerprint;
  final draftSaveStatus = ValueNotifier<String>('');
  String get draftFingerprint;
  String get savedDraftLabel => 'Saved';
  String get failedDraftLabel => 'Could not save. Retrying…';

  String get _contentFingerprint {
    try {
      Object? stable(Object? value) {
        if (value is Map) {
          return {
            for (final entry in value.entries)
              if (entry.key != 'updated_at' &&
                  entry.key != 'submittedAt' &&
                  entry.key != 'visitedStages')
                entry.key:
                    entry.key == 'title' &&
                        entry.value is String &&
                        RegExp(r'^Entry \d+:').hasMatch(entry.value as String)
                    ? ''
                    : stable(entry.value),
          };
        }
        if (value is List) return value.map(stable).toList();
        return value;
      }

      return jsonEncode(stable(jsonDecode(draftFingerprint)));
    } on FormatException {
      return draftFingerprint;
    }
  }

  Future<bool> writeAutosave();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _savedFingerprint = _contentFingerprint;
      _draftTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
        if (mounted &&
            _activeWrite == null &&
            _contentFingerprint != _savedFingerprint) {
          unawaited(flushDraft());
        }
      });
    });
  }

  Future<bool> serializeDraft(Future<bool> Function() write) async {
    while (_activeWrite != null) {
      await _activeWrite;
    }
    if (!mounted) return false;
    final fingerprint = _contentFingerprint;
    draftSaveStatus.value = 'Saving...';
    final pending = Future<bool>.sync(write).catchError((Object error) {
      debugPrint('Draft write failed: $error');
      return false;
    });
    _activeWrite = pending;
    try {
      final ok = await pending;
      if (ok) _savedFingerprint = fingerprint;
      if (mounted) {
        draftSaveStatus.value = ok ? savedDraftLabel : failedDraftLabel;
      }
      return ok;
    } finally {
      _activeWrite = null;
    }
  }

  Future<bool> flushDraft() async {
    while (_activeWrite != null) {
      await _activeWrite;
    }
    if (!mounted || _contentFingerprint == _savedFingerprint) return true;
    return serializeDraft(writeAutosave);
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    draftSaveStatus.dispose();
    super.dispose();
  }
}
