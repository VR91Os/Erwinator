import 'audit_entry.dart';

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

  WorkTimeProfile({
    required this.id,
    required this.name,
    List<WeekdaySchedule>? schedules,
  }) : schedules = schedules ?? [];

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
      };

  factory WorkTimeProfile.fromMap(Map<String, dynamic> map) =>
      WorkTimeProfile(
        id: map['id'] as String,
        name: map['name'] as String,
        schedules: (map['schedules'] as List<dynamic>? ?? [])
            .map((e) => WeekdaySchedule.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}

// Ein einzelner erfasster Arbeitstag am Projekt (aus einem Profil erzeugt
// oder im Kalender manuell nachjustiert), inkl. der an diesem Tag
// mitwirkenden Helfer.
class WorkDayEntry {
  String id;
  DateTime date;
  double hours;
  List<String> helperNames;

  // Verlauf: wer hat den Tag erfasst/angepasst.
  List<AuditEntry> history;

  WorkDayEntry({
    required this.id,
    required this.date,
    required this.hours,
    List<String>? helperNames,
    List<AuditEntry>? history,
  })  : helperNames = helperNames ?? [],
        history = history ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'hours': hours,
        'helperNames': helperNames,
        'history': history.map((h) => h.toMap()).toList(),
      };

  factory WorkDayEntry.fromMap(Map<String, dynamic> map) => WorkDayEntry(
        id: map['id'] as String,
        date: DateTime.parse(map['date'] as String),
        hours: (map['hours'] as num).toDouble(),
        helperNames: (map['helperNames'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        history: (map['history'] as List<dynamic>? ?? [])
            .map((e) => AuditEntry.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}
