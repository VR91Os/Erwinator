// Ein Verlaufseintrag ("wer hat wann was gemacht") für Aufgaben, Kontakte,
// Dateien und Helferbedarfe. Wird über das kleine (i)-Icon sichtbar gemacht.
class AuditEntry {
  String kurzzeichen;
  String action;
  DateTime timestamp;

  AuditEntry({
    required this.kurzzeichen,
    required this.action,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'kurzzeichen': kurzzeichen,
        'action': action,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AuditEntry.fromMap(Map<String, dynamic> map) => AuditEntry(
        kurzzeichen: map['kurzzeichen'] as String? ?? '',
        action: map['action'] as String? ?? '',
        timestamp: DateTime.parse(map['timestamp'] as String),
      );
}
