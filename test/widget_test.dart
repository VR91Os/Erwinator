import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:baustelli/models/app_settings.dart';
import 'package:baustelli/models/project.dart';
import 'package:baustelli/repositories/project_repository.dart';
import 'package:baustelli/repositories/settings_repository.dart';
import 'package:baustelli/screens/start_screen.dart';
import 'package:baustelli/state/project_store.dart';
import 'package:baustelli/state/settings_store.dart';

// Vermeidet echte path_provider-Plattformaufrufe (nicht verfügbar in
// Widget-Tests) durch In-Memory-Repositories statt Local*Repository.
class _InMemoryProjectRepository implements ProjectRepository {
  @override
  Future<List<Project>> loadProjects() async => [];

  @override
  Future<void> saveProjects(List<Project> projects) async {}
}

class _InMemorySettingsRepository implements SettingsRepository {
  @override
  Future<AppSettings> loadSettings() async => AppSettings();

  @override
  Future<void> saveSettings(AppSettings settings) async {}
}

void main() {
  testWidgets('App startet und zeigt die Startseite', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) =>
                ProjectStore(repository: _InMemoryProjectRepository())
                  ..init(),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                SettingsStore(repository: _InMemorySettingsRepository())
                  ..init(),
          ),
        ],
        child: const MaterialApp(home: StartScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Baustellen Helfer'), findsOneWidget);
    expect(find.byTooltip('Neues Projekt'), findsOneWidget);
  });
}
