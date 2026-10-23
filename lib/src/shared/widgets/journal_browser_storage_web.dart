import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:shared_preferences/shared_preferences.dart';

/// Large journal snapshots belong in IndexedDB, not localStorage preferences.
class JournalBrowserStorage {
  static Future<web.IDBDatabase>? _opening;
  static Future<JSAny?> _request(web.IDBRequest request) {
    final result = Completer<JSAny?>();
    request.onsuccess = ((web.Event _) {
      result.complete(request.result);
    }).toJS;
    request.onerror = ((web.Event _) {
      result.completeError(
        StateError(request.error?.message ?? 'Browser storage failed'),
      );
    }).toJS;
    return result.future;
  }

  static Future<web.IDBDatabase> _database() => _opening ??= _open();
  static Future<web.IDBDatabase> _open() async {
    try {
      final request = web.window.indexedDB.open('juniper-journal-drafts', 1);
      request.onupgradeneeded = ((web.Event _) {
        (request.result as web.IDBDatabase).createObjectStore('drafts');
      }).toJS;
      return (await _request(request)) as web.IDBDatabase;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  static Future<String?> read(String key) async {
    try {
      final db = await _database();
      final tx = db.transaction('drafts'.toJS, 'readonly');
      final result = await _request(tx.objectStore('drafts').get(key.toJS));
      if (result != null && result.isA<JSString>())
        return (result as JSString).toDart;
    } catch (_) {}
    return (await SharedPreferences.getInstance()).getString(key);
  }

  static Future<void> write(String key, String value) async {
    try {
      final db = await _database();
      final tx = db.transaction('drafts'.toJS, 'readwrite');
      final completed = Completer<void>();
      tx.oncomplete = ((web.Event _) {
        completed.complete();
      }).toJS;
      tx.onabort = ((web.Event _) {
        completed.completeError(
          StateError('Journal storage transaction failed'),
        );
      }).toJS;
      tx.objectStore('drafts').put(value.toJS, key.toJS);
      await completed.future;
      return;
    } catch (_) {
      if (!await (await SharedPreferences.getInstance()).setString(
        key,
        value,
      )) {
        throw StateError('Browser storage could not save journal edits');
      }
    }
  }
}
