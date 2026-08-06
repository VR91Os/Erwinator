import 'gewerk.dart';

class Project {
  String id;
  String name;
  String address;
  List<Gewerk> gewerke;

  // Steuern, welche Aufgaben beim Projekt-Export zusätzlich als
  // .ics-Kalenderdatei mit exportiert werden.
  bool exportAllDatedTodos;
  bool exportPriorityTasks;

  Project(
    this.id,
    this.name, {
    this.address = '',
    List<Gewerk>? gewerke,
    this.exportAllDatedTodos = false,
    this.exportPriorityTasks = false,
  }) : gewerke = gewerke ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'gewerke': gewerke.map((g) => g.toMap()).toList(),
        'exportAllDatedTodos': exportAllDatedTodos,
        'exportPriorityTasks': exportPriorityTasks,
      };

  factory Project.fromMap(Map<String, dynamic> map) => Project(
        map['id'] as String,
        map['name'] as String,
        address: map['address'] as String? ?? '',
        gewerke: (map['gewerke'] as List<dynamic>? ?? [])
            .map((e) => Gewerk.fromMap(e as Map<String, dynamic>))
            .toList(),
        exportAllDatedTodos: map['exportAllDatedTodos'] as bool? ?? false,
        exportPriorityTasks: map['exportPriorityTasks'] as bool? ?? false,
      );
}
