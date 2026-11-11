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
        'als Daten erkannt und als migriert markiert', () {
      final legacy = [
        {'id': 'p1', 'name': 'Haus A'},
      ];
      final result = migrate(
        rawDecoded: legacy,
        currentVersion: currentProjectSchemaVersion,
        steps: projectMigrationSteps,
      );
      expect(result.data, legacy);
      expect(result.migrated, isTrue);
    });

    test('legacy bare Map (Settings vor dem Umschlag) wird unverändert '
        'als Daten erkannt und als migriert markiert', () {
      final legacy = {'userName': 'Max'};
      final result = migrate(
        rawDecoded: legacy,
        currentVersion: currentSettingsSchemaVersion,
        steps: settingsMigrationSteps,
      );
      expect(result.data, legacy);
      expect(result.migrated, isTrue);
    });

    test('bereits verpackter Umschlag liefert die Nutzdaten unverändert '
        'zurück und gilt nicht als migriert', () {
      final data = [
        {'id': 'p1'}
      ];
      final wrapped = wrap(version: currentProjectSchemaVersion, data: data);
      final result = migrate(
        rawDecoded: wrapped,
        currentVersion: currentProjectSchemaVersion,
        steps: projectMigrationSteps,
      );
      expect(result.data, data);
      expect(result.migrated, isFalse);
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

    test('beim Laden eines alten, unverpackten Formats wird vor dem ersten '
        'erneuten Speichern ein Backup der rohen Rohdaten angelegt', () async {
      const raw = '[{"id":"p1","name":"Altes Projekt"}]';
      SharedPreferences.setMockInitialValues({'baustelli_data': raw});
      final repo = LocalProjectRepository();
      await repo.loadProjects();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('baustelli_data_backup'), raw);
    });

    test('beim Laden eines bereits aktuellen Umschlags wird KEIN Backup '
        'angelegt', () async {
      final repo = LocalProjectRepository();
      await repo.saveProjects([Project('p1', 'Projekt X')]);
      await repo.loadProjects();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('baustelli_data_backup'), isNull);
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

    test('beim Laden eines alten, unverpackten Formats wird vor dem ersten '
        'erneuten Speichern ein Backup der rohen Rohdaten angelegt', () async {
      const raw = '{"userName":"Alte Einstellung"}';
      SharedPreferences.setMockInitialValues({'baustelli_settings': raw});
      final repo = LocalSettingsRepository();
      await repo.loadSettings();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('baustelli_settings_backup'), raw);
    });
  });
}
