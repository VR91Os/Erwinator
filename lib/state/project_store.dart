import 'package:flutter/foundation.dart';

import '../models/gewerk.dart';
import '../models/modules/contact_module.dart';
import '../models/modules/file_module.dart';
import '../models/modules/gewerk_module.dart';
import '../models/modules/todo_module.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../repositories/project_repository.dart';
import '../utils/id_generator.dart';

class ProjectStore extends ChangeNotifier {
  ProjectStore({ProjectRepository? repository})
      : _repository = repository ?? LocalProjectRepository();

  final ProjectRepository _repository;

  List<Project> projects = [];
  bool isLoading = true;

  Future<void> init() async {
    // Auf Plattformen ohne Dateisystem-Zugriff (z.B. Web) bleibt die App
    // ohne Persistenz nutzbar, statt beim Start abzustürzen.
    try {
      projects = await _repository.loadProjects();
    } catch (_) {
      projects = [];
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      await _repository.saveProjects(projects);
    } catch (_) {}
  }

  Project _project(String projectId) =>
      projects.firstWhere((p) => p.id == projectId);

  Gewerk _gewerk(String projectId, String gewerkId) =>
      _project(projectId).gewerke.firstWhere((g) => g.id == gewerkId);

  GewerkModule _module(String projectId, String gewerkId, String moduleId) =>
      _gewerk(projectId, gewerkId).modules.firstWhere((m) => m.id == moduleId);

  TodoModule _todoModule(String projectId, String gewerkId, String moduleId) =>
      _module(projectId, gewerkId, moduleId) as TodoModule;

  Future<void> addProject(String name, {String address = ''}) async {
    projects.add(Project(newId(), name, address: address));
    notifyListeners();
    await _persist();
  }

  Future<void> importProject(Project project) async {
    projects.add(project);
    notifyListeners();
    await _persist();
  }

  Future<void> updateExportPrefs(
    String projectId, {
    required bool exportAllDatedTodos,
    required bool exportPriorityTasks,
  }) async {
    final project = _project(projectId);
    project.exportAllDatedTodos = exportAllDatedTodos;
    project.exportPriorityTasks = exportPriorityTasks;
    notifyListeners();
    await _persist();
  }

  Future<void> addGewerk(String projectId, String name) async {
    _project(projectId).gewerke.add(Gewerk(newId(), name));
    notifyListeners();
    await _persist();
  }

  Future<void> renameGewerk(
    String projectId,
    String gewerkId,
    String name,
  ) async {
    _gewerk(projectId, gewerkId).name = name;
    notifyListeners();
    await _persist();
  }

  Future<void> removeGewerk(String projectId, String gewerkId) async {
    _project(projectId).gewerke.removeWhere((g) => g.id == gewerkId);
    notifyListeners();
    await _persist();
  }

  Future<void> addModule(
    String projectId,
    String gewerkId,
    String moduleType,
  ) async {
    final id = newId();
    final GewerkModule module = switch (moduleType) {
      ContactModule.moduleType => ContactModule(id),
      TodoModule.moduleType => TodoModule(id),
      FileModule.moduleType => FileModule(id),
      _ => throw ArgumentError('Unbekannter Modultyp: $moduleType'),
    };
    _gewerk(projectId, gewerkId).modules.add(module);
    notifyListeners();
    await _persist();
  }

  Future<void> removeModule(
    String projectId,
    String gewerkId,
    String moduleId,
  ) async {
    _gewerk(projectId, gewerkId).modules.removeWhere((m) => m.id == moduleId);
    notifyListeners();
    await _persist();
  }

  Future<void> addTaskToTodoModule(
    String projectId,
    String gewerkId,
    String moduleId,
    Task task,
  ) async {
    _todoModule(projectId, gewerkId, moduleId).tasks.add(task);
    notifyListeners();
    await _persist();
  }

  Future<void> updateTaskStatus(
    String projectId,
    String gewerkId,
    String moduleId,
    String taskId,
  ) async {
    final task = _todoModule(projectId, gewerkId, moduleId)
        .tasks
        .firstWhere((t) => t.id == taskId);
    if (task.status == 'offen') {
      task.status = 'teilweise';
    } else if (task.status == 'teilweise') {
      task.status = 'erledigt';
    } else if (task.status == 'erledigt') {
      task.status = 'offen';
    }
    task.updatedAt = DateTime.now();
    notifyListeners();
    await _persist();
  }

  Future<void> shiftTaskDueDate(
    String projectId,
    String gewerkId,
    String moduleId,
    String taskId,
  ) async {
    final task = _todoModule(projectId, gewerkId, moduleId)
        .tasks
        .firstWhere((t) => t.id == taskId);
    if (task.dueDate == null) {
      return;
    }
    task.dueDate = task.dueDate!.add(const Duration(days: 1));
    task.updatedAt = DateTime.now();
    notifyListeners();
    await _persist();
  }

  Future<void> archiveTask(
    String projectId,
    String gewerkId,
    String moduleId,
    String taskId,
  ) async {
    final task = _todoModule(projectId, gewerkId, moduleId)
        .tasks
        .firstWhere((t) => t.id == taskId);
    task.status = 'archiviert';
    task.updatedAt = DateTime.now();
    notifyListeners();
    await _persist();
  }

  Future<void> updateContactModule(
    String projectId,
    String gewerkId,
    String moduleId, {
    required String name,
    required String phone,
  }) async {
    final module = _module(projectId, gewerkId, moduleId) as ContactModule;
    module.name = name;
    module.phone = phone;
    notifyListeners();
    await _persist();
  }

  Future<void> addFileEntry(
    String projectId,
    String gewerkId,
    String moduleId,
    FileEntry entry,
  ) async {
    final module = _module(projectId, gewerkId, moduleId) as FileModule;
    module.entries.add(entry);
    notifyListeners();
    await _persist();
  }

  Future<void> addFileVersion(
    String projectId,
    String gewerkId,
    String moduleId,
    String entryId,
    FileVersion version,
  ) async {
    final module = _module(projectId, gewerkId, moduleId) as FileModule;
    final entry = module.entries.firstWhere((e) => e.id == entryId);
    entry.versions.add(version);
    notifyListeners();
    await _persist();
  }
}
