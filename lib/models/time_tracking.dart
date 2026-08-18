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

// Ein einzelner Stunden-Beitrag zu einem Arbeitstag (z.B. ein Helfer, eine
// Anwesenheits-Meldung, eine manuelle Profil-Anwendung oder eine Korrektur).
// Jeder Beitrag hat eine eigene, stabile ID -> WorkDayEntry.hours ist die
// Summe aller (nicht per Tombstone entfernten) Beiträge, statt eines
// einzelnen Skalarfelds. Das macht die Stunden sync-mergefähig: zwei
// Geräte, die offline gleichzeitig je einen eigenen Beitrag hinzufügen,
// verlieren beim Merge keine der beiden Ergänzungen (siehe
// WorkDayEntry.mergeFrom) - anders als ein einzelnes "neuere Seite
// gewinnt"-Stundenfeld, bei dem eine Seite die andere komplett überschreibt.
class HourContribution {
  String id;
  double amount;
  DateTime updatedAt;

  HourContribution({
    required this.id,
    required this.amount,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory HourContribution.fromMap(Map<String, dynamic> map) =>
      HourContribution(
        id: map['id'] as String,
        amount: (map['amount'] as num).toDouble(),
        updatedAt: map['updatedAt'] == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.parse(map['updatedAt'] as String),
      );
}

// Ein einzelner erfasster Arbeitstag am Projekt (aus einem Profil erzeugt
// oder im Kalender manuell nachjustiert), inkl. der an diesem Tag
// mitwirkenden Helfer.
class WorkDayEntry {
  String id;
  DateTime date;
  List<HourContribution> hourContributions;
  List<PresenceEntry> helperNames;

  // Verlauf: wer hat den Tag erfasst/angepasst.
  List<AuditEntry> history;
  DateTime updatedAt;

  double get hours =>
      hourContributions.fold(0.0, (sum, c) => sum + c.amount);

  // Bequemlichkeits-Setter für einfache Fälle (Tests, Alt-Daten-Migration
  // in fromMap): ersetzt alle bisherigen Beiträge durch genau einen. Für
  // die manuelle Korrektur in ProjectStore.updateWorkDayEntryHours reicht
  // das NICHT aus (dort müssen die ersetzten Beiträge zusätzlich in
  // project.deletedIds getombstoned werden, sonst bringt ein Merge sie von
  // einem Gerät zurück, das die Korrektur noch nicht kennt).
  set hours(double value) {
    hourContributions = [
      HourContribution(
        id: 'hourcontrib:manual:$id',
        amount: value,
        updatedAt: updatedAt,
      ),
    ];
  }

  WorkDayEntry({
    required this.id,
    required this.date,
    double? hours,
    List<HourContribution>? hourContributions,
    List<PresenceEntry>? helperNames,
    List<AuditEntry>? history,
    DateTime? updatedAt,
  })  : hourContributions = hourContributions ??
            (hours != null && hours != 0
                ? [
                    HourContribution(
                      id: 'hourcontrib:manual:$id',
                      amount: hours,
                      updatedAt: updatedAt,
                    ),
                  ]
                : []),
        helperNames = helperNames ?? [],
        history = history ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'hourContributions': hourContributions.map((c) => c.toMap()).toList(),
        'helperNames': helperNames.map((e) => e.toMap()).toList(),
        'history': history.map((h) => h.toMap()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  // 'hourContributions' fehlt bei Daten, die vor der Umstellung auf das
  // additive Stunden-Modell gespeichert wurden -> der alte Skalarwert
  // 'hours' wird dann einmalig in einen einzelnen Beitrag übersetzt.
  factory WorkDayEntry.fromMap(Map<String, dynamic> map) {
    final updatedAt = map['updatedAt'] == null
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : DateTime.parse(map['updatedAt'] as String);
    return WorkDayEntry(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      hourContributions: map['hourContributions'] == null
          ? null
          : (map['hourContributions'] as List<dynamic>)
              .map((e) => HourContribution.fromMap(e as Map<String, dynamic>))
              .toList(),
      hours: map['hourContributions'] == null
          ? (map['hours'] as num?)?.toDouble() ?? 0
          : null,
      helperNames: (map['helperNames'] as List<dynamic>? ?? [])
          .map((e) => PresenceEntry.fromAny(e))
          .toList(),
      history: (map['history'] as List<dynamic>? ?? [])
          .map((e) => AuditEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      updatedAt: updatedAt,
    );
  }

  // Sync-Merge (Option C): Stunden-Beiträge und Helferliste jeweils
  // feldweise per Tombstone gemerged (sonst würde das Entfernen eines
  // Beitrags/Helfers auf einem Gerät durch eine Ergänzung auf einem
  // anderen Gerät rückgängig gemacht, sobald dessen Seite komplett
  // "gewinnt"), Verlauf verlustfrei vereinigt. [tombstones] kommt vom
  // umschließenden Project.mergeFrom, da Tombstones dort projektweit
  // verwaltet werden (Schlüssel 'helper:$id:$person' bzw.
  // 'hourcontrib:...', siehe ProjectStore).
  WorkDayEntry mergeFrom(WorkDayEntry remote, Map<String, DateTime> tombstones) {
    return WorkDayEntry(
      id: id,
      date: date,
      hourContributions: mergeById<HourContribution>(
        local: hourContributions,
        remote: remote.hourContributions,
        idOf: (c) => c.id,
        updatedAtOf: (c) => c.updatedAt,
        combine: (l, r) => newerOf(l, r, (c) => c.updatedAt),
        tombstones: tombstones,
      ),
      updatedAt: newerOf(this, remote, (e) => e.updatedAt).updatedAt,
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
