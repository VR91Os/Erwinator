import '../../utils/id_merge.dart';
import '../task.dart';
import 'gewerk_module.dart';

class TodoModule extends GewerkModule {
  static const moduleType = 'todo';

  List<Task> tasks;

  TodoModule(super.id, {super.label, super.updatedAt, List<Task>? tasks})
      : tasks = tasks ?? [];

  @override
  String get type => moduleType;

  @override
  Map<String, dynamic> toMap() => {
        'type': type,
        'id': id,
        'label': label,
        'updatedAt': updatedAt.toIso8601String(),
        'tasks': tasks.map((t) => t.toMap()).toList(),
      };

  factory TodoModule.fromMap(Map<String, dynamic> map) => TodoModule(
        map['id'] as String,
        label: map['label'] as String? ?? '',
        updatedAt: map['updatedAt'] == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.parse(map['updatedAt'] as String),
        tasks: (map['tasks'] as List<dynamic>? ?? [])
            .map((e) => Task.fromMap(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  GewerkModule mergeFrom(GewerkModule remote, Map<String, DateTime> tombstones) {
    if (remote is! TodoModule) return this;
    final winner = newerOf(this, remote, (m) => m.updatedAt);
    return TodoModule(
      id,
      label: winner.label,
      updatedAt: winner.updatedAt,
      tasks: mergeById<Task>(
        local: tasks,
        remote: remote.tasks,
        idOf: (t) => t.id,
        updatedAtOf: (t) => t.updatedAt,
        combine: (l, r) => l.mergeFrom(r, tombstones),
        tombstones: tombstones,
      ),
    );
  }
}
