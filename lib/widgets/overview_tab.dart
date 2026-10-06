import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/modules/todo_module.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../state/project_store.dart';
import '../state/settings_store.dart';
import '../utils/task_urgency.dart';
import 'helper_demand_calendar.dart';
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
      final color = taskUrgencyColor(ref.task,
          warningDays: widget.project.priorityWarningDays);
      if (color == prioWarningColor) {
        return color;
      }
    }
    return result;
  }

  Widget _taskWidgetFor(_TaskRef ref) {
    final store = context.read<ProjectStore>();
    final settingsStore = context.read<SettingsStore>();
    final actor = settingsStore.currentUserKurzzeichen;
    return taskWidget(
      ref.task,
      context,
      projectId: widget.project.id,
      gewerkId: ref.gewerkId,
      moduleId: ref.moduleId,
      onStatusTap: () => store.updateTaskStatus(
          widget.project.id, ref.gewerkId, ref.moduleId, ref.task.id,
          actor: actor),
      onShiftDate: () => store.shiftTaskDueDate(
          widget.project.id, ref.gewerkId, ref.moduleId, ref.task.id,
          actor: actor),
      onShiftDateByDefault: () => store.shiftTaskDueDateByDefault(
          widget.project.id, ref.gewerkId, ref.moduleId, ref.task.id,
          holidayCountry: settingsStore.settings.holidayCountry,
          actor: actor),
      shiftDays: widget.project.shiftDays,
      onArchive: () => store.archiveTask(
          widget.project.id, ref.gewerkId, ref.moduleId, ref.task.id,
          actor: actor),
      warningDays: widget.project.priorityWarningDays,
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
        HelperDemandCalendar(
          demands: widget.project.helperDemands,
          selectedDay: selectedDay,
          focusedDay: focusedDay,
          onDaySelected: (selected, focused) {
            setState(() {
              selectedDay = selected;
              focusedDay = focused;
            });
          },
          taskColorBuilder: _dayColor,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                selectedDay = DateTime.now();
                focusedDay = DateTime.now();
              });
            },
            icon: const Icon(Icons.today, size: 16),
            label: const Text("Heute"),
          ),
        ),
        if (widget.project.timeTrackingEnabled) ...[
          const SizedBox(height: 10),
          _OnSitePresenceRow(project: widget.project),
        ],
        const SizedBox(height: 20),
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

// "Ich bin auf der Baustelle" (V1): dauerhafter Schalter statt täglicher
// Checkbox – siehe ProjectStore.setOnSitePresence/syncOnSitePresenceForToday.
// Der Hinweistext bleibt bewusst klein und dezent, damit er nicht wie eine
// aufdringliche Warnung wirkt.
class _OnSitePresenceRow extends StatelessWidget {
  final Project project;

  const _OnSitePresenceRow({required this.project});

  @override
  Widget build(BuildContext context) {
    final store = context.read<ProjectStore>();
    final myName = context.watch<SettingsStore>().currentUserDisplayName;
    final isPresent = project.onSitePresence.any((e) => e.person == myName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Switch(
              value: isPresent,
              onChanged: (value) => store.setOnSitePresence(
                project.id,
                person: myName,
                present: value,
              ),
            ),
            const Text("Ich bin auf der Baustelle"),
          ],
        ),
        if (isPresent)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              "Arbeitstage laut aktivem Profil zählen automatisch in die "
              "Zeitstatistik, bis du das wieder ausschaltest.",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
          ),
      ],
    );
  }
}
