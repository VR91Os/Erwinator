import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/helper_demand.dart';
import '../models/modules/todo_module.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../state/project_store.dart';
import '../state/settings_store.dart';
import '../utils/task_urgency.dart';
import 'audit_info_icon.dart';
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

  HelperDemand? _demandFor(DateTime day) {
    for (final demand in widget.project.helperDemands) {
      if (isSameDay(demand.date, day)) return demand;
    }
    return null;
  }

  Color _demandColor(HelperDemand demand) {
    if (demand.signups.length >= demand.neededCount) {
      return Colors.green.shade600;
    }
    if (demand.signups.isNotEmpty) {
      return const Color(0xFFE0A800);
    }
    return const Color(0xFFD32F2F);
  }

  Widget? _dayBuilder(BuildContext context, DateTime day, DateTime focused) {
    final color = _dayColor(day);
    final demand = _demandFor(day);
    if (color == null && demand == null) return null;

    final dayNumber = Container(
      margin: const EdgeInsets.all(4),
      decoration:
          color == null ? null : BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text('${day.day}'),
    );
    if (demand == null) return dayNumber;

    return Stack(
      alignment: Alignment.center,
      children: [
        dayNumber,
        Positioned(
          right: 4,
          top: 4,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _demandColor(demand),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _taskWidgetFor(_TaskRef ref) {
    final store = context.read<ProjectStore>();
    final actor = context.read<SettingsStore>().currentUserKurzzeichen;
    return taskWidget(
      ref.task,
      context,
      onStatusTap: () => store.updateTaskStatus(
          widget.project.id, ref.gewerkId, ref.moduleId, ref.task.id,
          actor: actor),
      onShiftDate: () => store.shiftTaskDueDate(
          widget.project.id, ref.gewerkId, ref.moduleId, ref.task.id,
          actor: actor),
      onArchive: () => store.archiveTask(
          widget.project.id, ref.gewerkId, ref.moduleId, ref.task.id,
          actor: actor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<ProjectStore>();
    final selectedDayRefs = _taskRefsForDay(selectedDay);
    final demand = _demandFor(selectedDay);
    final signups = [...?demand?.signups]
      ..sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? ''));

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
          calendarBuilders: CalendarBuilders(defaultBuilder: _dayBuilder),
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
        const SizedBox(height: 10),
        Text(
          "🙋 Helferbedarf am ${selectedDay.day}.${selectedDay.month}.${selectedDay.year}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        if (demand == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text("Kein Helferbedarf an diesem Tag"),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  "${signups.length} von ${demand.neededCount} Helfer bestätigt"
                  "${demand.note.isEmpty ? '' : ' · ${demand.note}'}",
                ),
              ),
              AuditInfoIcon(history: demand.history),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: "Bedarf entfernen",
                onPressed: () =>
                    store.removeHelperDemand(widget.project.id, demand.id),
              ),
            ],
          ),
          ...signups.map((signup) {
            final time = [signup.startTime, signup.endTime]
                .where((t) => t != null && t.isNotEmpty)
                .join(' – ');
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline, size: 18),
              title: Text(signup.name),
              subtitle: time.isEmpty ? null : Text(time),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: "Zusage entfernen",
                onPressed: () => store.removeHelperSignup(
                    widget.project.id, demand.id, signup.id),
              ),
            );
          }),
        ],
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => _showSignupDialog(context),
              child: const Text("🙋 Helfer eintragen"),
            ),
            OutlinedButton(
              onPressed: () => _showDemandDialog(context),
              child: const Text("➕ Bedarf eintragen"),
            ),
          ],
        ),
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

  void _showDemandDialog(BuildContext context) {
    final store = context.read<ProjectStore>();
    final actor = context.read<SettingsStore>().currentUserKurzzeichen;
    final countController = TextEditingController(text: '1');
    final noteController = TextEditingController();
    DateTime from = selectedDay;
    DateTime to = selectedDay;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Helferbedarf eintragen"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        "Zeitraum: ${from.day}.${from.month}.${from.year}"
                        " – ${to.day}.${to.month}.${to.year}"),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            setDialogState(() {
                              from = selectedDay;
                              to = selectedDay;
                            });
                          },
                          child: const Text("Nur dieser Tag"),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            setDialogState(() {
                              from = selectedDay;
                              to = selectedDay.add(const Duration(days: 6));
                            });
                          },
                          child: const Text("Ganze Woche"),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: from,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 365)),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                from = picked;
                                if (to.isBefore(from)) to = from;
                              });
                            }
                          },
                          child: const Text("Von…"),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: to,
                              firstDate: from,
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDialogState(() => to = picked);
                            }
                          },
                          child: const Text("Bis…"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: countController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Benötigte Helfer pro Tag *",
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: "Notiz"),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Abbrechen"),
                ),
                ElevatedButton(
                  onPressed: () {
                    final count = int.tryParse(countController.text.trim());
                    if (count == null || count <= 0) return;
                    store.setHelperDemand(
                      widget.project.id,
                      from: from,
                      to: to,
                      neededCount: count,
                      note: noteController.text.trim(),
                      actor: actor,
                    );
                    Navigator.pop(dialogContext);
                  },
                  child: const Text("Speichern"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSignupDialog(BuildContext context) {
    final store = context.read<ProjectStore>();
    final actor = context.read<SettingsStore>().currentUserKurzzeichen;
    final nameController = TextEditingController();
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    DateTime from = selectedDay;
    DateTime to = selectedDay;

    String formatTime(TimeOfDay time) =>
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Helfer eintragen"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Name *"),
                    ),
                    const SizedBox(height: 10),
                    Text(
                        "Zeitraum: ${from.day}.${from.month}.${from.year}"
                        " – ${to.day}.${to.month}.${to.year}"),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            setDialogState(() {
                              from = selectedDay;
                              to = selectedDay;
                            });
                          },
                          child: const Text("Nur dieser Tag"),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            setDialogState(() {
                              from = selectedDay;
                              to = selectedDay.add(const Duration(days: 6));
                            });
                          },
                          child: const Text("Ganze Woche"),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: from,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 365)),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                from = picked;
                                if (to.isBefore(from)) to = from;
                              });
                            }
                          },
                          child: const Text("Von…"),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: to,
                              firstDate: from,
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDialogState(() => to = picked);
                            }
                          },
                          child: const Text("Bis…"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: startTime ??
                                    const TimeOfDay(hour: 8, minute: 0),
                              );
                              if (picked != null) {
                                setDialogState(() => startTime = picked);
                              }
                            },
                            child: Text(startTime == null
                                ? "Von…"
                                : "Von ${formatTime(startTime!)}"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: endTime ??
                                    const TimeOfDay(hour: 12, minute: 0),
                              );
                              if (picked != null) {
                                setDialogState(() => endTime = picked);
                              }
                            },
                            child: Text(endTime == null
                                ? "Bis…"
                                : "Bis ${formatTime(endTime!)}"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Abbrechen"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) return;
                    store.addHelperSignupForRange(
                      widget.project.id,
                      from: from,
                      to: to,
                      name: nameController.text.trim(),
                      startTime:
                          startTime == null ? null : formatTime(startTime!),
                      endTime: endTime == null ? null : formatTime(endTime!),
                      actor: actor,
                    );
                    Navigator.pop(dialogContext);
                  },
                  child: const Text("Speichern"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
