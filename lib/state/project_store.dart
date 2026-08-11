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
import '../models/time_tracking.dart';
import '../repositories/project_repository.dart';
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
    NotificationService.instance.syncForProjects(projects);

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
    NotificationService.instance.syncForProjects(projects);
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

  Future<void> updatePriorityWarningSettings(
    String projectId, {
    required int priorityWarningDays,
    required bool notifyOnPriorityWarning,
  }) async {
    final project = _project(projectId);
    project.priorityWarningDays = priorityWarningDays;
    project.notifyOnPriorityWarning = notifyOnPriorityWarning;
    notifyListeners();
    await _persist();
  }

  Future<void> updateSkipPartialStatus(
    String projectId, {
    required bool skipPartialStatus,
  }) async {
    _project(projectId).skipPartialStatus = skipPartialStatus;
    notifyListeners();
    await _persist();
  }

  Future<void> updateShiftDays(
    String projectId, {
    required int shiftDays,
  }) async {
    _project(projectId).shiftDays = shiftDays;
    notifyListeners();
    await _persist();
  }

  Future<void> updateArchiveSettings(
    String projectId, {
    required int archiveAfterDays,
    required bool moveCompletedToArchiveToo,
  }) async {
    final project = _project(projectId);
    project.archiveAfterDays = archiveAfterDays;
    project.moveCompletedToArchiveToo = moveCompletedToArchiveToo;
    notifyListeners();
    await _persist();
  }

  Future<void> updateDeleteArchivedSettings(
    String projectId, {
    required bool deleteArchivedTasksPermanently,
    required int deleteArchivedAfterDays,
  }) async {
    final project = _project(projectId);
    project.deleteArchivedTasksPermanently = deleteArchivedTasksPermanently;
    project.deleteArchivedAfterDays = deleteArchivedAfterDays;
    notifyListeners();
    await _persist();
  }

  // Entfernt archivierte (nicht erledigte) Aufgaben endgültig, sobald sie
  // insgesamt archiveAfterDays + deleteArchivedAfterDays Tage alt sind –
  // nur wenn deleteArchivedTasksPermanently aktiv ist. Wird beim Öffnen
  // eines Projekts aufgerufen (siehe GewerkeScreen.initState).
  Future<void> cleanupExpiredArchivedTasks(String projectId) async {
    final project = _project(projectId);
    if (!project.deleteArchivedTasksPermanently) return;
    final threshold =
        project.archiveAfterDays + project.deleteArchivedAfterDays;
    var changed = false;
    for (final gewerk in project.gewerke) {
      for (final module in gewerk.modules.whereType<TodoModule>()) {
        final before = module.tasks.length;
        module.tasks.removeWhere((task) =>
            task.status == 'archiviert' &&
            DateTime.now().difference(task.updatedAt).inDays >= threshold);
        if (module.tasks.length != before) changed = true;
      }
    }
    if (!changed) return;
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
    final project = _project(projectId);
    final task = _todoModule(projectId, gewerkId, moduleId)
        .tasks
        .firstWhere((t) => t.id == taskId);
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
    final task = _todoModule(projectId, gewerkId, moduleId)
        .tasks
        .firstWhere((t) => t.id == taskId);
    if (task.dueDate == null) {
      return;
    }
    final shifted =
        task.dueDate!.add(Duration(days: project.shiftDays));
    task.dueDate = nextWorkday(shifted, holidayCountry);
    task.updatedAt = DateTime.now();
    task.history.add(AuditEntry(
      kurzzeichen: actor,
      action: 'Fälligkeit um ${project.shiftDays} Tage verschoben',
    ));
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

  Future<void> addContactPerson(
    String projectId,
    String gewerkId,
    String moduleId, {
    required String name,
    String phone = '',
    required String actor,
  }) async {
    final module = _module(projectId, gewerkId, moduleId) as ContactModule;
    module.contacts.add(ContactPerson(id: newId(), name: name, phone: phone));
    module.history
        .add(AuditEntry(kurzzeichen: actor, action: 'Person hinzugefügt'));
    notifyListeners();
    await _persist();
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
    final module = _module(projectId, gewerkId, moduleId) as ContactModule;
    final person = module.contacts.firstWhere((c) => c.id == personId);
    person.name = name;
    person.phone = phone;
    module.history.add(AuditEntry(kurzzeichen: actor, action: 'bearbeitet'));
    notifyListeners();
    await _persist();
  }

  Future<void> removeContactPerson(
    String projectId,
    String gewerkId,
    String moduleId,
    String personId, {
    required String actor,
  }) async {
    final module = _module(projectId, gewerkId, moduleId) as ContactModule;
    module.contacts.removeWhere((c) => c.id == personId);
    module.history
        .add(AuditEntry(kurzzeichen: actor, action: 'Person entfernt'));
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
      _syncHelperIntoTimeTracking(project, day, name, actor);
    }
    notifyListeners();
    await _persist();
  }

  // Ist an [day] laut aktivem Arbeitszeitprofil ein Arbeitstag, wird der
  // Helfer automatisch (mit den daraus berechneten Stunden) in die
  // Zeitstatistik übernommen – Helfer eintragen im Überblick ist die
  // einzige Erfassungsstelle, die Zeitstatistik zeigt nur die Auswertung.
  void _syncHelperIntoTimeTracking(
    Project project,
    DateTime day,
    String helperName,
    String actor,
  ) {
    final schedule = project.activeWorkTimeProfile?.scheduleFor(day.weekday);
    if (schedule == null) return;
    final existing =
        project.workDayEntries.where((e) => e.date.isAtSameMomentAs(day));
    if (existing.isNotEmpty) {
      final entry = existing.first;
      entry.hours = schedule.hours;
      if (!entry.helperNames.contains(helperName)) {
        entry.helperNames.add(helperName);
      }
      entry.history.add(AuditEntry(
        kurzzeichen: actor,
        action: 'Aus Helferbedarf übernommen: $helperName',
      ));
    } else {
      project.workDayEntries.add(WorkDayEntry(
        id: newId(),
        date: day,
        hours: schedule.hours,
        helperNames: [helperName],
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
    final demand = project.helperDemands.firstWhere((d) => d.id == demandId);
    final removedSignups =
        demand.signups.where((s) => s.id == signupId).toList();
    demand.signups.removeWhere((s) => s.id == signupId);
    for (final signup in removedSignups) {
      final day = _dateOnly(demand.date);
      final entries =
          project.workDayEntries.where((e) => e.date.isAtSameMomentAs(day));
      if (entries.isNotEmpty) {
        entries.first.helperNames.remove(signup.name);
      }
    }
    notifyListeners();
    await _persist();
  }

  Future<void> updateTimeTrackingEnabled(
    String projectId, {
    required bool enabled,
  }) async {
    _project(projectId).timeTrackingEnabled = enabled;
    notifyListeners();
    await _persist();
  }

  // Schalter "Ich bin auf der Baustelle" (V1): bleibt aktiv, bis er wieder
  // ausgeschaltet wird, statt täglich neu gesetzt werden zu müssen.
  Future<void> setOnSitePresence(
    String projectId, {
    required String person,
    required bool present,
  }) async {
    final project = _project(projectId);
    if (present) {
      if (!project.onSitePresence.contains(person)) {
        project.onSitePresence.add(person);
      }
    } else {
      project.onSitePresence.remove(person);
    }
    notifyListeners();
    await _persist();
    // Sofort für heute nachziehen, statt erst beim nächsten App-Start.
    await syncOnSitePresenceForToday(projectId, actor: person);
  }

  // Solange mindestens ein Nutzer als anwesend markiert ist, wird jeder Tag,
  // der laut aktivem Profil ein Arbeitstag ist, automatisch in die
  // Zeitstatistik übernommen – ohne dass dafür ein Helfer eingetragen
  // werden muss. Wird beim Öffnen des Projekts aufgerufen (für "heute").
  Future<void> syncOnSitePresenceForToday(
    String projectId, {
    required String actor,
  }) async {
    final project = _project(projectId);
    if (project.onSitePresence.isEmpty) return;
    final today = _dateOnly(DateTime.now());
    final schedule = project.activeWorkTimeProfile?.scheduleFor(today.weekday);
    if (schedule == null) return;

    final existing =
        project.workDayEntries.where((e) => e.date.isAtSameMomentAs(today));
    final WorkDayEntry entry;
    var changed = false;
    if (existing.isNotEmpty) {
      entry = existing.first;
      if (entry.hours != schedule.hours) {
        entry.hours = schedule.hours;
        changed = true;
      }
    } else {
      entry = WorkDayEntry(id: newId(), date: today, hours: schedule.hours);
      project.workDayEntries.add(entry);
      changed = true;
    }
    for (final person in project.onSitePresence) {
      if (!entry.helperNames.contains(person)) {
        entry.helperNames.add(person);
        changed = true;
      }
    }
    if (!changed) return;
    entry.history
        .add(AuditEntry(kurzzeichen: actor, action: 'Anwesenheit synchronisiert'));
    notifyListeners();
    await _persist();
  }

  Future<void> updateExtendedTimeCalendar(
    String projectId, {
    required bool enabled,
  }) async {
    _project(projectId).extendedTimeCalendar = enabled;
    notifyListeners();
    await _persist();
  }

  Future<void> addWorkTimeProfile(
    String projectId,
    WorkTimeProfile profile,
  ) async {
    _project(projectId).workTimeProfiles.add(profile);
    notifyListeners();
    await _persist();
  }

  // Ersetzt ein bestehendes Profil (gleiche id) durch [profile].
  Future<void> updateWorkTimeProfile(
    String projectId,
    WorkTimeProfile profile,
  ) async {
    final profiles = _project(projectId).workTimeProfiles;
    final index = profiles.indexWhere((p) => p.id == profile.id);
    if (index == -1) return;
    profiles[index] = profile;
    notifyListeners();
    await _persist();
  }

  Future<void> removeWorkTimeProfile(
    String projectId,
    String profileId,
  ) async {
    final project = _project(projectId);
    project.workTimeProfiles.removeWhere((p) => p.id == profileId);
    if (project.activeWorkTimeProfileId == profileId) {
      project.activeWorkTimeProfileId = null;
    }
    notifyListeners();
    await _persist();
  }

  // Genau ein Profil kann gleichzeitig aktiv sein (Radiobox in den
  // Profilen). profileId: null deaktiviert das aktuell aktive Profil.
  Future<void> setActiveWorkTimeProfile(
    String projectId, {
    required String? profileId,
  }) async {
    _project(projectId).activeWorkTimeProfileId = profileId;
    notifyListeners();
    await _persist();
  }

  // Wendet ein Arbeitszeitprofil auf jeden Tag im Zeitraum [from, to] an:
  // Wochentage ohne Zeitplan im Profil werden übersprungen (arbeitsfrei).
  // Bereits erfasste Tage werden mit den neuen Stunden überschrieben, ihre
  // Helferliste bleibt erhalten.
  Future<void> applyWorkTimeProfile(
    String projectId, {
    required WorkTimeProfile profile,
    required DateTime from,
    required DateTime to,
    required String actor,
  }) async {
    final project = _project(projectId);
    final start = _dateOnly(from);
    final end = _dateOnly(to);
    for (var day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))) {
      final schedule = profile.scheduleFor(day.weekday);
      if (schedule == null) continue;
      final entry = AuditEntry(
        kurzzeichen: actor,
        action: 'Profil "${profile.name}" angewendet',
      );
      final existing =
          project.workDayEntries.where((e) => e.date.isAtSameMomentAs(day));
      if (existing.isNotEmpty) {
        existing.first.hours = schedule.hours;
        existing.first.history.add(entry);
      } else {
        project.workDayEntries.add(WorkDayEntry(
          id: newId(),
          date: day,
          hours: schedule.hours,
          history: [entry],
        ));
      }
    }
    notifyListeners();
    await _persist();
  }

  // Legt einen Arbeitstag manuell an oder überschreibt einen bestehenden
  // (z.B. um einen aus einem Profil erzeugten Tag im Kalender nachzujustieren).
}
