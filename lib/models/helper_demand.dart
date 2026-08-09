import 'audit_entry.dart';

class HelperSignup {
  String id;
  String name;
  String? startTime; // Format "HH:MM"
  String? endTime; // Format "HH:MM"

  HelperSignup({
    required this.id,
    required this.name,
    this.startTime,
    this.endTime,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'startTime': startTime,
        'endTime': endTime,
      };

  factory HelperSignup.fromMap(Map<String, dynamic> map) => HelperSignup(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        startTime: map['startTime'] as String?,
        endTime: map['endTime'] as String?,
      );
}

// Helferbedarf für einen einzelnen Tag, direkt am Projekt (nicht an einem
// Gewerk) – erscheint im Überblickskalender. Ein wochenweiser Eintrag
// entsteht, indem für jeden Tag im gewählten Zeitraum ein eigener
// HelperDemand angelegt wird.
class HelperDemand {
  String id;
  DateTime date;
  int neededCount;
  String note;
  List<HelperSignup> signups;

  // Verlauf: wer hat den Bedarf eingetragen/Helfer eingetragen.
  List<AuditEntry> history;

  HelperDemand({
    required this.id,
    required this.date,
    this.neededCount = 1,
    this.note = '',
    List<HelperSignup>? signups,
    List<AuditEntry>? history,
  })  : signups = signups ?? [],
        history = history ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'neededCount': neededCount,
        'note': note,
        'signups': signups.map((s) => s.toMap()).toList(),
        'history': history.map((h) => h.toMap()).toList(),
      };

  factory HelperDemand.fromMap(Map<String, dynamic> map) => HelperDemand(
        id: map['id'] as String,
        date: DateTime.parse(map['date'] as String),
        neededCount: map['neededCount'] as int? ?? 1,
        note: map['note'] as String? ?? '',
        signups: (map['signups'] as List<dynamic>? ?? [])
            .map((e) => HelperSignup.fromMap(e as Map<String, dynamic>))
            .toList(),
        history: (map['history'] as List<dynamic>? ?? [])
            .map((e) => AuditEntry.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}
