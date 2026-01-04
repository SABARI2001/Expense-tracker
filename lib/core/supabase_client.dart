import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const supabaseUrl = 'https://cwxlyvdabeuwtkgnklxt.supabase.co';
  static const anonKey = 'sb_publishable_yuLjS36JI032i8A1H3rehg_ACE-DqLA'; // safe in client
}

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.anonKey,
  );
}
