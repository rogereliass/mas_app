import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  /// Get Supabase URL from environment
  static String get url {
    final envUrl = dotenv.env['SUPABASE_URL'];
    if (envUrl == null || envUrl.isEmpty) {
      throw Exception(
        'SUPABASE_URL not found in .env file!\n'
        'Please ensure .env file exists in project root with SUPABASE_URL',
      );
    }
    return envUrl;
  }
  
  /// Get Supabase anon key from environment
  static String get anonKey {
    final envKey = dotenv.env['SUPABASE_ANON_KEY'];
    if (envKey == null || envKey.isEmpty) {
      throw Exception(
        'SUPABASE_ANON_KEY not found in .env file!\n'
        'Please ensure .env file exists in project root with SUPABASE_ANON_KEY',
      );
    }
    return envKey;
  }
}
