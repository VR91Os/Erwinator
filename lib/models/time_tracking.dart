import 'audit_entry.dart';
import 'presence_entry.dart';
import '../utils/id_merge.dart';

int _minutesOf(String hhmm) {
  final parts = hhmm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

// Zeitplan für einen einzelnen Wochentag innerhalb eines Arbeitszeitprofils.
// weekday: 1 (Montag) .. 7 (Sonntag), analog zu DateTime.weekday. Ein
// Wochentag ohne Eintrag im Profil gilt als arbeitsfrei und wird beim
// Anwenden des Profils übersprungen.
class WeekdaySchedule {
  int weekday;
  String startTime; // "HH:MM"
  String endTime; // "HH:MM"
  int breakMinutes;

  WeekdaySchedule({
    required this.weekday,
    required this.startTime,
    required this.endTime,
    this.breakMinutes = 0,
  });

  double get hours {
    final minutes = _minutesOf(endTime) - _minutesOf(startTime) - breakMinutes;
    return minutes <= 0 ? 0 : minutes / 60;
  }

  Map<String, dynamic> toMap() => {
        'weekday': weekday,
        'startTime': startTime,
        'endTime': endTime,
        'breakMinutes': breakMinutes,
      };

  factory WeekdaySchedule.fromMap(Map<String, dynamic> map) =>
      WeekdaySchedule(
        weekday: map['weekday'] as int,
        startTime: map['startTime'] as String,
        endTime: map['endTime'] as String,
        breakMinutes: map['breakMinutes'] as int? ?? 0,
      );
}

// Wiederverwendbares Arbeitszeit-Profil, z.B. "Kurzer Tag" oder "Lange
// Woche". Enthält für jeden relevanten Wochentag einen Zeitplan; Wochentage
// ohne Eintrag werden beim Anwenden auf einen Zeitraum nicht erfasst.
class WorkTimeProfile {
  String id;
  String name;
  List<WeekdaySchedule> schedules;
  DateTime updatedAt;

  WorkTimeProfile({
    required this.id,
    required this.name,
    List<WeekdaySchedule>? schedules,
    DateTime? updatedAt,
  })  : schedules = schedules ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  WeekdaySchedule? scheduleFor(int weekday) {
    for (final s in schedules) {
      if (s.weekday == weekday) return s;
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'schedules': schedules.map((s) => s.toMap()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory WorkTimeProfile.fromMap(Map<String, dynamic> map) =>
      WorkTimeProfile(
        id: map['id'] as String,
        name: map['name'] as String,
        schedules: (map['schedules'] as List<dynamic>? ?? [])
            .map((e) => WeekdaySchedule.fromMap(e as Map<String, dynamic>))
            .toList(),
        updatedAt: map['updatedAt'] == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.parse(map['updatedAt'] as String),
      );

  // Sync-Merge (Option C): wird immer als Ganzes ersetzt (siehe
  // updateWorkTimeProfile) -> neuere Seite gewinnt komplett, inkl. Zeitplan.
  WorkTimeProfile mergeFrom(WorkTimeProfile remote) =>
      newerOf(this, remote, (p) => p.updatedAt);
}

// Ein einzelner erfasster Arbeitstag am Projekt (aus einem Profil erzeugt
// oder im Kalender manuell nachjustiert), inkl. der an diesem Tag
// mitwirkenden Helfer.
class WorkDayEntry {
  String id;
  DateTime date;
  double hours;
  List<PresenceEntry> helperNames;

  // Verlauf: wer hat den Tag erfasst/angepasst.
  List<AuditEntry> history;
  DateTime updatedAt;

  WorkDayEntry({
    required this.id,
    required this.date,
    required this.hours,
    List<PresenceEntry>? helperNames,
    List<AuditEntry>? history,
    DateTime? updatedAt,
  })  : helperNames = helperNames ?? [],
        history = history ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'hours': hours,
        'helperNames': helperNames.map((e) => e.toMap()).toList(),
        'history': history.map((h) => h.toMap()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory WorkDayEntry.fromMap(Map<String, dynamic> map) => WorkDayEntry(
        id: map['id'] as String,
        date: DateTime.parse(map['date'] as String),
        hours: (map['hours'] as num).toDouble(),
        helperNames: (map['helperNames'] as List<dynamic>? ?? [])
            .map((e) => PresenceEntry.fromAny(e))
            .toList(),
        history: (map['history'] as List<dynamic>? ?? [])
            .map((e) => AuditEntry.fromMap(e as Map<String, dynamic>))
            .toList(),
        updatedAt: map['updatedAt'] == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.parse(map['updatedAt'] as String),
      );

  // Sync-Merge (Option C): Stunden von der neueren Seite, Helferliste
  // feldweise per Tombstone gemerged (sonst würde das Entfernen eines
  // Helfers auf einem Gerät durch eine Ergänzung auf einem anderen Gerät
  // rückgängig gemacht, sobald dessen Seite beim Stunden-Feld "gewinnt"),
  // Verlauf verlustfrei vereinigt. [tombstones] kommt vom umschließenden
  // Project.mergeFrom, da Helfer-Tombstones dort projektweit verwaltet
  // werden (Schlüssel 'helper:$id:$person', siehe ProjectStore).
  WorkDayEntry mergeFrom(WorkDayEntry remote, Map<String, DateTime> tombstones) {
    final winner = newerOf(this, remote, (e) => e.updatedAt);
    return WorkDayEntry(
      id: id,
      date: date,
      hours: winner.hours,
      updatedAt: winner.updatedAt,
      helperNames: mergeById<PresenceEntry>(
        local: helperNames,
        remote: remote.helperNames,
        idOf: (p) => 'helper:$id:${p.person}',
        updatedAtOf: (p) => p.updatedAt,
        combine: (l, r) => newerOf(l, r, (p) => p.updatedAt),
        tombstones: tombstones,
      ),
      history: mergeHistory(history, remote.history),
    );
  }
}
