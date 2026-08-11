import 'gewerk.dart';
import 'helper_demand.dart';
import 'time_tracking.dart';

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
  // Namen der Nutzer, die den Schalter "Ich bin auf der Baustelle"
  // aktuell aktiv haben (V1: einfacher, dauerhafter Anwesenheits-Status
  // statt täglicher Checkbox). Solange ein Name hier eingetragen ist,
  // zählt jeder Tag, der laut aktivem Profil ein Arbeitstag ist,
  // automatisch mit in die Zeitstatistik.
  List<String> onSitePresence;

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
    List<String>? onSitePresence,
    this.sharedId,
  })  : gewerke = gewerke ?? [],
        helperDemands = helperDemands ?? [],
        workTimeProfiles = workTimeProfiles ?? [],
        workDayEntries = workDayEntries ?? [],
        onSitePresence = onSitePresence ?? [];

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
        'onSitePresence': onSitePresence,
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
            .map((e) => e as String)
            .toList(),
        sharedId: map['sharedId'] as String?,
      );

  WorkTimeProfile? get activeWorkTimeProfile {
    final id = activeWorkTimeProfileId;
    if (id == null) return null;
    for (final p in workTimeProfiles) {
      if (p.id == id) return p;
    }
    return null;
  }
}
