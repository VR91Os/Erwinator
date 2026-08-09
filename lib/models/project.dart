import 'gewerk.dart';
import 'helper_demand.dart';

class Project {
  String id;
  String name;
  String address;
  List<Gewerk> gewerke;

  // 'neubau' | 'sanierung' | '' (z.B. bei importierten Alt-Projekten).
  // Steuert nur die Start-Gewerke beim Anlegen, nicht weiter erzwungen.
  String projectType;

  // Helferbedarf des gesamten Projekts (Projekt-weit statt je Gewerk),
  // erscheint im Überblickskalender.
  List<HelperDemand> helperDemands;

  // Steuern, welche Aufgaben beim Projekt-Export zusätzlich als
  // .ics-Kalenderdatei mit exportiert werden.
  bool exportAllDatedTodos;
  bool exportPriorityTasks;

  Project(
    this.id,
    this.name, {
    this.address = '',
    List<Gewerk>? gewerke,
    this.projectType = '',
    List<HelperDemand>? helperDemands,
    this.exportAllDatedTodos = false,
    this.exportPriorityTasks = false,
  })  : gewerke = gewerke ?? [],
        helperDemands = helperDemands ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'gewerke': gewerke.map((g) => g.toMap()).toList(),
        'projectType': projectType,
        'helperDemands': helperDemands.map((d) => d.toMap()).toList(),
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
        projectType: map['projectType'] as String? ?? '',
        helperDemands: (map['helperDemands'] as List<dynamic>? ?? [])
            .map((e) => HelperDemand.fromMap(e as Map<String, dynamic>))
            .toList(),
        exportAllDatedTodos: map['exportAllDatedTodos'] as bool? ?? false,
        exportPriorityTasks: map['exportPriorityTasks'] as bool? ?? false,
      );
}
