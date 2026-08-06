import 'modules/gewerk_module.dart';

class Gewerk {
  String id;
  String name;
  String? category;
  List<GewerkModule> modules;

  Gewerk(
    this.id,
    this.name, {
    this.category,
    List<GewerkModule>? modules,
  }) : modules = modules ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'modules': modules.map((m) => m.toMap()).toList(),
      };

  factory Gewerk.fromMap(Map<String, dynamic> map) => Gewerk(
        map['id'] as String,
        map['name'] as String,
        category: map['category'] as String?,
        modules: (map['modules'] as List<dynamic>? ?? [])
            .map((e) => GewerkModule.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}
