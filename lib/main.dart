import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/start_screen.dart';
import 'services/error_log_service.dart';
import 'services/notification_service.dart';
import 'state/documentation_store.dart';
import 'state/project_store.dart';
import 'state/settings_store.dart';
import 'supabase_config.dart';

// Fängt sonst unsichtbare Abstürze/Fehler app-weit ein (sowohl im
// Flutter-Widget-Baum als auch außerhalb, z.B. in nicht abgefangenen
// Future-Fehlern) und protokolliert sie im ErrorLogService, statt sie
// stillschweigend zu verlieren – wichtig, weil beim Testen auf dem Handy
// auf der Baustelle niemand eine Dev-Konsole mitlaufen hat.
void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      ErrorLogService.instance
          .record(details.exceptionAsString(), details.stack.toString());
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      ErrorLogService.instance.record(error.toString(), stack.toString());
      return true;
    };

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
  }, (error, stack) {
    ErrorLogService.instance.record(error.toString(), stack.toString());
  });
}

class BaustellenApp extends StatelessWidget {
  const BaustellenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProjectStore()..init()),
        ChangeNotifierProvider(create: (_) => SettingsStore()..init()),
        ChangeNotifierProvider(create: (_) => DocumentationStore()..init()),
        ChangeNotifierProvider.value(value: ErrorLogService.instance),
      ],
      child: MaterialApp(
        title: 'Erwinator',
        theme: ThemeData(
          primarySwatch: Colors.grey,
        ),
        home: const StartScreen(),
      ),
    );
  }
}
