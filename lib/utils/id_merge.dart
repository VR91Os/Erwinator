import '../models/audit_entry.dart';

// Generischer Baustein für den projektweiten Merge (Option C): führt zwei
// Versionen einer Liste eindeutig identifizierbarer Elemente zusammen,
// statt eine Seite komplett durch die andere zu ersetzen.
//
// - Elemente, die nur auf einer Seite existieren, bleiben erhalten (neu
//   hinzugefügt auf der jeweils anderen Seite).
// - Elemente auf beiden Seiten werden über [combine] zusammengeführt
//   (typischerweise: neuere updatedAt gewinnt, verschachtelte Listen
//   rekursiv gemerged).
// - [tombstones] (id -> Löschzeitpunkt) sorgt dafür, dass eine Löschung
//   nicht durch die andere Seite rückgängig gemacht wird – außer die
//   andere Seite hat das Element NACH der Löschung noch bearbeitet
//   (updatedAt nach dem Tombstone-Zeitpunkt), dann gewinnt die Bearbeitung
//   ("Edit schlägt Delete"), damit nie stillschweigend eine Änderung
//   verloren geht.
List<T> mergeById<T>({
  required List<T> local,
  required List<T> remote,
  required String Function(T item) idOf,
  required DateTime Function(T item) updatedAtOf,
  required T Function(T local, T remote) combine,
  Map<String, DateTime> tombstones = const {},
}) {
  final localById = <String, T>{for (final item in local) idOf(item): item};
  final remoteById = <String, T>{for (final item in remote) idOf(item): item};

  final order = <String>[];
  final seen = <String>{};
  for (final item in local) {
    if (seen.add(idOf(item))) order.add(idOf(item));
  }
  for (final item in remote) {
    if (seen.add(idOf(item))) order.add(idOf(item));
  }

  final result = <T>[];
  for (final id in order) {
    final l = localById[id];
    final r = remoteById[id];
    final merged = (l != null && r != null) ? combine(l, r) : (l ?? r as T);

    final deletedAt = tombstones[id];
    if (deletedAt != null && !updatedAtOf(merged).isAfter(deletedAt)) {
      continue;
    }
    result.add(merged);
  }
  return result;
}

// [local]/[remote] jeweils bei Gleichstand bevorzugt lokal (beliebige aber
// deterministische Wahl).
T newerOf<T>(T local, T remote, DateTime Function(T item) updatedAtOf) =>
    updatedAtOf(remote).isAfter(updatedAtOf(local)) ? remote : local;

// Verlaufslisten (AuditEntry) werden nie bearbeitet, nur angehängt – daher
// reicht eine verlustfreie Vereinigung ohne exakte Duplikate, chronologisch
// sortiert, statt einer Konfliktauflösung.
List<AuditEntry> mergeHistory(List<AuditEntry> a, List<AuditEntry> b) {
  final byKey = <String, AuditEntry>{};
  for (final entry in [...a, ...b]) {
    final key =
        '${entry.kurzzeichen}|${entry.action}|${entry.timestamp.toIso8601String()}';
    byKey[key] = entry;
  }
  final result = byKey.values.toList()
    ..sort((x, y) => x.timestamp.compareTo(y.timestamp));
  return result;
}

// Für Elemente ohne eigenen Zeitstempel (z.B. Helfer-Zusagen), die nie
// bearbeitet, nur an-/abgemeldet werden: ein Tombstone soll immer
// gewinnen, "Edit schlägt Delete" ist hier nicht anwendbar.
final DateTime epoch = DateTime.fromMillisecondsSinceEpoch(0);
