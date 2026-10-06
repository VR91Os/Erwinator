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

  @override
  Future<List<Project>> loadProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final content = prefs.getString(_key);
    if (content == null || content.trim().isEmpty) {
      return [];
    }
    final decoded = jsonDecode(content);
    final data = migrate(
      rawDecoded: decoded,
      currentVersion: currentProjectSchemaVersion,
      steps: projectMigrationSteps,
    ) as List<dynamic>;
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
