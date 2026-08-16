import 'audit_entry.dart';
import '../utils/id_merge.dart';

// 'angebot' | 'rechnung'. Werden nie zu einer gemeinsamen Summe verschmolzen
// (siehe FinanceOverviewSection) - ein Angebot ist unverbindlich, eine
// Rechnung eine tatsächliche Zahlungsverpflichtung.
class FinanceDocumentType {
  static const angebot = 'angebot';
  static const rechnung = 'rechnung';
}

// Ein einzelner erfasster Finanz-Beleg (Angebot oder Rechnung), projektweit
// in Project.financeEntries gesammelt (wie HelperDemand/WorkDayEntry), damit
// eine Gesamtübersicht möglich ist, ohne den ganzen Gewerke-Baum zu
// durchlaufen. gewerkId ordnet den Eintrag einem Gewerk zu (für die
// Gruppierung in der Gesamtübersicht und die gefilterte Anzeige im
// optionalen Finanzen-Modul dieses Gewerks).
//
// Referenziert die Quelldatei nur über ihre IDs (fileModuleId/fileEntryId),
// statt den Dateiinhalt ein zweites Mal zu speichern - hier stehen
// ausschließlich die daraus ausgelesenen/eingetragenen Zahlungsdaten.
class FinanceEntry {
  String id;
  String gewerkId;
  String? fileModuleId;
  String? fileEntryId;

  String documentType; // FinanceDocumentType.angebot | .rechnung

  // Bruttobetrag ist Pflicht (der in der Praxis relevanteste Wert), Netto
  // optional, falls nicht erkennbar/angegeben.
  double amountGross;
  double? amountNet;

  DateTime? date;
  String note;

  // true, wenn der Vorschlag aus der automatischen PDF-Erkennung stammt und
  // vom Nutzer nur bestätigt wurde (nie automatisch ohne Bestätigung
  // gespeichert) - rein informativ für die Anzeige, keine Funktionslogik.
  bool autoDetected;

  String createdBy;
  DateTime createdAt;
  DateTime updatedAt;
  List<AuditEntry> history;

  FinanceEntry({
    required this.id,
    required this.gewerkId,
    this.fileModuleId,
    this.fileEntryId,
    required this.documentType,
    required this.amountGross,
    this.amountNet,
    this.date,
    this.note = '',
    this.autoDetected = false,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AuditEntry>? history,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        history = history ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'gewerkId': gewerkId,
        'fileModuleId': fileModuleId,
        'fileEntryId': fileEntryId,
        'documentType': documentType,
        'amountGross': amountGross,
        'amountNet': amountNet,
        'date': date?.toIso8601String(),
        'note': note,
        'autoDetected': autoDetected,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'history': history.map((h) => h.toMap()).toList(),
      };

  factory FinanceEntry.fromMap(Map<String, dynamic> map) => FinanceEntry(
        id: map['id'] as String,
        gewerkId: map['gewerkId'] as String,
        fileModuleId: map['fileModuleId'] as String?,
        fileEntryId: map['fileEntryId'] as String?,
        documentType:
            map['documentType'] as String? ?? FinanceDocumentType.rechnung,
        amountGross: (map['amountGross'] as num?)?.toDouble() ?? 0,
        amountNet: (map['amountNet'] as num?)?.toDouble(),
        date: map['date'] == null ? null : DateTime.parse(map['date'] as String),
        note: map['note'] as String? ?? '',
        autoDetected: map['autoDetected'] as bool? ?? false,
        createdBy: map['createdBy'] as String? ?? 'User',
        createdAt: map['createdAt'] == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.parse(map['createdAt'] as String),
        updatedAt: map['updatedAt'] == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.parse(map['updatedAt'] as String),
        history: (map['history'] as List<dynamic>? ?? [])
            .map((e) => AuditEntry.fromMap(e as Map<String, dynamic>))
            .toList(),
      );

  // Sync-Merge (Option C): wird immer als Ganzes bearbeitet (siehe
  // ProjectStore.updateFinanceEntry) -> neuere Seite gewinnt komplett,
  // Verlauf verlustfrei vereinigt.
  FinanceEntry mergeFrom(FinanceEntry remote) {
    final winner = newerOf(this, remote, (e) => e.updatedAt);
    return FinanceEntry(
      id: id,
      gewerkId: winner.gewerkId,
      fileModuleId: winner.fileModuleId,
      fileEntryId: winner.fileEntryId,
      documentType: winner.documentType,
      amountGross: winner.amountGross,
      amountNet: winner.amountNet,
      date: winner.date,
      note: winner.note,
      autoDetected: winner.autoDetected,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: winner.updatedAt,
      history: mergeHistory(history, remote.history),
    );
  }
}
