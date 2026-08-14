import 'modules/gewerk_module.dart';
import '../utils/id_merge.dart';

class Gewerk {
  String id;
  String name;
  String? category;
  List<GewerkModule> modules;
  DateTime updatedAt;

  Gewerk(
    this.id,
    this.name, {
    this.category,
    List<GewerkModule>? modules,
    DateTime? updatedAt,
  })  : modules = modules ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'modules': modules.map((m) => m.toMap()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Gewerk.fromMap(Map<String, dynamic> map) => Gewerk(
        map['id'] as String,
        map['name'] as String,
        category: map['category'] as String?,
        modules: (map['modules'] as List<dynamic>? ?? [])
            .map((e) => GewerkModule.fromMap(e as Map<String, dynamic>))
            .toList(),
        updatedAt: map['updatedAt'] == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.parse(map['updatedAt'] as String),
      );

  // Sync-Merge (Option C): Name/Kategorie von der neueren Seite, Module
  // per ID zusammengeführt (inkl. Tombstones für gelöschte Module).
  Gewerk mergeFrom(Gewerk remote, {required Map<String, DateTime> tombstones}) {
    final winner = newerOf(this, remote, (g) => g.updatedAt);
    return Gewerk(
      id,
      winner.name,
      category: winner.category,
      updatedAt: winner.updatedAt,
      modules: mergeById<GewerkModule>(
        local: modules,
        remote: remote.modules,
        idOf: (m) => m.id,
        updatedAtOf: (m) => m.updatedAt,
        combine: (l, r) => l.mergeFrom(r, tombstones),
        tombstones: tombstones,
      ),
    );
  }
}
