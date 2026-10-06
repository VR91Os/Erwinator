import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baustelli/models/app_settings.dart';
import 'package:baustelli/models/project.dart';
import 'package:baustelli/repositories/project_repository.dart';
import 'package:baustelli/repositories/settings_repository.dart';
import 'package:baustelli/utils/schema_migration.dart';

void main() {
  group('schema_migration.migrate/wrap', () {
    test('legacy bare List (Projekte vor dem Umschlag) wird unverändert '
        'als Daten erkannt', () {
      final legacy = [
        {'id': 'p1', 'name': 'Haus A'},
      ];
      final result = migrate(
        rawDecoded: legacy,
        currentVersion: currentProjectSchemaVersion,
        steps: projectMigrationSteps,
      );
      expect(result, legacy);
    });

    test('legacy bare Map (Settings vor dem Umschlag) wird unverändert '
        'als Daten erkannt', () {
      final legacy = {'userName': 'Max'};
      final result = migrate(
        rawDecoded: legacy,
        currentVersion: currentSettingsSchemaVersion,
        steps: settingsMigrationSteps,
      );
      expect(result, legacy);
    });

    test('bereits verpackter Umschlag liefert die Nutzdaten unverändert '
        'zurück, unabhängig vom Inhalt', () {
      final data = [
        {'id': 'p1'}
      ];
      final wrapped = wrap(version: currentProjectSchemaVersion, data: data);
      final result = migrate(
        rawDecoded: wrapped,
        currentVersion: currentProjectSchemaVersion,
        steps: projectMigrationSteps,
      );
      expect(result, data);
    });
  });

  group('LocalProjectRepository liest altes, unverpacktes Format', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('ein vor der Umschlag-Einführung gespeichertes bare JSON-Array '
        'lädt weiterhin korrekt', () async {
      SharedPreferences.setMockInitialValues({
        'baustelli_data': '[{"id":"p1","name":"Altes Projekt"}]',
      });
      final repo = LocalProjectRepository();
      final projects = await repo.loadProjects();
      expect(projects, hasLength(1));
      expect(projects.single.id, 'p1');
      expect(projects.single.name, 'Altes Projekt');
    });

    test('nach dem Speichern wird im neuen Umschlag-Format abgelegt und '
        'lädt beim nächsten Mal wieder korrekt', () async {
      final repo = LocalProjectRepository();
      await repo.saveProjects([Project('p1', 'Projekt X')]);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('baustelli_data');
      expect(raw, contains('"schemaVersion"'));

      final reloaded = await repo.loadProjects();
      expect(reloaded, hasLength(1));
      expect(reloaded.single.name, 'Projekt X');
    });
  });

  group('LocalSettingsRepository liest altes, unverpacktes Format', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('ein vor der Umschlag-Einführung gespeichertes bare JSON-Objekt '
        'lädt weiterhin korrekt', () async {
      SharedPreferences.setMockInitialValues({
        'baustelli_settings': '{"userName":"Alte Einstellung"}',
      });
      final repo = LocalSettingsRepository();
      final settings = await repo.loadSettings();
      expect(settings.userName, 'Alte Einstellung');
    });

    test('nach dem Speichern wird im neuen Umschlag-Format abgelegt und '
        'lädt beim nächsten Mal wieder korrekt', () async {
      final repo = LocalSettingsRepository();
      final settings = AppSettings()..userName = 'Neu';
      await repo.saveSettings(settings);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('baustelli_settings');
      expect(raw, contains('"schemaVersion"'));

      final reloaded = await repo.loadSettings();
      expect(reloaded.userName, 'Neu');
    });
  });
}
