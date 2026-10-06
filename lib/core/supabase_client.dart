import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Inisialisasi Supabase. Panggil [initialize] sekali di main() sebelum runApp.
class SupabaseService {
  SupabaseService._();

  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');

    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || anonKey == null || url.contains('xxxxx')) {
      throw Exception(
        'SUPABASE_URL / SUPABASE_ANON_KEY belum diisi di file .env. '
        'Salin .env.example menjadi .env lalu isi dengan credentials project Supabase Anda.',
      );
    }

    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
