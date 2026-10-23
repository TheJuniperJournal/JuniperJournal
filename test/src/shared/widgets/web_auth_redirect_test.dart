import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/auth/auth_redirect.dart';

void main() {
  test(
    'browser callback uses current origin without auth parameters or routes',
    () {
      expect(
        authRedirect(
          isWeb: true,
          base: Uri.parse('http://127.0.0.1:5174/#/login?code=secret'),
        ),
        'http://127.0.0.1:5174/',
      );
      expect(
        authRedirect(
          isWeb: true,
          base: Uri.parse('https://app.junejournal.org/?code=secret#/project'),
        ),
        'https://app.junejournal.org/',
      );
    },
  );
  test('native callback remains unchanged', () {
    expect(
      authRedirect(
        isWeb: false,
        base: Uri.parse('https://app.junejournal.org/'),
      ),
      'io.supabase.flutterquickstart://login-callback/',
    );
  });
}
