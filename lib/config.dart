import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  static String get supabaseUrl {
    return dotenv.get('SUPABASE_URL');
  }

  static String get supabaseAnonKey {
    return dotenv.get('SUPABASE_ANON_KEY');
  }
}