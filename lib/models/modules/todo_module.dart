import '../task.dart';
import 'gewerk_module.dart';

class TodoModule extends GewerkModule {
  static const moduleType = 'todo';

  List<Task> tasks;

  TodoModule(super.id, {super.label, List<Task>? tasks})
      : tasks = tasks ?? [];

  @override
  String get type => moduleType;

  @override
  Map<String, dynamic> toMap() => {
        'type': type,
        'id': id,
        'label': label,
        'tasks': tasks.map((t) => t.toMap()).toList(),
      };

  factory TodoModule.fromMap(Map<String, dynamic> map) => TodoModule(
        map['id'] as String,
        label: map['label'] as String? ?? '',
        tasks: (map['tasks'] as List<dynamic>? ?? [])
            .map((e) => Task.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}
