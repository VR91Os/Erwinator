import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/documentation_entry.dart';

abstract class DocumentationRepository {
  Future<List<DocumentationEntry>> loadEntries();
  Future<void> saveEntries(List<DocumentationEntry> entries);
}

// Eigener Speicher-Schlüssel, getrennt von den Projektdaten – der
// Dokumentations-Ordner ist app-weit und übersteht das Löschen einzelner
// Projekte.
class LocalDocumentationRepository implements DocumentationRepository {
  static const _key = 'baustelli_documentation';

  @override
  Future<List<DocumentationEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final content = prefs.getString(_key);
    if (content == null || content.trim().isEmpty) {
      return [];
    }
    final decoded = jsonDecode(content) as List<dynamic>;
    return decoded
        .map((e) => DocumentationEntry.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveEntries(List<DocumentationEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(entries.map((e) => e.toMap()).toList());
    await prefs.setString(_key, encoded);
  }
}
