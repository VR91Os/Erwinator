import 'finance_entry.dart';
import 'gewerk.dart';
import 'helper_demand.dart';
import 'presence_entry.dart';
import 'time_tracking.dart';
import '../utils/id_merge.dart';

class Project {
  String id;
  String name;
  String address;
  List<Gewerk> gewerke;

  // 'neubau' | 'sanierung' | '' (z.B. bei importierten Alt-Projekten).
  // Steuert nur die Start-Gewerke beim Anlegen, nicht weiter erzwungen.
  String projectType;

  // Helferbedarf des gesamten Projekts (Projekt-weit statt je Gewerk),
  // erscheint im Überblickskalender.
  List<HelperDemand> helperDemands;

  // Steuern, welche Aufgaben beim Projekt-Export zusätzlich als
  // .ics-Kalenderdatei mit exportiert werden.
  bool exportAllDatedTodos;
  bool exportPriorityTasks;

  // Anzahl Tage vor Fälligkeit, ab der ein Gewerk-Reiter (und bei
  // Betroffenheit auch der Überblick-Reiter) hellrot markiert wird, wenn
  // eine offene Prio-Aufgabe die Schwelle erreicht.
  int priorityWarningDays;
  // Zusätzlich eine Push-Nachricht anzeigen, sobald die Warnschwelle
  // erreicht wird (auch wenn die App geschlossen ist).
  bool notifyOnPriorityWarning;

  // Wenn aktiv, springt der Status einer offenen Aufgabe beim Antippen
  // direkt auf "erledigt" – der Zwischenschritt "teilweise erledigt" wird
  // übersprungen.
  bool skipPartialStatus;

  // Anzahl Tage, um die der zusätzliche "Fälligkeit verschieben"-Button an
  // Aufgaben die Fälligkeit vorschlägt (landet nie auf Sonntag/Feiertag,
  // siehe utils/holidays.dart).
  int shiftDays;

  // Anzahl Tage nach Archivierung/Erledigung, ab der eine Aufgabe in der
  // Todo-Liste in den eingeklappten Archivbereich ganz unten wandert.
  int archiveAfterDays;
  // Wenn aktiv, gilt archiveAfterDays auch für erledigte (nicht nur
  // archivierte) Aufgaben.
  bool moveCompletedToArchiveToo;

  // Wenn aktiv, werden archivierte (nicht erledigte) Aufgaben endgültig
  // gelöscht, statt nur dauerhaft im Archivbereich zu bleiben – nach
  // insgesamt archiveAfterDays + deleteArchivedAfterDays Tagen.
  bool deleteArchivedTasksPermanently;
  int deleteArchivedAfterDays;

  // Projektweites, optionales Zeitstatistik-Modul: erfasst die gesamte am
  // Projekt gearbeitete Zeit über wiederverwendbare Arbeitszeitprofile
  // (z.B. "Kurzer Tag", "Lange Woche") und einen Tages-Kalender.
  bool timeTrackingEnabled;
  // Kalender in der Zeitstatistik zeigt Stunden/Helferanzahl direkt in der
  // Tageskachel an und erlaubt Wochen-/Jahresansicht statt nur Monat.
  bool extendedTimeCalendar;
  List<WorkTimeProfile> workTimeProfiles;
  List<WorkDayEntry> workDayEntries;
  // Höchstens ein Profil gleichzeitig aktiv (Radiobox in den Profilen).
  // Helfer, die an einem Tag eingetragen werden, dessen Wochentag im
  // aktiven Profil einen Zeitplan hat, werden automatisch mit den daraus
  // berechneten Stunden in die Zeitstatistik übernommen.
  String? activeWorkTimeProfileId;
  // Nutzer, die den Schalter "Ich bin auf der Baustelle" aktuell aktiv
  // haben (V1: einfacher, dauerhafter Anwesenheits-Status statt täglicher
  // Checkbox). Solange ein Nutzer hier eingetragen ist, zählt jeder Tag,
  // der laut aktivem Profil ein Arbeitstag ist, automatisch mit in die
  // Zeitstatistik. Jeder Eintrag trägt einen eigenen Zeitstempel (statt
  // einer reinen Namensliste), damit ein Ein-/Ausschalten auf zwei Geräten
  // beim Sync-Merge feldweise statt als Ganzes aufgelöst werden kann.
  List<PresenceEntry> onSitePresence;

  // Projektweites, optionales Finanzen-Modul: sammelt aus Angeboten/
  // Rechnungen ausgelesene bzw. manuell erfasste Beträge, referenziert die
  // Quelldatei nur über ihre IDs (kein doppeltes Ablegen). Projektweit
  // gehalten (wie workDayEntries), damit eine Gesamtübersicht über alle
  // Gewerke hinweg möglich ist; ein optionales FinanceModule pro Gewerk
  // zeigt nur eine gefilterte Sicht darauf.
  bool financeEnabled;
  List<FinanceEntry> financeEntries;

  // Vom Nutzer frei festgelegte Reihenfolge der Reiter oben in der
  // Projektansicht (Überblick, Gewerke, Dateiablage, Zeitstatistik,
  // Finanzen - als IDs). Fehlende Einträge (neues Gewerk, neu aktiviertes
  // Modul) werden von GewerkeScreen automatisch hinten angehängt, entfernte
  // (gelöschtes Gewerk) einfach ignoriert - hier wird nichts aufgeräumt.
  List<String> tabOrder;

  // Wann eines der obigen Projekt-weiten Felder zuletzt geändert wurde
  // (für den Sync-Merge, Option C).
  DateTime updatedAt;

  // Projektweite Tombstones fürs Sync-Merge: id (Gewerk, Modul, Aufgabe,
  // Kontakt, Datei-Markierung, Helfer-Zusage, Arbeitszeitprofil, ...) ->
  // Löschzeitpunkt. IDs sind app-weit eindeutig (newId()), daher reicht
  // eine einzige Map für alle verschachtelten Listen. Verhindert, dass ein
  // gelöschtes Element durch die andere Sync-Seite wiederaufersteht –
  // außer es wurde dort NACH der Löschung noch bearbeitet ("Edit schlägt
  // Delete").
  Map<String, DateTime> deletedIds;

  // ID der Zeile in der Supabase-Tabelle "shared_projects", sobald das
  // Projekt geteilt wurde. null = nur lokal, nicht geteilt.
  String? sharedId;

  Project(
    this.id,
    this.name, {
    this.address = '',
    List<Gewerk>? gewerke,
    this.projectType = '',
    List<HelperDemand>? helperDemands,
    this.exportAllDatedTodos = false,
    this.exportPriorityTasks = false,
    this.priorityWarningDays = 7,
    this.notifyOnPriorityWarning = false,
    this.skipPartialStatus = false,
    this.shiftDays = 3,
    this.archiveAfterDays = 7,
    this.moveCompletedToArchiveToo = false,
    this.deleteArchivedTasksPermanently = false,
    this.deleteArchivedAfterDays = 0,
    this.timeTrackingEnabled = false,
    this.extendedTimeCalendar = false,
    List<WorkTimeProfile>? workTimeProfiles,
    List<WorkDayEntry>? workDayEntries,
    this.activeWorkTimeProfileId,
    List<PresenceEntry>? onSitePresence,
    this.financeEnabled = false,
    List<FinanceEntry>? financeEntries,
    List<String>? tabOrder,
    DateTime? updatedAt,
    Map<String, DateTime>? deletedIds,
    this.sharedId,
  })  : gewerke = gewerke ?? [],
        helperDemands = helperDemands ?? [],
        workTimeProfiles = workTimeProfiles ?? [],
        workDayEntries = workDayEntries ?? [],
        onSitePresence = onSitePresence ?? [],
        financeEntries = financeEntries ?? [],
        tabOrder = tabOrder ?? [],
        updatedAt = updatedAt ?? DateTime.now(),
        deletedIds = deletedIds ?? {};

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'gewerke': gewerke.map((g) => g.toMap()).toList(),
        'projectType': projectType,
        'helperDemands': helperDemands.map((d) => d.toMap()).toList(),
        'exportAllDatedTodos': exportAllDatedTodos,
        'exportPriorityTasks': exportPriorityTasks,
        'priorityWarningDays': priorityWarningDays,
        'notifyOnPriorityWarning': notifyOnPriorityWarning,
        'skipPartialStatus': skipPartialStatus,
        'shiftDays': shiftDays,
        'archiveAfterDays': archiveAfterDays,
        'moveCompletedToArchiveToo': moveCompletedToArchiveToo,
        'deleteArchivedTasksPermanently': deleteArchivedTasksPermanently,
        'deleteArchivedAfterDays': deleteArchivedAfterDays,
        'timeTrackingEnabled': timeTrackingEnabled,
        'extendedTimeCalendar': extendedTimeCalendar,
        'workTimeProfiles': workTimeProfiles.map((p) => p.toMap()).toList(),
        'workDayEntries': workDayEntries.map((e) => e.toMap()).toList(),
        'activeWorkTimeProfileId': activeWorkTimeProfileId,
        'onSitePresence': onSitePresence.map((e) => e.toMap()).toList(),
        'financeEnabled': financeEnabled,
        'financeEntries': financeEntries.map((e) => e.toMap()).toList(),
        'tabOrder': tabOrder,
        'updatedAt': updatedAt.toIso8601String(),
        'deletedIds': deletedIds
            .map((id, deletedAt) => MapEntry(id, deletedAt.toIso8601String())),
        'sharedId': sharedId,
      };

  factory Project.fromMap(Map<String, dynamic> map) => Project(
        map['id'] as String,
        map['name'] as String,
        address: map['address'] as String? ?? '',
        gewerke: (map['gewerke'] as List<dynamic>? ?? [])
            .map((e) => Gewerk.fromMap(e as Map<String, dynamic>))
            .toList(),
        projectType: map['projectType'] as String? ?? '',
        helperDemands: (map['helperDemands'] as List<dynamic>? ?? [])
            .map((e) => HelperDemand.fromMap(e as Map<String, dynamic>))
            .toList(),
        exportAllDatedTodos: map['exportAllDatedTodos'] as bool? ?? false,
        exportPriorityTasks: map['exportPriorityTasks'] as bool? ?? false,
        priorityWarningDays: map['priorityWarningDays'] as int? ?? 7,
        notifyOnPriorityWarning:
            map['notifyOnPriorityWarning'] as bool? ?? false,
        skipPartialStatus: map['skipPartialStatus'] as bool? ?? false,
        shiftDays: map['shiftDays'] as int? ?? 3,
        archiveAfterDays: map['archiveAfterDays'] as int? ?? 7,
        moveCompletedToArchiveToo:
            map['moveCompletedToArchiveToo'] as bool? ?? false,
        deleteArchivedTasksPermanently:
            map['deleteArchivedTasksPermanently'] as bool? ?? false,
        deleteArchivedAfterDays: map['deleteArchivedAfterDays'] as int? ?? 0,
        timeTrackingEnabled: map['timeTrackingEnabled'] as bool? ?? false,
        extendedTimeCalendar: map['extendedTimeCalendar'] as bool? ?? false,
        workTimeProfiles: (map['workTimeProfiles'] as List<dynamic>? ?? [])
            .map((e) => WorkTimeProfile.fromMap(e as Map<String, dynamic>))
            .toList(),
        workDayEntries: (map['workDayEntries'] as List<dynamic>? ?? [])
            .map((e) => WorkDayEntry.fromMap(e as Map<String, dynamic>))
            .toList(),
        activeWorkTimeProfileId: map['activeWorkTimeProfileId'] as String?,
        onSitePresence: (map['onSitePresence'] as List<dynamic>? ?? [])
            .map((e) => PresenceEntry.fromAny(e))
            .toList(),
        financeEnabled: map['financeEnabled'] as bool? ?? false,
        financeEntries: (map['financeEntries'] as List<dynamic>? ?? [])
            .map((e) => FinanceEntry.fromMap(e as Map<String, dynamic>))
            .toList(),
        tabOrder: (map['tabOrder'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        updatedAt: map['updatedAt'] == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.parse(map['updatedAt'] as String),
        deletedIds: (map['deletedIds'] as Map<String, dynamic>? ?? {}).map(
          (id, deletedAt) => MapEntry(id, DateTime.parse(deletedAt as String)),
        ),
        sharedId: map['sharedId'] as String?,
      );

  // Tombstones sammeln sich sonst über die gesamte Projektlaufzeit
  // unbegrenzt an (jede Löschung fügt einen Eintrag hinzu, der nie entfernt
  // wird) und vergrößern die JSON-Payload lokal und bei jedem Sync-Push
  // immer weiter. Nach dieser Frist ist "Edit schlägt Delete" ohnehin nicht
  // mehr relevant: kein Gerät dürfte so lange offline sein, dass es noch
  // eine ältere, unbearbeitete Kopie des gelöschten Elements hält.
  void pruneTombstones({Duration retention = const Duration(days: 180)}) {
    final cutoff = DateTime.now().subtract(retention);
    deletedIds.removeWhere((_, deletedAt) => deletedAt.isBefore(cutoff));
  }

  WorkTimeProfile? get activeWorkTimeProfile {
    final id = activeWorkTimeProfileId;
    if (id == null) return null;
    for (final p in workTimeProfiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  // Sync-Merge (Option C), siehe lib/utils/id_merge.dart: statt das ganze
  // Projekt bei jeder Änderung 1:1 zu ersetzen, werden Gewerke/Module/
  // Aufgaben/Kontakte/Dateien/Helferbedarfe/Arbeitszeit-Daten per ID
  // zusammengeführt. Nur die Projekt-weiten Einstellungsfelder (oben,
  // exportAllDatedTodos etc.) werden als Ganzes von der neueren Seite
  // übernommen – Konflikte dort sind selten und weniger kritisch als der
  // Verlust einzelner Aufgaben/Dateien.
  Project mergeFrom(Project remote) {
    final tombstones = <String, DateTime>{...deletedIds};
    for (final entry in remote.deletedIds.entries) {
      final existing = tombstones[entry.key];
      if (existing == null || entry.value.isAfter(existing)) {
        tombstones[entry.key] = entry.value;
      }
    }

    final winner = newerOf(this, remote, (p) => p.updatedAt);

    return Project(
      id,
      winner.name,
      address: winner.address,
      projectType: winner.projectType,
      exportAllDatedTodos: winner.exportAllDatedTodos,
      exportPriorityTasks: winner.exportPriorityTasks,
      priorityWarningDays: winner.priorityWarningDays,
      notifyOnPriorityWarning: winner.notifyOnPriorityWarning,
      skipPartialStatus: winner.skipPartialStatus,
      shiftDays: winner.shiftDays,
      archiveAfterDays: winner.archiveAfterDays,
      moveCompletedToArchiveToo: winner.moveCompletedToArchiveToo,
      deleteArchivedTasksPermanently: winner.deleteArchivedTasksPermanently,
      deleteArchivedAfterDays: winner.deleteArchivedAfterDays,
      timeTrackingEnabled: winner.timeTrackingEnabled,
      extendedTimeCalendar: winner.extendedTimeCalendar,
      activeWorkTimeProfileId: winner.activeWorkTimeProfileId,
      financeEnabled: winner.financeEnabled,
      tabOrder: winner.tabOrder,
      updatedAt: winner.updatedAt,
      deletedIds: tombstones,
      sharedId: sharedId ?? remote.sharedId,
      gewerke: mergeById<Gewerk>(
        local: gewerke,
        remote: remote.gewerke,
        idOf: (g) => g.id,
        updatedAtOf: (g) => g.updatedAt,
        combine: (l, r) => l.mergeFrom(r, tombstones: tombstones),
        tombstones: tombstones,
      ),
      helperDemands: mergeById<HelperDemand>(
        local: helperDemands,
        remote: remote.helperDemands,
        idOf: (d) => d.id,
        updatedAtOf: (d) => d.updatedAt,
        combine: (l, r) => l.mergeFrom(r, tombstones),
        tombstones: tombstones,
      ),
      workTimeProfiles: mergeById<WorkTimeProfile>(
        local: workTimeProfiles,
        remote: remote.workTimeProfiles,
        idOf: (p) => p.id,
        updatedAtOf: (p) => p.updatedAt,
        combine: (l, r) => l.mergeFrom(r),
        tombstones: tombstones,
      ),
      workDayEntries: mergeById<WorkDayEntry>(
        local: workDayEntries,
        remote: remote.workDayEntries,
        idOf: (e) => e.id,
        updatedAtOf: (e) => e.updatedAt,
        combine: (l, r) => l.mergeFrom(r, tombstones),
        tombstones: tombstones,
      ),
      // Feldweiser statt kompletter Merge (anders als die übrigen
      // Projekt-weiten Felder oben, die als Ganzes von der neueren Seite
      // übernommen werden): sonst würde ein gleichzeitiges An-/Abmelden
      // zweier Nutzer auf zwei Geräten dazu führen, dass einer der beiden
      // Zustände beim Merge komplett verloren geht.
      onSitePresence: mergeById<PresenceEntry>(
        local: onSitePresence,
        remote: remote.onSitePresence,
        idOf: (e) => 'presence:${e.person}',
        updatedAtOf: (e) => e.updatedAt,
        combine: (l, r) => newerOf(l, r, (e) => e.updatedAt),
        tombstones: tombstones,
      ),
      financeEntries: mergeById<FinanceEntry>(
        local: financeEntries,
        remote: remote.financeEntries,
        idOf: (e) => e.id,
        updatedAtOf: (e) => e.updatedAt,
        combine: (l, r) => l.mergeFrom(r),
        tombstones: tombstones,
      ),
    );
  }
}
