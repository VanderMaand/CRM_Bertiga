import 'package:flutter/material.dart';

import 'app.dart';
import 'core/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.initialize();

  // Firebase.initializeApp() akan ditambahkan di Modul 6 (Notification)

  runApp(const CoffeeStreetApp());
}
