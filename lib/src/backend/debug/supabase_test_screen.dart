import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/*
  Tests supabase connection:
    Manually insert row in supabase
    Check screen
    Should return # rows fetched and "Connected!"
 */

class SupabaseTestScreen extends StatelessWidget {
  const SupabaseTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return Scaffold(
      appBar: AppBar(title: const Text('Supabase Connection Test')),
      body: Center(
        child: FutureBuilder(
          future: supabase.from('test').select(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else {
              final data = snapshot.data ?? [];
              return Text(
                'Connected!\nRows fetched: ${data.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTypography.headingFamily,
                  fontSize: AppTypography.sectionTitleSize,
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
