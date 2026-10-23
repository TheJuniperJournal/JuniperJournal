import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/web_navigation_host.dart';

void main() {
  testWidgets('opening a shared URL keeps the bootstrap page mounted once', (
    tester,
  ) async {
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: WebNavigationHost(
          initialLocation: '/explore',
          navigatorKey: GlobalKey<NavigatorState>(),
          initialPage: _StartupProbe(onStart: () => starts++),
          observers: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Resolved destination'), findsOneWidget);
    expect(starts, 1);
  });
}

class _StartupProbe extends StatefulWidget {
  const _StartupProbe({required this.onStart});
  final VoidCallback onStart;
  @override
  State<_StartupProbe> createState() => _StartupProbeState();
}

class _StartupProbeState extends State<_StartupProbe> {
  @override
  void initState() {
    super.initState();
    widget.onStart();
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('Resolved destination'));
}
