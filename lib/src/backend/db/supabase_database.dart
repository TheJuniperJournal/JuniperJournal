import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDatabase {
  SupabaseDatabase._();
  static final SupabaseDatabase instance = SupabaseDatabase._();

  late final SupabaseClient client;
  bool _initialized = false;

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  Future<void> init() async {
    if (_initialized) return;
    if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
      throw Exception(
        'Missing SUPABASE_URL or SUPABASE_KEY. '
        'Did you forget --dart-define when building?',
      );
    }

    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

    client = Supabase.instance.client;
    _initialized = true;
  }
}
