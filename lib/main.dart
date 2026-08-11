import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/start_screen.dart';
import 'services/notification_service.dart';
import 'state/project_store.dart';
import 'state/settings_store.dart';
import 'supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();

  // Projekt-Teilen ist optional: ohne ausgefüllte supabase_config.dart
  // bleibt die App vollständig lokal nutzbar, wie bisher.
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }
  runApp(const BaustellenApp());
}

class BaustellenApp extends StatelessWidget {
  const BaustellenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProjectStore()..init()),
        ChangeNotifierProvider(create: (_) => SettingsStore()..init()),
      ],
      child: MaterialApp(
        title: 'Erwin der Baustellen Helfer',
        theme: ThemeData(
          primarySwatch: Colors.grey,
        ),
        home: const StartScreen(),
      ),
    );
  }
}
