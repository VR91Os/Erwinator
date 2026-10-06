import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../utils/schema_migration.dart';

abstract class SettingsRepository {
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings settings);
}

// Nutzt SharedPreferences statt direktem Datei-Zugriff, damit die
// Speicherung auf allen Plattformen funktioniert – inklusive Web, wo
// dart:io nicht verfügbar ist.
class LocalSettingsRepository implements SettingsRepository {
  static const _key = 'baustelli_settings';

  @override
  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final content = prefs.getString(_key);
    if (content == null || content.trim().isEmpty) {
      return AppSettings();
    }
    final decoded = jsonDecode(content);
    final data = migrate(
      rawDecoded: decoded,
      currentVersion: currentSettingsSchemaVersion,
      steps: settingsMigrationSteps,
    ) as Map<String, dynamic>;
    return AppSettings.fromMap(data);
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = wrap(
      version: currentSettingsSchemaVersion,
      data: settings.toMap(),
    );
    await prefs.setString(_key, jsonEncode(payload));
  }
}
