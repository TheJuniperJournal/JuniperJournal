import 'package:juniper_journal/src/shared/widgets/desktop_modal_layer.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:juniper_journal/src/backend/db/supabase_database.dart';
import 'package:juniper_journal/src/features/site/pages/site_information_page.dart';
import 'package:juniper_journal/src/shared/widgets/persistent_desktop_shell.dart';
import 'package:juniper_journal/src/shared/widgets/adaptive_app_shell.dart';

void main() {
  testWidgets('signed in About keeps workspace navigation and footer links', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient(
        (request) async => http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    SupabaseDatabase.instance.client = client;
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'exp':
                  DateTime.now()
                      .add(const Duration(days: 1))
                      .millisecondsSinceEpoch ~/
                  1000,
            }),
          ),
        )
        .replaceAll('=', '');
    await client.auth.recoverSession(
      jsonEncode({
        'access_token': 'e30.$payload.test',
        'refresh_token': 'test',
        'token_type': 'bearer',
        'expires_in': 86400,
        'user': {
          'id': 'test-user',
          'aud': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [desktopRouteObserver],
        builder: (_, child) =>
            DesktopModalLayer(child: PersistentDesktopShell(child: child!)),
        home: const SiteInformationPage(page: 'about'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Journal Library'), findsOneWidget);
    expect(find.byType(AdaptiveAppShell), findsWidgets);
    await tester.drag(find.byType(ListView).first, const Offset(0, -16000));
    await tester.pumpAndSettle();
    expect(find.byType(SiteFooter), findsOneWidget);
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Safety'), findsOneWidget);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      isNull,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    client.auth.dispose();
  });
}
