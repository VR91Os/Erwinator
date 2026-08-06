import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/modules/todo_module.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../state/project_store.dart';
import '../utils/task_urgency.dart';
import 'task_widget.dart';

class _TaskRef {
  final String gewerkId;
  final String moduleId;
  final Task task;
  _TaskRef(this.gewerkId, this.moduleId, this.task);
}

class OverviewTab extends StatefulWidget {
  final Project project;

  const OverviewTab({super.key, required this.project});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  DateTime selectedDay = DateTime.now();
  DateTime focusedDay = DateTime.now();

  List<_TaskRef> get _allTaskRefs {
    final refs = <_TaskRef>[];
    for (final gewerk in widget.project.gewerke) {
      for (final module in gewerk.modules.whereType<TodoModule>()) {
        for (final task in module.tasks) {
          refs.add(_TaskRef(gewerk.id, module.id, task));
        }
      }
    }
    return refs;
  }

  List<_TaskRef> get _priorityTaskRefs {
    final refs = _allTaskRefs
        .where((r) =>
            r.task.isHighPriority &&
            (r.task.status == "offen" || r.task.status == "teilweise"))
        .toList();
    refs.sort((a, b) {
      final ad = a.task.dueDate;
      final bd = b.task.dueDate;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
    return refs;
  }

  List<_TaskRef> _taskRefsForDay(DateTime day) {
    return _allTaskRefs.where((r) {
      final due = r.task.dueDate;
      if (r.task.status == "archiviert" || due == null) return false;
      return isSameDay(due, day);
    }).toList();
  }

  Color? _dayColor(DateTime day) {
    final refs = _taskRefsForDay(day);
    if (refs.isEmpty) return null;
    Color result = Colors.blue.shade100;
    for (final ref in refs) {
      final color = taskUrgencyColor(ref.task);
      if (color == const Color(0xFFFFD6D6)) {
        return color;
      }
      if (color == const Color(0xFFFFF3CD)) {
        result = color;
      }
    }
    return result;
  }

  Widget _taskWidgetFor(_TaskRef ref) {
    final store = context.read<ProjectStore>();
    return taskWidget(
      ref.task,
      context,
      onStatusTap: () => store.updateTaskStatus(
          widget.project.id, ref.gewerkId, ref.moduleId, ref.task.id),
      onShiftDate: () => store.shiftTaskDueDate(
          widget.project.id, ref.gewerkId, ref.moduleId, ref.task.id),
      onArchive: () => store.archiveTask(
          widget.project.id, ref.gewerkId, ref.moduleId, ref.task.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDayRefs = _taskRefsForDay(selectedDay);

    return ListView(
      children: [
        const Text(
          "Prioritäts-Aufgaben",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (_priorityTaskRefs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text("Keine offenen Prioritäts-Aufgaben"),
          ),
        ..._priorityTaskRefs.map(_taskWidgetFor),
        const SizedBox(height: 20),
        const Text(
          "Kalender",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        TableCalendar(
          firstDay: DateTime.now().subtract(const Duration(days: 365)),
          lastDay: DateTime.now().add(const Duration(days: 365)),
          focusedDay: focusedDay,
          selectedDayPredicate: (day) => isSameDay(day, selectedDay),
          onDaySelected: (selected, focused) {
            setState(() {
              selectedDay = selected;
              focusedDay = focused;
            });
          },
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focused) {
              final color = _dayColor(day);
              if (color == null) return null;
              return Container(
                margin: const EdgeInsets.all(4),
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('${day.day}'),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Aufgaben am ${selectedDay.day}.${selectedDay.month}.${selectedDay.year}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        if (selectedDayRefs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text("Keine Aufgaben an diesem Tag"),
          ),
        ...selectedDayRefs.map(_taskWidgetFor),
      ],
    );
  }
}
