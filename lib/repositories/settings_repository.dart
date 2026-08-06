import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';

abstract class SettingsRepository {
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings settings);
}

class LocalSettingsRepository implements SettingsRepository {
  static const _fileName = 'baustelli_settings.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  @override
  Future<AppSettings> loadSettings() async {
    final file = await _file();
    if (!await file.exists()) {
      return AppSettings();
    }
    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return AppSettings();
    }
    final decoded = jsonDecode(content) as Map<String, dynamic>;
    return AppSettings.fromMap(decoded);
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(settings.toMap()));
  }
}
