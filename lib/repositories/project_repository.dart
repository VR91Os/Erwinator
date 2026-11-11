import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/project.dart';
import '../utils/schema_migration.dart';

abstract class ProjectRepository {
  Future<List<Project>> loadProjects();
  Future<void> saveProjects(List<Project> projects);
}

// Nutzt SharedPreferences statt direktem Datei-Zugriff, damit die
// Speicherung auf allen Plattformen funktioniert – inklusive Web, wo
// dart:io nicht verfügbar ist.
class LocalProjectRepository implements ProjectRepository {
  static const _key = 'baustelli_data';
  // Rohe, unmigrierte Fassung - wird nur geschrieben, wenn beim Laden
  // tatsächlich migriert wurde (siehe loadProjects()), als manuell
  // wiederherstellbare Rückfalloption, falls sich ein Fehler in einem
  // Migrationsschritt erst später zeigt. Nie automatisch gelesen.
  static const _backupKey = 'baustelli_data_backup';

  @override
  Future<List<Project>> loadProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final content = prefs.getString(_key);
    if (content == null || content.trim().isEmpty) {
      return [];
    }
    final decoded = jsonDecode(content);
    final result = migrate(
      rawDecoded: decoded,
      currentVersion: currentProjectSchemaVersion,
      steps: projectMigrationSteps,
    );
    if (result.migrated) {
      // Das Backup ist eine reine Zusatz-Absicherung - scheitert nur dieser
      // Schreibvorgang (z.B. localStorage-Quota im Web voll), darf das
      // NICHT dazu führen, dass die gerade erfolgreich geladenen/migrierten
      // Projektdaten verworfen werden (loadProjects() würde sonst eine
      // Exception werfen, obwohl das Laden an sich geklappt hat).
      try {
        await prefs.setString(_backupKey, content);
      } catch (_) {}
    }
    final data = result.data as List<dynamic>;
    return data
        .map((e) => Project.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveProjects(List<Project> projects) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = wrap(
      version: currentProjectSchemaVersion,
      data: projects.map((p) => p.toMap()).toList(),
    );
    await prefs.setString(_key, jsonEncode(payload));
  }
}
