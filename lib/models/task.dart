import 'audit_entry.dart';
import 'checklist_item.dart';
import '../utils/id_merge.dart';

class Task {
  String id;

  String name;
  String description;

  String status;

  bool isHighPriority;

  DateTime? dueDate;

  List<ChecklistItem> checklist;
  List<String> itemRefs;

  String createdBy;
  DateTime createdAt;
  DateTime updatedAt;

  // Verlauf: wer hat die Aufgabe erstellt/bearbeitet/abgehakt.
  List<AuditEntry> history;

  Task(
    this.id,
    this.name, {
    this.description = "",
    this.status = "offen",
    this.isHighPriority = false,
    this.dueDate,
    List<ChecklistItem>? checklist,
    List<String>? itemRefs,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AuditEntry>? history,
  })  : checklist = checklist ?? [],
        itemRefs = itemRefs ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        history = history ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'status': status,
        'isHighPriority': isHighPriority,
        'dueDate': dueDate?.toIso8601String(),
        'checklist': checklist.map((c) => c.toMap()).toList(),
        'itemRefs': itemRefs,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'history': history.map((h) => h.toMap()).toList(),
      };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
        map['id'] as String,
        map['name'] as String,
        description: map['description'] as String? ?? "",
        status: map['status'] as String? ?? "offen",
        isHighPriority: map['isHighPriority'] as bool? ?? false,
        dueDate: map['dueDate'] == null
            ? null
            : DateTime.parse(map['dueDate'] as String),
        checklist: (map['checklist'] as List<dynamic>? ?? [])
            .map((e) => ChecklistItem.fromMap(e as Map<String, dynamic>))
            .toList(),
        itemRefs: (map['itemRefs'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        createdBy: map['createdBy'] as String? ?? "User",
        createdAt: DateTime.parse(map['createdAt'] as String),
        updatedAt: DateTime.parse(map['updatedAt'] as String),
        history: (map['history'] as List<dynamic>? ?? [])
            .map((e) => AuditEntry.fromMap(e as Map<String, dynamic>))
            .toList(),
      );

  // Sync-Merge (Option C): die Seite mit der neueren updatedAt liefert die
  // inhaltlichen Felder (Name, Status, Fälligkeit, Checkliste – dafür hat
  // ChecklistItem keine eigene ID, ein Item-genauer Merge ist daher nicht
  // möglich), der Verlauf wird verlustfrei aus beiden Seiten vereinigt,
  // damit kein Audit-Eintrag verschwindet, egal welche Seite "gewinnt".
  Task mergeFrom(Task remote) {
    final winner = newerOf(this, remote, (t) => t.updatedAt);
    final itemRefsUnion = {...itemRefs, ...remote.itemRefs}.toList();
    return Task(
      id,
      winner.name,
      description: winner.description,
      status: winner.status,
      isHighPriority: winner.isHighPriority,
      dueDate: winner.dueDate,
      checklist: winner.checklist,
      itemRefs: itemRefsUnion,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: winner.updatedAt,
      history: mergeHistory(history, remote.history),
    );
  }
}
