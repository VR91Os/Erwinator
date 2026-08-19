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

// Regressionstest für den "_dependents.isEmpty"-Crash: eine Store-Mutation,
// die synchron im selben Callback wie Navigator.pop notifyListeners()
// auslöst, kollidiert mit dem Element-Abbau des sich schließenden Dialogs.
// Testet den kompletten, realen "Neues Projekt"-Dialogfluss (nicht nur die
// popDialogThen-Utility isoliert), damit ein zukünftiger Regressions-Bug an
// dieser konkreten Stelle auffällt.
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
  testWidgets(
      '"Neues Projekt" anlegen: Dialog schließen + Store-Mutation crasht nicht',
      (tester) async {
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

    await tester.tap(find.byTooltip('Neues Projekt'));
    await tester.pumpAndSettle();
    expect(find.text('Neues Projekt'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Name *'), 'Testprojekt');
    await tester.tap(find.text('Erstellen'));

    // Genau der kritische Moment: Navigator.pop lief bereits synchron, die
    // Store-Mutation (und ihr notifyListeners()) ist über
    // addPostFrameCallback erst für den nächsten Frame vorgemerkt. Ein
    // einzelnes pump() verarbeitet exakt diesen Frame - würde die Mutation
    // stattdessen synchron im selben Callback wie Navigator.pop laufen,
    // wäre das der Moment, in dem die "_dependents.isEmpty"-Assertion
    // auslösen würde.
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Testprojekt'), findsOneWidget);
  });
}
