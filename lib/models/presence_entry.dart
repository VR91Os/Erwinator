// Ein Name (Nutzer oder Helfer), der zu einem bestimmten Zeitpunkt aktiviert
// wurde – z.B. "Ich bin auf der Baustelle" (Project.onSitePresence) oder ein
// eingetragener Helfer an einem Arbeitstag (WorkDayEntry.helperNames). Der
// Zeitstempel macht das Ein-/Ausschalten sync-mergefähig (siehe
// utils/id_merge.dart): eine Deaktivierung setzt einen Tombstone, eine
// erneute Aktivierung NACH dem Tombstone-Zeitpunkt gewinnt ("Edit schlägt
// Delete") – anders als bei einer reinen String-Liste, die beim Merge nur
// als Ganzes von einer Seite übernommen werden könnte.
class PresenceEntry {
  String person;
  DateTime updatedAt;

  PresenceEntry(this.person, {DateTime? updatedAt})
      : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'person': person,
        'updatedAt': updatedAt.toIso8601String(),
      };

  // Akzeptiert zusätzlich das alte Format (reiner Name als String), damit
  // vor der Umstellung lokal gespeicherte Projekte weiter lesbar bleiben.
  factory PresenceEntry.fromAny(dynamic value) {
    if (value is String) {
      return PresenceEntry(value, updatedAt: DateTime.fromMillisecondsSinceEpoch(0));
    }
    final map = value as Map<String, dynamic>;
    return PresenceEntry(
      map['person'] as String,
      updatedAt: map['updatedAt'] == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.parse(map['updatedAt'] as String),
    );
  }
}
