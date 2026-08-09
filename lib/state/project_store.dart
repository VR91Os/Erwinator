import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/audit_entry.dart';
import '../models/gewerk.dart';
import '../models/helper_demand.dart';
import '../models/image_annotation.dart';
import '../models/modules/contact_module.dart';
import '../models/modules/file_module.dart';
import '../models/modules/gewerk_module.dart';
import '../models/modules/todo_module.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../repositories/project_repository.dart';
import '../services/sharing_service.dart';
import '../supabase_config.dart';
import '../utils/id_generator.dart';

const neubauStarterGewerke = ['Architekt', 'Erdbau', 'Behörde'];
const sanierungStarterGewerke = ['Abrissfirma', 'Baumeister'];

class ProjectStore extends ChangeNotifier {
  ProjectStore({ProjectRepository? repository, SharingService? sharingService})
      : _repository = repository ?? LocalProjectRepository(),
        _sharingService = sharingService ?? SharingService();

  final ProjectRepository _repository;
  final SharingService _sharingService;
  final Map<String, RealtimeChannel> _projectSubscriptions = {};

  // Projekt-Teilen ist nur aktiv, wenn supabase_config.dart ausgefüllt ist –
  // sonst bleibt die App wie bisher rein lokal nutzbar.
  bool get _sharingConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

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

    if (_sharingConfigured) {
      for (final project in projects) {
        if (project.sharedId != null) _subscribeToProject(project.sharedId!);
      }
    }
  }

  // Hält ein geteiltes Projekt live synchron: Änderungen von anderen
  // Geräten kommen sofort hier an und aktualisieren die lokale Kopie.
  void _subscribeToProject(String sharedId) {
    if (_projectSubscriptions.containsKey(sharedId)) return;
    _projectSubscriptions[sharedId] =
        _sharingService.subscribeToProjectUpdates(sharedId, (updated) {
      final index = projects.indexWhere((p) => p.sharedId == sharedId);
      if (index == -1) return;
      projects[index] = updated;
      notifyListeners();
      _repository.saveProjects(projects).catchError((_) {});
    });
  }

  Future<String> shareProject(String projectId) async {
    final project = _project(projectId);
    final sharedId = await _sharingService.shareProject(project);
    project.sharedId = sharedId;
    _subscribeToProject(sharedId);
    notifyListeners();
    await _persist();
    return sharedId;
  }

  // Fügt ein Projekt hinzu, dem man beigetreten ist (Beitrittsanfrage
  // wurde bestätigt) – behält die ID aus der Cloud bei, damit Live-Updates
  // korrekt zugeordnet werden.
  Future<void> addSharedProject(Project project) async {
    if (projects.any((p) => p.id == project.id)) return;
    projects.add(project);
    if (project.sharedId != null) _subscribeToProject(project.sharedId!);
    notifyListeners();
    await _persist();
  }

  @override
  void dispose() {
    for (final channel in _projectSubscriptions.values) {
      _sharingService.unsubscribe(channel);
    }
    super.dispose();
  }

  Future<void> _persist() async {
    try {
      await _repository.saveProjects(projects);
    } catch (_) {}
    if (_sharingConfigured) {
      for (final project in projects) {
        if (project.sharedId == null) continue;
        _sharingService.pushUpdate(project.sharedId!, project).catchError((_) {});
      }
    }
  }

  Project _project(String projectId) =>
      projects.firstWhere((p) => p.id == projectId);

  Gewerk _gewerk(String projectId, String gewerkId) =>
      _project(projectId).gewerke.firstWhere((g) => g.id == gewerkId);

  GewerkModule _module(String projectId, String gewerkId, String moduleId) =>
      _gewerk(projectId, gewerkId).modules.firstWhere((m) => m.id == moduleId);

  TodoModule _todoModule(String projectId, String gewerkId, String moduleId) =>
      _module(projectId, gewerkId, moduleId) as TodoModule;

  Future<void> addProject(
    String name, {
    String address = '',
    required String projectType,
  }) async {
    final starterGewerke = switch (projectType) {
      'sanierung' => sanierungStarterGewerke,
      'neubau' => neubauStarterGewerke,
      _ => const <String>[],
    };
    projects.add(Project(
      newId(),
      name,
      address: address,
      projectType: projectType,
      // ✅ Standard-Gewerke starten direkt mit einem Kontakt-Modul.
      gewerke: starterGewerke
          .map((g) => Gewerk(newId(), g, modules: [ContactModule(newId())]))
          .toList(),
    ));
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

  Future<void> renameModule(
    String projectId,
    String gewerkId,
    String moduleId,
    String label,
  ) async {
    _module(projectId, gewerkId, moduleId).label = label;
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
    String taskId, {
    required String actor,
  }) async {
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
    task.history.add(AuditEntry(
      kurzzeichen: actor,
      action: task.status == 'erledigt'
          ? 'abgehakt'
          : 'Status geändert: ${task.status}',
    ));
    notifyListeners();
    await _persist();
  }

  Future<void> shiftTaskDueDate(
    String projectId,
    String gewerkId,
    String moduleId,
    String taskId, {
    required String actor,
  }) async {
    final task = _todoModule(projectId, gewerkId, moduleId)
        .tasks
        .firstWhere((t) => t.id == taskId);
    if (task.dueDate == null) {
      return;
    }
    task.dueDate = task.dueDate!.add(const Duration(days: 1));
    task.updatedAt = DateTime.now();
    task.history
        .add(AuditEntry(kurzzeichen: actor, action: 'Fälligkeit verschoben'));
    notifyListeners();
    await _persist();
  }

  Future<void> archiveTask(
    String projectId,
    String gewerkId,
    String moduleId,
    String taskId, {
    required String actor,
  }) async {
    final task = _todoModule(projectId, gewerkId, moduleId)
        .tasks
        .firstWhere((t) => t.id == taskId);
    task.status = 'archiviert';
    task.updatedAt = DateTime.now();
    task.history.add(AuditEntry(kurzzeichen: actor, action: 'archiviert'));
    notifyListeners();
    await _persist();
  }

  Future<void> updateContactModule(
    String projectId,
    String gewerkId,
    String moduleId, {
    required String name,
    required String phone,
    required String actor,
  }) async {
    final module = _module(projectId, gewerkId, moduleId) as ContactModule;
    module.name = name;
    module.phone = phone;
    module.history.add(AuditEntry(kurzzeichen: actor, action: 'bearbeitet'));
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
    FileVersion version, {
    required String actor,
  }) async {
    final module = _module(projectId, gewerkId, moduleId) as FileModule;
    final entry = module.entries.firstWhere((e) => e.id == entryId);
    entry.versions.add(version);
    entry.history.add(AuditEntry(
      kurzzeichen: actor,
      action: 'neue Version hochgeladen (${version.label})',
    ));
    notifyListeners();
    await _persist();
  }

  Future<void> addImageAnnotation(
    String projectId,
    String gewerkId,
    String moduleId,
    String entryId,
    ImageAnnotation annotation,
  ) async {
    final module = _module(projectId, gewerkId, moduleId) as FileModule;
    final entry = module.entries.firstWhere((e) => e.id == entryId);
    entry.annotations.add(annotation);
    notifyListeners();
    await _persist();
  }

  Future<void> removeImageAnnotation(
    String projectId,
    String gewerkId,
    String moduleId,
    String entryId,
    String annotationId,
  ) async {
    final module = _module(projectId, gewerkId, moduleId) as FileModule;
    final entry = module.entries.firstWhere((e) => e.id == entryId);
    entry.annotations.removeWhere((a) => a.id == annotationId);
    notifyListeners();
    await _persist();
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  // Legt für jeden Tag im Zeitraum [from, to] einen Helferbedarf an bzw.
  // aktualisiert die benötigte Anzahl, falls für den Tag schon einer
  // existiert. So deckt ein einzelner Aufruf sowohl Tages- als auch
  // Wochen-weise Eintragung ab. Projekt-weit statt je Gewerk, erscheint im
  // Überblickskalender.
  Future<void> setHelperDemand(
    String projectId, {
    required DateTime from,
    required DateTime to,
    required int neededCount,
    String note = '',
    required String actor,
  }) async {
    final project = _project(projectId);
    final start = _dateOnly(from);
    final end = _dateOnly(to);
    for (var day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))) {
      final existing =
          project.helperDemands.where((d) => d.date.isAtSameMomentAs(day));
      final entry = AuditEntry(kurzzeichen: actor, action: 'Bedarf eingetragen');
      if (existing.isNotEmpty) {
        existing.first.neededCount = neededCount;
        existing.first.note = note;
        existing.first.history.add(entry);
      } else {
        project.helperDemands.add(HelperDemand(
          id: newId(),
          date: day,
          neededCount: neededCount,
          note: note,
          history: [entry],
        ));
      }
    }
    notifyListeners();
    await _persist();
  }

  Future<void> removeHelperDemand(String projectId, String demandId) async {
    _project(projectId).helperDemands.removeWhere((d) => d.id == demandId);
    notifyListeners();
    await _persist();
  }

  // Trägt einen Helfer für jeden Tag im Zeitraum [from, to] ein. Tage ohne
  // bestehenden Bedarf bekommen automatisch einen Bedarf (1 Helfer) angelegt,
  // damit die Zusage nicht verloren geht.
  Future<void> addHelperSignupForRange(
    String projectId, {
    required DateTime from,
    required DateTime to,
    required String name,
    String? startTime,
    String? endTime,
    required String actor,
  }) async {
    final project = _project(projectId);
    final start = _dateOnly(from);
    final end = _dateOnly(to);
    for (var day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))) {
      final existing =
          project.helperDemands.where((d) => d.date.isAtSameMomentAs(day));
      final HelperDemand demand;
      if (existing.isNotEmpty) {
        demand = existing.first;
      } else {
        demand = HelperDemand(id: newId(), date: day, neededCount: 1);
        project.helperDemands.add(demand);
      }
      demand.signups.add(HelperSignup(
        id: newId(),
        name: name,
        startTime: startTime,
        endTime: endTime,
      ));
      demand.history
          .add(AuditEntry(kurzzeichen: actor, action: 'Helfer eingetragen: $name'));
    }
    notifyListeners();
    await _persist();
  }

  Future<void> removeHelperSignup(
    String projectId,
    String demandId,
    String signupId,
  ) async {
    final demand =
        _project(projectId).helperDemands.firstWhere((d) => d.id == demandId);
    demand.signups.removeWhere((s) => s.id == signupId);
    notifyListeners();
    await _persist();
  }
}
