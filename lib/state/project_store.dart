import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/audit_entry.dart';
import '../models/finance_entry.dart';
import '../models/gewerk.dart';
import '../models/helper_demand.dart';
import '../models/image_annotation.dart';
import '../models/modules/contact_module.dart';
import '../models/modules/file_module.dart';
import '../models/modules/finance_module.dart';
import '../models/modules/gewerk_module.dart';
import '../models/modules/todo_module.dart';
import '../models/presence_entry.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../models/time_tracking.dart';
import '../repositories/project_repository.dart';
import '../services/error_log_service.dart';
import '../services/notification_service.dart';
import '../services/sharing_service.dart';
import '../supabase_config.dart';
import '../utils/holidays.dart';
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

  // Serialisiert überlappende Cloud-Syncs pro geteiltem Projekt (statt sie
  // parallel laufen zu lassen): zwei schnelle Aktionen kurz hintereinander
  // (oder ein Sync, der noch läuft, während der nächste Edit passiert)
  // würden sonst zwei fetch→merge→push-Zyklen gleichzeitig auf demselben
  // Projekt ausführen und sich potenziell gegenseitig überschreiben.
  final Map<String, Future<bool>> _syncQueue = {};

  // Verhindert doppelte shared_projects-Zeilen durch Doppel-Tap auf
  // "Teilen", solange die erste Anfrage noch läuft.
  final Map<String, Future<String>> _shareInProgress = {};

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
    for (final project in projects) {
      project.pruneTombstones();
    }
    isLoading = false;
    notifyListeners();
    NotificationService.instance.syncForProjects(projects);

    if (_sharingConfigured) {
      // Abgleich mit dem aktuellen Cloud-Stand beim Start (nicht nur beim
      // nächsten lokalen Edit) – deckt den Fall ab, dass sich während der
      // Offline-Zeit etwas geändert hat, das Realtime allein nicht mehr
      // nachliefert (Events vor dem Abonnieren gehen sonst verloren).
      var mergedAnything = false;
      for (final project in List<Project>.of(projects)) {
        if (project.sharedId == null) continue;
        if (await _syncSharedProject(project)) mergedAnything = true;
        _subscribeToProject(project.sharedId!);
      }
      if (mergedAnything) {
        notifyListeners();
        try {
          await _repository.saveProjects(projects);
        } catch (_) {}
      }
    }
  }

  // Hält ein geteiltes Projekt live synchron: Änderungen von anderen
  // Geräten kommen sofort hier an. Statt die lokale Kopie 1:1 zu ersetzen
  // (Datenverlust bei gleichzeitiger lokaler Änderung), wird sie mit dem
  // eingehenden Stand gemergt (Option C, siehe lib/utils/id_merge.dart).
  void _subscribeToProject(String sharedId) {
    if (_projectSubscriptions.containsKey(sharedId)) return;
    _projectSubscriptions[sharedId] =
        _sharingService.subscribeToProjectUpdates(sharedId, (updated) {
      final index = projects.indexWhere((p) => p.sharedId == sharedId);
      if (index == -1) return;
      projects[index] = projects[index].mergeFrom(updated);
      notifyListeners();
      _repository.saveProjects(projects).catchError((e, stack) {
        ErrorLogService.instance
            .record('Lokales Speichern fehlgeschlagen', '$e\n$stack');
      });
    });
  }

  // Serialisiert-per-sharedId Wrapper um [_doSyncSharedProject]: siehe
  // [_syncQueue]. _doSyncSharedProject wirft nie (fängt alle Fehler selbst
  // ab), daher bleibt die Warteschlange auch nach einem Fehlschlag nutzbar.
  Future<bool> _syncSharedProject(Project project) {
    final sharedId = project.sharedId;
    if (sharedId == null) return Future.value(false);
    final previous = _syncQueue[sharedId] ?? Future.value(false);
    final next = previous.then((_) => _doSyncSharedProject(project));
    _syncQueue[sharedId] = next;
    return next;
  }

  // Holt den aktuellen Cloud-Stand, merged ihn mit der lokalen Version
  // (statt blind zu überschreiben) und schreibt das Ergebnis zurück – so
  // in beide Richtungen. Gibt false zurück (und protokolliert den Fehler),
  // wenn der Abgleich fehlschlägt, z.B. mangels Netzwerk – die lokale
  // Änderung bleibt dabei immer erhalten, nur der Cloud-Abgleich fällt aus.
  Future<bool> _doSyncSharedProject(Project project) async {
    final sharedId = project.sharedId;
    if (sharedId == null) return false;
    try {
      final remote = await _sharingService.fetchSharedProject(sharedId);
      final merged = remote == null ? project : project.mergeFrom(remote);
      final index = projects.indexWhere((p) => p.id == project.id);
      if (index != -1) projects[index] = merged;
      await _sharingService.pushUpdate(sharedId, merged);
      return true;
    } catch (e, stack) {
      ErrorLogService.instance.record(
        'Synchronisierung fehlgeschlagen für "${project.name}"',
        '$e\n$stack',
      );
      return false;
    }
  }

  Future<String> shareProject(String projectId) async {
    final inFlight = _shareInProgress[projectId];
    if (inFlight != null) return inFlight;

    final future = _shareProject(projectId);
    _shareInProgress[projectId] = future;
    try {
      return await future;
    } finally {
      _shareInProgress.remove(projectId);
    }
  }

  Future<String> _shareProject(String projectId) async {
    final project = _project(projectId);
    if (project == null) return Future.error(StateError('Projekt nicht gefunden'));
    final sharedId = await _sharingService.shareProject(project);
    project.sharedId = sharedId;
    _subscribeToProject(sharedId);
    notifyListeners();
    await _persist(projectId);
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
    await _persist(project.id);
  }

  @override
  void dispose() {
    for (final channel in _projectSubscriptions.values) {
      _sharingService.unsubscribe(channel);
    }
    super.dispose();
  }

  // [changedProjectId] beschränkt den Cloud-Sync auf das betroffene
  // Projekt, statt bei jeder Kleinigkeit ausnahmslos alle geteilten
  // Projekte neu abzugleichen (unnötiger Netzwerk-Traffic inkl. der
  // Dateiinhalte aller anderen Projekte). null (z.B. bei neu/importierten
  // Projekten ohne bekannte sharedId) synct sicherheitshalber weiterhin
  // alle.
  Future<void> _persist([String? changedProjectId]) async {
    try {
      await _repository.saveProjects(projects);
    } catch (e, stack) {
      ErrorLogService.instance
          .record('Lokales Speichern fehlgeschlagen', '$e\n$stack');
    }
    NotificationService.instance.syncForProjects(projects);
    if (!_sharingConfigured) return;

    // Vor dem Push erst den aktuellen Cloud-Stand holen und mergen (statt
    // blind zu überschreiben) – deckt sowohl "Kollege hat parallel etwas
    // geändert" als auch "war offline, jetzt wieder online" ab.
    final targets = changedProjectId == null
        ? List<Project>.of(projects)
        : projects.where((p) => p.id == changedProjectId).toList();
    var mergedAnything = false;
    for (final project in targets) {
      if (project.sharedId == null) continue;
      if (await _syncSharedProject(project)) mergedAnything = true;
    }
    if (mergedAnything) {
      notifyListeners();
      try {
        await _repository.saveProjects(projects);
      } catch (_) {}
    }
  }

  // Null-sichere Lookups statt firstWhere ohne orElse: hat ein anderes
  // Gerät das Element per Sync gerade gelöscht, während lokal eine Aktion
  // darauf zielt, brach das vorher mit einer unbehandelten StateError ab.
  // Jetzt bricht die jeweilige Aktion still ab (Element existiert nicht
  // mehr, es gibt nichts zu tun).
  Project? _project(String projectId) {
    for (final p in projects) {
      if (p.id == projectId) return p;
    }
    return null;
  }

  Gewerk? _gewerk(String projectId, String gewerkId) {
    final project = _project(projectId);
    if (project == null) return null;
    for (final g in project.gewerke) {
      if (g.id == gewerkId) return g;
    }
    return null;
  }

  GewerkModule? _module(String projectId, String gewerkId, String moduleId) {
    final gewerk = _gewerk(projectId, gewerkId);
    if (gewerk == null) return null;
    for (final m in gewerk.modules) {
      if (m.id == moduleId) return m;
    }
    return null;
  }

  TodoModule? _todoModule(String projectId, String gewerkId, String moduleId) {
    final module = _module(projectId, gewerkId, moduleId);
    return module is TodoModule ? module : null;
  }

  Task? _task(TodoModule module, String taskId) {
    for (final t in module.tasks) {
      if (t.id == taskId) return t;
    }
    return null;
  }

  Future<void> addProject(
    String name, {
    String address = '',
    String projectType = '',
  }) async {
    // ⛔ Vorgefertigte Start-Gewerke je nach Projekt-Art (Neubau/Sanierung)
    // deaktiviert – ein neues Projekt bekommt stattdessen nur einen
    // einzigen Reiter "Allgemein" mit allen Modulen (siehe unten).
    // final starterGewerke = switch (projectType) {
    //   'sanierung' => sanierungStarterGewerke,
    //   'neubau' => neubauStarterGewerke,
    //   _ => const <String>[],
    // };
    projects.add(Project(
      newId(),
      name,
      address: address,
      projectType: projectType,
      gewerke: [
        Gewerk(newId(), 'Allgemein', modules: [
          ContactModule(newId()),
          TodoModule(newId()),
          FileModule(newId()),
        ]),
      ],
      // gewerke: starterGewerke
      //     .map((g) => Gewerk(newId(), g, modules: [ContactModule(newId())]))
      //     .toList(),
    ));
    notifyListeners();
    await _persist();
  }

  Future<void> importProject(Project project) async {
    projects.add(project);
    notifyListeners();
    await _persist(project.id);
  }

  Future<void> updateExportPrefs(
    String projectId, {
    required bool exportAllDatedTodos,
    required bool exportPriorityTasks,
  }) async {
    final project = _project(projectId);
    if (project == null) return;
    project.exportAllDatedTodos = exportAllDatedTodos;
    project.exportPriorityTasks = exportPriorityTasks;
    project.updatedAt = DateTime.now();
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> updatePriorityWarningSettings(
    String projectId, {
    required int priorityWarningDays,
    required bool notifyOnPriorityWarning,
  }) async {
    final project = _project(projectId);
    if (project == null) return;
    project.priorityWarningDays = priorityWarningDays;
    project.notifyOnPriorityWarning = notifyOnPriorityWarning;
    project.updatedAt = DateTime.now();
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> updateSkipPartialStatus(
    String projectId, {
    required bool skipPartialStatus,
  }) async {
    final project = _project(projectId);
    if (project == null) return;
    project.skipPartialStatus = skipPartialStatus;
    project.updatedAt = DateTime.now();
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> updateShiftDays(
    String projectId, {
    required int shiftDays,
  }) async {
    final project = _project(projectId);
    if (project == null) return;
    project.shiftDays = shiftDays;
    project.updatedAt = DateTime.now();
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> updateArchiveSettings(
    String projectId, {
    required int archiveAfterDays,
    required bool moveCompletedToArchiveToo,
  }) async {
    final project = _project(projectId);
    if (project == null) return;
    project.archiveAfterDays = archiveAfterDays;
    project.moveCompletedToArchiveToo = moveCompletedToArchiveToo;
    project.updatedAt = DateTime.now();
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> updateDeleteArchivedSettings(
    String projectId, {
    required bool deleteArchivedTasksPermanently,
    required int deleteArchivedAfterDays,
  }) async {
    final project = _project(projectId);
    if (project == null) return;
    project.deleteArchivedTasksPermanently = deleteArchivedTasksPermanently;
    project.deleteArchivedAfterDays = deleteArchivedAfterDays;
    project.updatedAt = DateTime.now();
    notifyListeners();
    await _persist(projectId);
  }

  // Entfernt archivierte (nicht erledigte) Aufgaben endgültig, sobald sie
  // insgesamt archiveAfterDays + deleteArchivedAfterDays Tage alt sind –
  // nur wenn deleteArchivedTasksPermanently aktiv ist. Wird beim Öffnen
  // eines Projekts aufgerufen (siehe GewerkeScreen.initState).
  Future<void> cleanupExpiredArchivedTasks(String projectId) async {
    final project = _project(projectId);
    if (project == null || !project.deleteArchivedTasksPermanently) return;
    final threshold =
        project.archiveAfterDays + project.deleteArchivedAfterDays;
    var changed = false;
    for (final gewerk in project.gewerke) {
      for (final module in gewerk.modules.whereType<TodoModule>()) {
        final expired = module.tasks.where((task) =>
            task.status == 'archiviert' &&
            DateTime.now().difference(task.updatedAt).inDays >= threshold);
        if (expired.isEmpty) continue;
        final now = DateTime.now();
        for (final task in expired) {
          project.deletedIds[task.id] = now;
        }
        module.tasks.removeWhere((task) => task.status == 'archiviert' &&
            DateTime.now().difference(task.updatedAt).inDays >= threshold);
        changed = true;
      }
    }
    if (!changed) return;
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> addGewerk(String projectId, String name) async {
    final project = _project(projectId);
    if (project == null) return;
    project.gewerke.add(Gewerk(newId(), name));
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> renameGewerk(
    String projectId,
    String gewerkId,
    String name,
  ) async {
    final gewerk = _gewerk(projectId, gewerkId);
    if (gewerk == null) return;
    gewerk.name = name;
    gewerk.updatedAt = DateTime.now();
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> removeGewerk(String projectId, String gewerkId) async {
    final project = _project(projectId);
    if (project == null) return;
    project.gewerke.removeWhere((g) => g.id == gewerkId);
    project.deletedIds[gewerkId] = DateTime.now();
    notifyListeners();
    await _persist(projectId);
  }

  // Gibt die id des neu angelegten Moduls zurück (z.B. damit direkt danach
  // eine Datei automatisch in ein frisch angelegtes File-Modul hochgeladen
  // werden kann, siehe TaskDetailScreen).
  Future<String?> addModule(
    String projectId,
    String gewerkId,
    String moduleType,
  ) async {
    final gewerk = _gewerk(projectId, gewerkId);
    if (gewerk == null) return null;
    final id = newId();
    final GewerkModule module = switch (moduleType) {
      ContactModule.moduleType => ContactModule(id),
      TodoModule.moduleType => TodoModule(id),
      FileModule.moduleType => FileModule(id),
      FinanceModule.moduleType => FinanceModule(id),
      _ => throw ArgumentError('Unbekannter Modultyp: $moduleType'),
    };
    gewerk.modules.add(module);
    notifyListeners();
    await _persist(projectId);
    return id;
  }

  Future<void> removeModule(
    String projectId,
    String gewerkId,
    String moduleId,
  ) async {
    final project = _project(projectId);
    final gewerk = _gewerk(projectId, gewerkId);
    if (project == null || gewerk == null) return;
    gewerk.modules.removeWhere((m) => m.id == moduleId);
    project.deletedIds[moduleId] = DateTime.now();
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> renameModule(
    String projectId,
    String gewerkId,
    String moduleId,
    String label,
  ) async {
    final module = _module(projectId, gewerkId, moduleId);
    if (module == null) return;
    module.label = label;
    module.updatedAt = DateTime.now();
    notifyListeners();
    await _persist(projectId);
  }

  // Frei per Drag&Drop sortierbare Module innerhalb eines Gewerks (analog
  // zu updateTabOrder für die Reiter-Leiste). newIndex kommt bereits
  // "post-removal" an (siehe ReorderableListView.onReorderItem), also ohne
  // die sonst nötige oldIndex/newIndex-Korrektur.
  Future<void> reorderModules(
    String projectId,
    String gewerkId,
    int oldIndex,
    int newIndex,
  ) async {
    final gewerk = _gewerk(projectId, gewerkId);
    if (gewerk == null) return;
    final module = gewerk.modules.removeAt(oldIndex);
    gewerk.modules.insert(newIndex, module);
    gewerk.updatedAt = DateTime.now();
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> addTaskToTodoModule(
    String projectId,
    String gewerkId,
    String moduleId,
    Task task,
  ) async {
    final module = _todoModule(projectId, gewerkId, moduleId);
    if (module == null) return;
    module.tasks.add(task);
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> updateTaskStatus(
    String projectId,
    String gewerkId,
    String moduleId,
    String taskId, {
    required String actor,
  }) async {
    final project = _project(projectId);
    final module = _todoModule(projectId, gewerkId, moduleId);
    if (project == null || module == null) return;
    final task = _task(module, taskId);
    if (task == null) return;
    if (task.status == 'offen') {
      task.status = project.skipPartialStatus ? 'erledigt' : 'teilweise';
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
    await _persist(projectId);
  }

  Future<void> shiftTaskDueDate(
    String projectId,
    String gewerkId,
    String moduleId,
    String taskId, {
    required String actor,
  }) async {
    final module = _todoModule(projectId, gewerkId, moduleId);
    if (module == null) return;
    final task = _task(module, taskId);
    if (task == null || task.dueDate == null) return;
    task.dueDate = task.dueDate!.add(const Duration(days: 1));
    task.updatedAt = DateTime.now();
    task.history
        .add(AuditEntry(kurzzeichen: actor, action: 'Fälligkeit verschoben'));
    notifyListeners();
    await _persist(projectId);
  }

  // Verschiebt um die in den Projekt-Optionen eingestellte Anzahl Tage
  // (Standard 3) und rückt danach auf den nächsten Werktag weiter, falls
  // das Ergebnis auf einen Sonntag oder Feiertag fällt.
  Future<void> shiftTaskDueDateByDefault(
    String projectId,
    String gewerkId,
    String moduleId,
    String taskId, {
    required String holidayCountry,
    required String actor,
  }) async {
    final project = _project(projectId);
    final module = _todoModule(projectId, gewerkId, moduleId);
    if (project == null || module == null) return;
    final task = _task(module, taskId);
    if (task == null || task.dueDate == null) return;
    final shifted =
        task.dueDate!.add(Duration(days: project.shiftDays));
    task.dueDate = nextWorkday(shifted, holidayCountry);
    task.updatedAt = DateTime.now();
    task.history.add(AuditEntry(
      kurzzeichen: actor,
      action: 'Fälligkeit um ${project.shiftDays} Tage verschoben',
    ));
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> archiveTask(
    String projectId,
    String gewerkId,
    String moduleId,
    String taskId, {
    required String actor,
  }) async {
    final module = _todoModule(projectId, gewerkId, moduleId);
    if (module == null) return;
    final task = _task(module, taskId);
    if (task == null) return;
    task.status = 'archiviert';
    task.updatedAt = DateTime.now();
    task.history.add(AuditEntry(kurzzeichen: actor, action: 'archiviert'));
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> renameTask(
    String projectId,
    String gewerkId,
    String moduleId,
    String taskId, {
    required String name,
    required String actor,
  }) async {
    final module = _todoModule(projectId, gewerkId, moduleId);
    if (module == null) return;
    final task = _task(module, taskId);
    if (task == null || name.trim().isEmpty) return;
    task.name = name.trim();
    task.updatedAt = DateTime.now();
    task.history.add(AuditEntry(kurzzeichen: actor, action: 'umbenannt'));
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> updateTaskDescription(
    String projectId,
    String gewerkId,
    String moduleId,
    String taskId, {
    required String description,
    required String actor,
  }) async {
    final module = _todoModule(projectId, gewerkId, moduleId);
    if (module == null) return;
    final task = _task(module, taskId);
    if (task == null) return;
    task.description = description.trim();
    task.updatedAt = DateTime.now();
    task.history
        .add(AuditEntry(kurzzeichen: actor, action: 'Beschreibung geändert'));
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> setTaskHighPriority(
    String projectId,
    String gewerkId,
    String moduleId,
    String taskId, {
    required bool isHighPriority,
    required String actor,
  }) async {
    final module = _todoModule(projectId, gewerkId, moduleId);
    if (module == null) return;
    final task = _task(module, taskId);
    if (task == null) return;
    task.isHighPriority = isHighPriority;
    task.updatedAt = DateTime.now();
    task.history.add(AuditEntry(
      kurzzeichen: actor,
      action: isHighPriority ? 'als Prio markiert' : 'Prio entfernt',
    ));
    notifyListeners();
    await _persist(projectId);
  }

  // dueDate: null entfernt die Fälligkeit. Direktes Setzen (im Unterschied
  // zu shiftTaskDueDate/-ByDefault, die relativ zum bisherigen Datum
  // verschieben) für die Bearbeitung im Aufgaben-Detail.
  Future<void> setTaskDueDate(
    String projectId,
    String gewerkId,
    String moduleId,
    String taskId, {
    required DateTime? dueDate,
    required String actor,
  }) async {
    final module = _todoModule(projectId, gewerkId, moduleId);
    if (module == null) return;
    final task = _task(module, taskId);
    if (task == null) return;
    task.dueDate = dueDate;
    task.updatedAt = DateTime.now();
    task.history.add(AuditEntry(
      kurzzeichen: actor,
      action: dueDate == null ? 'Fälligkeit entfernt' : 'Fälligkeit gesetzt',
    ));
    notifyListeners();
    await _persist(projectId);
  }

  // Direktes Setzen eines Status (im Unterschied zu updateTaskStatus, das
  // offen -> teilweise -> erledigt -> offen durchschaltet) für die Auswahl
  // im Aufgaben-Detail.
  Future<void> setTaskStatusDirect(
    String projectId,
    String gewerkId,
    String moduleId,
    String taskId, {
    required String status,
    required String actor,
  }) async {
    final module = _todoModule(projectId, gewerkId, moduleId);
    if (module == null) return;
    final task = _task(module, taskId);
    if (task == null || task.status == status) return;
    task.status = status;
    task.updatedAt = DateTime.now();
    task.history
        .add(AuditEntry(kurzzeichen: actor, action: 'Status geändert: $status'));
    notifyListeners();
    await _persist(projectId);
  }

  // Verknüpft eine bereits im Projekt vorhandene Datei (aus einem
  // beliebigen Gewerk) mit der Aufgabe, ohne sie ein zweites Mal
  // abzulegen - itemRefs speichert nur die (app-weit eindeutige)
  // fileEntryId. Set-Semantik über mergeFrom (siehe task.dart) macht das
  // beim Sync konfliktfrei, auch wenn zwei Geräte gleichzeitig
  // unterschiedliche Dateien verknüpfen.
  Future<void> addTaskItemRef(
    String projectId,
    String gewerkId,
    String moduleId,
    String taskId,
    String fileEntryId, {
    required String actor,
  }) async {
    final project = _project(projectId);
    final module = _todoModule(projectId, gewerkId, moduleId);
    if (project == null || module == null) return;
    final task = _task(module, taskId);
    if (task == null || task.itemRefs.contains(fileEntryId)) return;
    task.itemRefs.add(fileEntryId);
    // Löscht einen eventuell noch bestehenden lokalen Tombstone dieser
    // Verknüpfung (siehe Task.mergeFrom) - sonst würde ein erneutes
    // Verknüpfen derselben Datei nach vorherigem Entfernen beim nächsten
    // Merge sofort wieder herausgefiltert.
    project.deletedIds.remove('itemRef:$taskId:$fileEntryId');
    task.updatedAt = DateTime.now();
    task.history
        .add(AuditEntry(kurzzeichen: actor, action: 'Datei verknüpft'));
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> removeTaskItemRef(
    String projectId,
    String gewerkId,
    String moduleId,
    String taskId,
    String fileEntryId, {
    required String actor,
  }) async {
    final project = _project(projectId);
    final module = _todoModule(projectId, gewerkId, moduleId);
    if (project == null || module == null) return;
    final task = _task(module, taskId);
    if (task == null) return;
    task.itemRefs.remove(fileEntryId);
    // Tombstone, sonst würde ein Gerät, das die Aufgabe unverändert (mit
    // der alten Verknüpfung) hält, sie beim nächsten Sync-Merge einfach
    // wiederherstellen (Task.mergeFrom vereinigt itemRefs sonst als reine
    // Menge ohne Löschung zu berücksichtigen).
    project.deletedIds['itemRef:$taskId:$fileEntryId'] = DateTime.now();
    task.updatedAt = DateTime.now();
    task.history
        .add(AuditEntry(kurzzeichen: actor, action: 'Datei-Verknüpfung entfernt'));
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> addContactPerson(
    String projectId,
    String gewerkId,
    String moduleId, {
    required String name,
    String phone = '',
    required String actor,
  }) async {
    final module = _module(projectId, gewerkId, moduleId);
    if (module is! ContactModule) return;
    module.contacts.add(ContactPerson(id: newId(), name: name, phone: phone));
    module.history
        .add(AuditEntry(kurzzeichen: actor, action: 'Person hinzugefügt'));
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> updateContactPerson(
    String projectId,
    String gewerkId,
    String moduleId,
    String personId, {
    required String name,
    required String phone,
    required String actor,
  }) async {
    final module = _module(projectId, gewerkId, moduleId);
    if (module is! ContactModule) return;
    ContactPerson? person;
    for (final c in module.contacts) {
      if (c.id == personId) person = c;
    }
    if (person == null) return;
    person.name = name;
    person.phone = phone;
    person.updatedAt = DateTime.now();
    module.history.add(AuditEntry(kurzzeichen: actor, action: 'bearbeitet'));
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> removeContactPerson(
    String projectId,
    String gewerkId,
    String moduleId,
    String personId, {
    required String actor,
  }) async {
    final project = _project(projectId);
    final module = _module(projectId, gewerkId, moduleId);
    if (project == null || module is! ContactModule) return;
    module.contacts.removeWhere((c) => c.id == personId);
    project.deletedIds[personId] = DateTime.now();
    module.history
        .add(AuditEntry(kurzzeichen: actor, action: 'Person entfernt'));
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> addFileEntry(
    String projectId,
    String gewerkId,
    String moduleId,
    FileEntry entry,
  ) async {
    final module = _module(projectId, gewerkId, moduleId);
    if (module is! FileModule) return;
    module.entries.add(entry);
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> addFileVersion(
    String projectId,
    String gewerkId,
    String moduleId,
    String entryId,
    FileVersion version, {
    required String actor,
  }) async {
    final module = _module(projectId, gewerkId, moduleId);
    if (module is! FileModule) return;
    FileEntry? entry;
    for (final e in module.entries) {
      if (e.id == entryId) entry = e;
    }
    if (entry == null) return;
    entry.versions.add(version);
    entry.updatedAt = DateTime.now();
    entry.history.add(AuditEntry(
      kurzzeichen: actor,
      action: 'neue Version hochgeladen (${version.label})',
    ));
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> addImageAnnotation(
    String projectId,
    String gewerkId,
    String moduleId,
    String entryId,
    ImageAnnotation annotation,
  ) async {
    final module = _module(projectId, gewerkId, moduleId);
    if (module is! FileModule) return;
    FileEntry? entry;
    for (final e in module.entries) {
      if (e.id == entryId) entry = e;
    }
    if (entry == null) return;
    entry.annotations.add(annotation);
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> removeImageAnnotation(
    String projectId,
    String gewerkId,
    String moduleId,
    String entryId,
    String annotationId,
  ) async {
    final project = _project(projectId);
    final module = _module(projectId, gewerkId, moduleId);
    if (project == null || module is! FileModule) return;
    FileEntry? entry;
    for (final e in module.entries) {
      if (e.id == entryId) entry = e;
    }
    if (entry == null) return;
    entry.annotations.removeWhere((a) => a.id == annotationId);
    project.deletedIds[annotationId] = DateTime.now();
    notifyListeners();
    await _persist(projectId);
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
    if (project == null) return;
    final start = _dateOnly(from);
    final end = _dateOnly(to);
    final byDate = <DateTime, HelperDemand>{
      for (final d in project.helperDemands) _dateOnly(d.date): d,
    };
    for (var day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))) {
      final entry = AuditEntry(kurzzeichen: actor, action: 'Bedarf eingetragen');
      final existing = byDate[day];
      if (existing != null) {
        existing.neededCount = neededCount;
        existing.note = note;
        existing.updatedAt = DateTime.now();
        existing.history.add(entry);
      } else {
        final demand = HelperDemand(
          id: newId(),
          date: day,
          neededCount: neededCount,
          note: note,
          history: [entry],
        );
        project.helperDemands.add(demand);
        byDate[day] = demand;
      }
    }
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> removeHelperDemand(String projectId, String demandId) async {
    final project = _project(projectId);
    if (project == null) return;
    project.helperDemands.removeWhere((d) => d.id == demandId);
    project.deletedIds[demandId] = DateTime.now();
    notifyListeners();
    await _persist(projectId);
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
    if (project == null) return;
    final start = _dateOnly(from);
    final end = _dateOnly(to);
    final demandsByDate = <DateTime, HelperDemand>{
      for (final d in project.helperDemands) _dateOnly(d.date): d,
    };
    for (var day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))) {
      final HelperDemand demand;
      final existing = demandsByDate[day];
      if (existing != null) {
        demand = existing;
      } else {
        demand = HelperDemand(id: newId(), date: day, neededCount: 1);
        project.helperDemands.add(demand);
        demandsByDate[day] = demand;
      }
      demand.signups.add(HelperSignup(
        id: newId(),
        name: name,
        startTime: startTime,
        endTime: endTime,
      ));
      demand.updatedAt = DateTime.now();
      demand.history
          .add(AuditEntry(kurzzeichen: actor, action: 'Helfer eingetragen: $name'));
      _syncHelperIntoTimeTracking(project, day, name, actor);
    }
    notifyListeners();
    await _persist(projectId);
  }

  // Ist an [day] laut aktivem Arbeitszeitprofil ein Arbeitstag, trägt der
  // Helfer automatisch die daraus berechneten Stunden zur Zeitstatistik
  // BEI (statt sie zu überschreiben) – Helfer eintragen im Überblick ist
  // die einzige Erfassungsstelle, die Zeitstatistik zeigt nur die
  // Auswertung. Jeder Helfer zählt nur einmal (Prüfung über helperNames),
  // damit ein erneuter Sync (z.B. Merge) die Stunden nicht doppelt addiert.
  void _syncHelperIntoTimeTracking(
    Project project,
    DateTime day,
    String helperName,
    String actor,
  ) {
    final schedule = project.activeWorkTimeProfile?.scheduleFor(day.weekday);
    if (schedule == null) return;
    WorkDayEntry? entry;
    for (final e in project.workDayEntries) {
      if (e.date.isAtSameMomentAs(day)) entry = e;
    }
    if (entry != null) {
      if (entry.helperNames.any((p) => p.person == helperName)) return;
      entry.hours += schedule.hours;
      entry.helperNames.add(PresenceEntry(helperName));
      entry.updatedAt = DateTime.now();
      entry.history.add(AuditEntry(
        kurzzeichen: actor,
        action: 'Aus Helferbedarf übernommen: $helperName',
      ));
    } else {
      project.workDayEntries.add(WorkDayEntry(
        id: newId(),
        date: day,
        hours: schedule.hours,
        helperNames: [PresenceEntry(helperName)],
        history: [
          AuditEntry(
            kurzzeichen: actor,
            action:
                'Automatisch aus aktivem Profil erstellt (Helferbedarf: $helperName)',
          ),
        ],
      ));
    }
  }

  Future<void> removeHelperSignup(
    String projectId,
    String demandId,
    String signupId,
  ) async {
    final project = _project(projectId);
    if (project == null) return;
    HelperDemand? demand;
    for (final d in project.helperDemands) {
      if (d.id == demandId) demand = d;
    }
    if (demand == null) return;
    final removedSignups =
        demand.signups.where((s) => s.id == signupId).toList();
    demand.signups.removeWhere((s) => s.id == signupId);
    project.deletedIds[signupId] = DateTime.now();
    final day = _dateOnly(demand.date);
    final schedule = project.activeWorkTimeProfile?.scheduleFor(day.weekday);
    for (final signup in removedSignups) {
      WorkDayEntry? dayEntry;
      for (final e in project.workDayEntries) {
        if (e.date.isAtSameMomentAs(day)) dayEntry = e;
      }
      if (dayEntry == null) continue;
      final wasCounted =
          dayEntry.helperNames.any((p) => p.person == signup.name);
      dayEntry.helperNames.removeWhere((p) => p.person == signup.name);
      // Die beim Eintragen addierten Stunden (siehe
      // _syncHelperIntoTimeTracking) wieder abziehen, sonst bleibt die
      // Zeitstatistik nach dem Entfernen eines Helfers dauerhaft zu hoch.
      if (wasCounted && schedule != null) {
        dayEntry.hours =
            (dayEntry.hours - schedule.hours).clamp(0, double.infinity);
      }
      // Tombstone + frischer Zeitstempel, sonst würde ein späterer Merge
      // (z.B. wenn ein anderes Gerät zwischenzeitlich nur die Stunden
      // dieses Tages geändert hat) den entfernten Helfer aus der älteren
      // Kopie wiederherstellen.
      project.deletedIds['helper:${dayEntry.id}:${signup.name}'] =
          DateTime.now();
      dayEntry.updatedAt = DateTime.now();
    }
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> updateTimeTrackingEnabled(
    String projectId, {
    required bool enabled,
  }) async {
    final project = _project(projectId);
    if (project == null) return;
    project.timeTrackingEnabled = enabled;
    project.updatedAt = DateTime.now();
    notifyListeners();
    await _persist(projectId);
  }

  // Schalter "Ich bin auf der Baustelle" (V1): bleibt aktiv, bis er wieder
  // ausgeschaltet wird, statt täglich neu gesetzt werden zu müssen.
  Future<void> setOnSitePresence(
    String projectId, {
    required String person,
    required bool present,
  }) async {
    final project = _project(projectId);
    if (project == null) return;
    if (present) {
      PresenceEntry? existing;
      for (final e in project.onSitePresence) {
        if (e.person == person) existing = e;
      }
      if (existing == null) {
        project.onSitePresence.add(PresenceEntry(person));
      } else {
        existing.updatedAt = DateTime.now();
      }
    } else {
      project.onSitePresence.removeWhere((e) => e.person == person);
      project.deletedIds['presence:$person'] = DateTime.now();
    }
    project.updatedAt = DateTime.now();
    notifyListeners();
    await _persist(projectId);
    // Sofort für heute nachziehen, statt erst beim nächsten App-Start.
    await syncOnSitePresenceForToday(projectId, actor: person);
  }

  // Solange mindestens ein Nutzer als anwesend markiert ist, trägt jeder
  // Tag, der laut aktivem Profil ein Arbeitstag ist, automatisch dessen
  // Stunden zur Zeitstatistik BEI (statt sie zu überschreiben) – ohne dass
  // dafür ein Helfer eingetragen werden muss. Wird beim Öffnen des Projekts
  // aufgerufen (für "heute"). Jede Person zählt nur einmal (Prüfung über
  // helperNames), damit ein erneuter Sync am selben Tag (z.B. jedes
  // App-Öffnen) die Stunden nicht doppelt addiert.
  Future<void> syncOnSitePresenceForToday(
    String projectId, {
    required String actor,
  }) async {
    final project = _project(projectId);
    if (project == null || project.onSitePresence.isEmpty) return;
    final today = _dateOnly(DateTime.now());
    final schedule = project.activeWorkTimeProfile?.scheduleFor(today.weekday);
    if (schedule == null) return;

    WorkDayEntry? entry;
    for (final e in project.workDayEntries) {
      if (e.date.isAtSameMomentAs(today)) entry = e;
    }
    final alreadyCounted =
        entry?.helperNames.map((p) => p.person).toSet() ?? <String>{};
    final newPresences = project.onSitePresence
        .where((p) => !alreadyCounted.contains(p.person))
        .toList();
    if (newPresences.isEmpty) return;

    final isNewEntry = entry == null;
    entry ??= WorkDayEntry(id: newId(), date: today, hours: 0);
    for (final presence in newPresences) {
      entry.helperNames.add(PresenceEntry(presence.person));
      entry.hours += schedule.hours;
    }
    if (isNewEntry) project.workDayEntries.add(entry);
    entry.updatedAt = DateTime.now();
    entry.history
        .add(AuditEntry(kurzzeichen: actor, action: 'Anwesenheit synchronisiert'));
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> updateExtendedTimeCalendar(
    String projectId, {
    required bool enabled,
  }) async {
    final project = _project(projectId);
    if (project == null) return;
    project.extendedTimeCalendar = enabled;
    project.updatedAt = DateTime.now();
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> addWorkTimeProfile(
    String projectId,
    WorkTimeProfile profile,
  ) async {
    final project = _project(projectId);
    if (project == null) return;
    project.workTimeProfiles.add(profile);
    notifyListeners();
    await _persist(projectId);
  }

  // Ersetzt ein bestehendes Profil (gleiche id) durch [profile].
  Future<void> updateWorkTimeProfile(
    String projectId,
    WorkTimeProfile profile,
  ) async {
    final project = _project(projectId);
    if (project == null) return;
    final profiles = project.workTimeProfiles;
    final index = profiles.indexWhere((p) => p.id == profile.id);
    if (index == -1) return;
    profiles[index] = profile;
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> removeWorkTimeProfile(
    String projectId,
    String profileId,
  ) async {
    final project = _project(projectId);
    if (project == null) return;
    project.workTimeProfiles.removeWhere((p) => p.id == profileId);
    project.deletedIds[profileId] = DateTime.now();
    if (project.activeWorkTimeProfileId == profileId) {
      project.activeWorkTimeProfileId = null;
    }
    project.updatedAt = DateTime.now();
    notifyListeners();
    await _persist(projectId);
  }

  // Genau ein Profil kann gleichzeitig aktiv sein (Radiobox in den
  // Profilen). profileId: null deaktiviert das aktuell aktive Profil.
  Future<void> setActiveWorkTimeProfile(
    String projectId, {
    required String? profileId,
  }) async {
    final project = _project(projectId);
    if (project == null) return;
    project.activeWorkTimeProfileId = profileId;
    project.updatedAt = DateTime.now();
    notifyListeners();
    await _persist(projectId);
  }

  // Manuelles "Zeit erfassen": wendet ein Arbeitszeitprofil auf jeden Tag im
  // Zeitraum [from, to] an und ADDIERT die daraus berechneten Stunden zu
  // bereits an diesem Tag erfassten Stunden (z.B. aus "Helfer eintragen"
  // oder "Ich bin auf der Baustelle") dazu, statt sie zu überschreiben –
  // so bildet ein zusätzlich/später/früher hinzukommender Helfer eine
  // eigene, additive Erfassung ab. Wochentage ohne Zeitplan im Profil
  // werden übersprungen (arbeitsfrei). Anders als die automatischen
  // Sync-Pfade (Helferbedarf, Anwesenheit) ist dies eine bewusste,
  // wiederholbare Nutzeraktion – mehrfaches Anwenden addiert entsprechend
  // mehrfach, ganz analog zu einem manuell mehrfach hinzugefügten
  // Finanz-Eintrag.
  Future<void> applyWorkTimeProfile(
    String projectId, {
    required WorkTimeProfile profile,
    required DateTime from,
    required DateTime to,
    required String actor,
  }) async {
    final project = _project(projectId);
    if (project == null) return;
    final start = _dateOnly(from);
    final end = _dateOnly(to);
    final byDate = <DateTime, WorkDayEntry>{
      for (final e in project.workDayEntries) _dateOnly(e.date): e,
    };
    for (var day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))) {
      final schedule = profile.scheduleFor(day.weekday);
      if (schedule == null) continue;
      final auditEntry = AuditEntry(
        kurzzeichen: actor,
        action: 'Profil "${profile.name}" angewendet (+${schedule.hours}h)',
      );
      final existing = byDate[day];
      if (existing != null) {
        existing.hours += schedule.hours;
        existing.updatedAt = DateTime.now();
        existing.history.add(auditEntry);
      } else {
        final entry = WorkDayEntry(
          id: newId(),
          date: day,
          hours: schedule.hours,
          history: [auditEntry],
        );
        project.workDayEntries.add(entry);
        byDate[day] = entry;
      }
    }
    notifyListeners();
    await _persist(projectId);
  }

  // Manuelle Korrektur eines bereits erfassten Tages im Zeitstatistik-
  // Kalender: setzt die Stunden direkt (im Gegensatz zu den additiven
  // Erfassungswegen oben) auf den angegebenen Wert, um z.B. eine
  // versehentliche Mehrfach-Erfassung wieder geradezurücken.
  Future<void> updateWorkDayEntryHours(
    String projectId,
    String entryId, {
    required double hours,
    required String actor,
  }) async {
    final project = _project(projectId);
    if (project == null) return;
    WorkDayEntry? entry;
    for (final e in project.workDayEntries) {
      if (e.id == entryId) entry = e;
    }
    if (entry == null) return;
    entry.hours = hours;
    entry.updatedAt = DateTime.now();
    entry.history
        .add(AuditEntry(kurzzeichen: actor, action: 'Stunden korrigiert'));
    notifyListeners();
    await _persist(projectId);
  }

  // Entfernt einen einzelnen Helfer aus einem bereits erfassten Tag, ohne
  // die Stunden anzupassen (reine Korrektur der Namensliste, z.B. wenn
  // jemand versehentlich für den falschen Tag eingetragen wurde) - anders
  // als removeHelperSignup, das zum passenden Helferbedarf-Eintrag gehört.
  Future<void> removeWorkDayHelper(
    String projectId,
    String entryId,
    String person,
  ) async {
    final project = _project(projectId);
    if (project == null) return;
    WorkDayEntry? entry;
    for (final e in project.workDayEntries) {
      if (e.id == entryId) entry = e;
    }
    if (entry == null) return;
    entry.helperNames.removeWhere((p) => p.person == person);
    project.deletedIds['helper:$entryId:$person'] = DateTime.now();
    entry.updatedAt = DateTime.now();
    notifyListeners();
    await _persist(projectId);
  }

  // Löscht einen kompletten erfassten Tag (Stunden + Helferliste), z.B. um
  // eine versehentliche Erfassung rückgängig zu machen.
  Future<void> removeWorkDayEntry(String projectId, String entryId) async {
    final project = _project(projectId);
    if (project == null) return;
    project.workDayEntries.removeWhere((e) => e.id == entryId);
    project.deletedIds[entryId] = DateTime.now();
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> updateFinanceEnabled(
    String projectId, {
    required bool enabled,
  }) async {
    final project = _project(projectId);
    if (project == null) return;
    project.financeEnabled = enabled;
    project.updatedAt = DateTime.now();
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> updateTabOrder(String projectId, List<String> tabOrder) async {
    final project = _project(projectId);
    if (project == null) return;
    project.tabOrder = tabOrder;
    project.updatedAt = DateTime.now();
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> addFinanceEntry(String projectId, FinanceEntry entry) async {
    final project = _project(projectId);
    if (project == null) return;
    project.financeEntries.add(entry);
    notifyListeners();
    await _persist(projectId);
  }

  // Ersetzt einen bestehenden Eintrag (gleiche id) durch [entry].
  Future<void> updateFinanceEntry(String projectId, FinanceEntry entry) async {
    final project = _project(projectId);
    if (project == null) return;
    final index = project.financeEntries.indexWhere((e) => e.id == entry.id);
    if (index == -1) return;
    project.financeEntries[index] = entry;
    notifyListeners();
    await _persist(projectId);
  }

  Future<void> removeFinanceEntry(String projectId, String entryId) async {
    final project = _project(projectId);
    if (project == null) return;
    project.financeEntries.removeWhere((e) => e.id == entryId);
    project.deletedIds[entryId] = DateTime.now();
    notifyListeners();
    await _persist(projectId);
  }
}
