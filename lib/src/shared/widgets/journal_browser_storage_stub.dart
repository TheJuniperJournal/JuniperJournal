import 'package:shared_preferences/shared_preferences.dart';

class JournalBrowserStorage {
  static Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);
  static Future<void> write(String key, String value) async {
    if (!await (await SharedPreferences.getInstance()).setString(key, value)) {
      throw StateError('Browser storage could not save journal edits');
    }
  }
}
