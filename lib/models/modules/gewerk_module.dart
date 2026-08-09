import 'contact_module.dart';
import 'file_module.dart';
import 'todo_module.dart';

abstract class GewerkModule {
  final String id;

  // Frei vergebbarer Anzeigename des Moduls (z.B. um mehrere Todo-Listen
  // im selben Gewerk zu unterscheiden). Leer = Standard-Bezeichnung.
  String label;

  GewerkModule(this.id, {this.label = ''});

  String get type;

  Map<String, dynamic> toMap();

  static GewerkModule fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String;
    switch (type) {
      case ContactModule.moduleType:
        return ContactModule.fromMap(map);
      case TodoModule.moduleType:
        return TodoModule.fromMap(map);
      case FileModule.moduleType:
        return FileModule.fromMap(map);
      default:
        throw ArgumentError('Unbekannter Modultyp: $type');
    }
  }
}
