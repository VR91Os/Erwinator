import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
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

    // Für die Monats-/Wochentagsnamen im Kalender (Zeitstatistik, Überblick)
    // - ohne das rendert table_calendar auf Englisch, weil die App (bewusst
    // sonst rein hartcodiertes Deutsch, kein MaterialApp-Locale-Setup) sich
    // sonst auf die Flutter-Standardlokalisierung ("en") verlässt.
    await initializeDateFormatting('de_DE');
    Intl.defaultLocale = 'de_DE';

    await NotificationService.instance.init();

    // Projekt-Teilen ist optional: ohne ausgefüllte supabase_config.dart
    // bleibt die App vollständig lokal nutzbar, wie bisher. Schlägt die
    // Initialisierung fehl (z.B. keine Internetverbindung beim ersten
    // Start), darf das nicht runApp() verhindern, sonst bleibt der Screen
    // leer und der Nutzer sieht nie, was im Fehlerprotokoll steht.
    if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseAnonKey,
        );
      } catch (e, stack) {
        ErrorLogService.instance
            .record('Supabase-Initialisierung fehlgeschlagen', '$e\n$stack');
      }
    }
    runApp(const BaustellenApp());
  }, (error, stack) {
    ErrorLogService.instance.record(error.toString(), stack.toString());
  });
}

ThemeMode _themeModeFrom(String value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
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
      // ✅ Eigener Consumer statt MaterialApp direkt hier zu bauen: der
      // MultiProvider muss erst im Baum existieren, bevor SettingsStore
      // (für die Design-Einstellung, siehe overview_settings_screen.dart)
      // aus demselben context lesbar ist.
      child: Consumer<SettingsStore>(
        builder: (context, settingsStore, _) => MaterialApp(
          title: 'Erwinator',
          theme: ThemeData(
            primarySwatch: Colors.grey,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.grey,
            brightness: Brightness.dark,
          ),
          themeMode: _themeModeFrom(settingsStore.settings.themeMode),
          // ✅ App läuft edge-to-edge (Inhalt kann hinter die System-Leiste
          // für Zurück/Home unten reichen) - ohne das hier würde jeder
          // einzelne Screen selbst dafür sorgen müssen, dass sein unterster
          // Button/Inhalt nicht in diesem unantippbaren Bereich landet. Nur
          // "bottom", damit oben nicht doppelt gepolstert wird (die AppBar
          // jedes Screens kümmert sich dort schon selbst um den
          // Status-Balken).
          builder: (context, child) => SafeArea(
            top: false,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const StartScreen(),
        ),
      ),
    );
  }
}
