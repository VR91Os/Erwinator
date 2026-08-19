import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/helper_demand.dart';
import '../models/modules/todo_module.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../state/project_store.dart';
import '../state/settings_store.dart';
import '../utils/light_surface_colors.dart';
import '../utils/name_capitalization.dart';
import '../utils/safe_notify.dart';
import '../utils/task_urgency.dart';
import '../utils/time_picker_24h.dart';
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
      final color = taskUrgencyColor(ref.task,
          warningDays: widget.project.priorityWarningDays);
      if (color == prioWarningColor) {
        return color;
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
      margin: const EdgeInsets.all(2),
      decoration:
          color == null ? null : BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          fontSize: 13,
          color: color == null ? null : lightSurfaceTextColor,
        ),
      ),
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
          locale: 'de_DE',
          startingDayOfWeek: StartingDayOfWeek.monday,
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
          // ✅ Kompakter als der Standard (deutlich weniger Höhe), da der
          // Kalender im Überblick nur einer von mehreren Abschnitten ist.
          rowHeight: 38,
          daysOfWeekHeight: 14,
          headerStyle: const HeaderStyle(
            titleTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            headerPadding: EdgeInsets.symmetric(vertical: 4),
            // Ohne calendarFormat/onFormatChanged hier ohnehin wirkungslos.
            formatButtonVisible: false,
          ),
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(fontSize: 11, color: Colors.grey),
            weekendStyle: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          calendarStyle: CalendarStyle(
            cellMargin: const EdgeInsets.all(2),
            defaultTextStyle: const TextStyle(fontSize: 13),
            weekendTextStyle: const TextStyle(fontSize: 13),
            outsideTextStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            // ✅ Heute = blau, angeklickt/ausgewählt = lila - eindeutig
            // unterscheidbar statt der ähnlichen Blautöne des Paket-Standards.
            todayDecoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            todayTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
            selectedDecoration: const BoxDecoration(
              color: Colors.purple,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
          ),
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
                    final note = noteController.text.trim();
                    popDialogThen(
                      dialogContext,
                      () => store.setHelperDemand(
                        widget.project.id,
                        from: from,
                        to: to,
                        neededCount: count,
                        note: note,
                        actor: actor,
                      ),
                    );
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
    // ✅ Standard-Zeitraum 07:00-17:00, außer das Zeitstatistik-Modul hat
    // für diesen Wochentag ein aktives Profil hinterlegt - dann werden
    // dessen Zeiten übernommen, statt einen abweichenden zweiten
    // "Standard" zu erfinden.
    final activeSchedule =
        widget.project.activeWorkTimeProfile?.scheduleFor(selectedDay.weekday);
    final usesProfileDefault = activeSchedule != null;
    TimeOfDay startTime = (usesProfileDefault
            ? parseTimeOfDay(activeSchedule.startTime)
            : null) ??
        const TimeOfDay(hour: 7, minute: 0);
    TimeOfDay endTime = (usesProfileDefault
            ? parseTimeOfDay(activeSchedule.endTime)
            : null) ??
        const TimeOfDay(hour: 17, minute: 0);
    DateTime from = selectedDay;
    DateTime to = selectedDay;
    // ✅ Uhrzeit ist nicht immer relevant (z.B. reine Tageszusage ohne
    // festen Zeitrahmen) - deshalb per Checkbox einblendbar statt immer
    // erzwungen sichtbar, standardmäßig aus.
    bool showTime = false;

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
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: const [NameCapitalizationFormatter()],
                      decoration: const InputDecoration(
                        labelText: "Name *",
                        helperText: "Mehrere Personen mit Komma trennen",
                      ),
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
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      title: const Text("Uhrzeit angeben"),
                      value: showTime,
                      onChanged: (value) =>
                          setDialogState(() => showTime = value ?? false),
                    ),
                    if (showTime) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await show24hTimePicker(
                                  context: context,
                                  initialTime: startTime,
                                );
                                if (picked == null) return;
                                setDialogState(() => startTime = picked);
                                // ✅ Direkt weiter zur Bis-Auswahl, statt
                                // dafür extra den zweiten Button antippen zu
                                // müssen.
                                if (!context.mounted) return;
                                final pickedEnd = await show24hTimePicker(
                                  context: context,
                                  initialTime: endTime,
                                );
                                if (pickedEnd != null) {
                                  setDialogState(() => endTime = pickedEnd);
                                }
                              },
                              child: Text("Von ${formatTime(startTime)}"),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await show24hTimePicker(
                                  context: context,
                                  initialTime: endTime,
                                );
                                if (picked != null) {
                                  setDialogState(() => endTime = picked);
                                }
                              },
                              child: Text("Bis ${formatTime(endTime)}"),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          usesProfileDefault
                              ? "Standardmäßig aus dem aktiven Profil "
                                  "\"${widget.project.activeWorkTimeProfile!.name}\" "
                                  "übernommen, weiter änderbar."
                              : "Standardmäßig wird 07:00–17:00 eingetragen, "
                                  "weiter änderbar.",
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ),
                    ],
                    if (widget.project.activeWorkTimeProfile != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          "Ist ein Tag im Zeitraum laut aktivem Profil "
                          "\"${widget.project.activeWorkTimeProfile!.name}\" "
                          "ein Arbeitstag, zählt die Zusage automatisch mit "
                          "in die Zeitstatistik.",
                          style: TextStyle(
                              color: Colors.teal.shade700, fontSize: 12),
                        ),
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
                    final names = splitNames(nameController.text);
                    if (names.isEmpty) return;
                    popDialogThen(dialogContext, () {
                      for (final name in names) {
                        store.addHelperSignupForRange(
                          widget.project.id,
                          from: from,
                          to: to,
                          name: name,
                          startTime: showTime ? formatTime(startTime) : null,
                          endTime: showTime ? formatTime(endTime) : null,
                          actor: actor,
                        );
                      }
                    });
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
