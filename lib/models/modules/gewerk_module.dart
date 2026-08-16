import 'contact_module.dart';
import 'file_module.dart';
import 'finance_module.dart';
import 'todo_module.dart';

abstract class GewerkModule {
  final String id;

  // Frei vergebbarer Anzeigename des Moduls (z.B. um mehrere Todo-Listen
  // im selben Gewerk zu unterscheiden). Leer = Standard-Bezeichnung.
  String label;

  // Für den Sync-Merge (Option C): wann Label o.ä. zuletzt geändert wurde.
  DateTime updatedAt;

  GewerkModule(this.id, {this.label = '', DateTime? updatedAt})
      : updatedAt = updatedAt ?? DateTime.now();

  String get type;

  Map<String, dynamic> toMap();

  // Sync-Merge (Option C): typ-spezifisch überschrieben, damit Inhalte
  // (Aufgaben/Kontakte/Dateien) per ID statt komplett ersetzt werden.
  // [tombstones] (projektweite id -> Löschzeitpunkt) wird bis in die
  // innersten Listen (z.B. Datei-Markierungen) durchgereicht. Unterschiedlicher
  // Modultyp bei gleicher ID sollte nie vorkommen – Fallback: lokale Version
  // behalten, statt zu raten.
  GewerkModule mergeFrom(GewerkModule remote, Map<String, DateTime> tombstones);

  static GewerkModule fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String;
    switch (type) {
      case ContactModule.moduleType:
        return ContactModule.fromMap(map);
      case TodoModule.moduleType:
        return TodoModule.fromMap(map);
      case FileModule.moduleType:
        return FileModule.fromMap(map);
      case FinanceModule.moduleType:
        return FinanceModule.fromMap(map);
      default:
        throw ArgumentError('Unbekannter Modultyp: $type');
    }
  }
}
