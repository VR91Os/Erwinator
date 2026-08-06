import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/project.dart';

abstract class ProjectRepository {
  Future<List<Project>> loadProjects();
  Future<void> saveProjects(List<Project> projects);
}

class LocalProjectRepository implements ProjectRepository {
  static const _fileName = 'baustelli_data.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  @override
  Future<List<Project>> loadProjects() async {
    final file = await _file();
    if (!await file.exists()) {
      return [];
    }
    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return [];
    }
    final decoded = jsonDecode(content) as List<dynamic>;
    return decoded
        .map((e) => Project.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveProjects(List<Project> projects) async {
    final file = await _file();
    final encoded = jsonEncode(projects.map((p) => p.toMap()).toList());
    await file.writeAsString(encoded);
  }
}
