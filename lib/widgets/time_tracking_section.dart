import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/project.dart';
import '../models/time_tracking.dart';
import '../screens/time_profiles_screen.dart';
import '../state/project_store.dart';
import '../state/settings_store.dart';
import '../utils/light_surface_colors.dart';
import '../utils/time_picker_24h.dart';

String _formatTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _formatHours(double hours) {
  final rounded = (hours * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? '${rounded.toInt()}'
      : rounded.toString().replaceAll('.', ',');
}

// Projektweites, optionales Modul: wertet die über "Helfer eintragen" im
// Überblick erfassten Zusagen aus (Stunden aus dem aktiven Arbeitszeitprofil
// für Tage, die dort ein Arbeitstag sind). Die Zeitstatistik selbst ist nur
// Auswertung – Helfer werden ausschließlich im Überblick eingetragen.
class TimeTrackingSection extends StatefulWidget {
  final Project project;

  const TimeTrackingSection({super.key, required this.project});

  @override
  State<TimeTrackingSection> createState() => _TimeTrackingSectionState();
}

class _TimeTrackingSectionState extends State<TimeTrackingSection> {
  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;
  CalendarFormat calendarFormat = CalendarFormat.month;

  WorkDayEntry? _entryFor(DateTime day) {
    for (final entry in widget.project.workDayEntries) {
      if (isSameDay(entry.date, day)) return entry;
    }
    return null;
  }

  double get _totalHours => widget.project.workDayEntries
      .fold(0.0, (sum, e) => sum + e.hours);

  Widget? _dayBuilder(BuildContext context, DateTime day, DateTime focused) {
    final entry = _entryFor(day);
    if (entry == null) return null;

    if (!widget.project.extendedTimeCalendar) {
      return Stack(
        alignment: Alignment.center,
        children: [
          // Hintergrund bleibt Standard (nicht fest hell), daher hier keine
          // feste Textfarbe nötig - anders als unten (fest teal.shade50).
          Text('${day.day}'),
          Positioned(
            bottom: 2,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.teal,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${day.day}',
              style: const TextStyle(color: lightSurfaceTextColor)),
          Text(
            '${_formatHours(entry.hours)}h',
            style: const TextStyle(fontSize: 9, color: Colors.teal),
          ),
          if (entry.helperNames.isNotEmpty)
            Text(
              '👥${entry.helperNames.length}',
              style: const TextStyle(fontSize: 9, color: lightSurfaceTextColor),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<ProjectStore>();
    final project = widget.project;
    final extended = project.extendedTimeCalendar;
    final loggedDays = project.workDayEntries.length;
    final activeProfile = project.activeWorkTimeProfile;
    final todaySchedule = activeProfile?.scheduleFor(DateTime.now().weekday);
    final selectedEntry =
        selectedDay == null ? null : _entryFor(selectedDay!);

    return ListView(
      children: [
        const Text(
          "🕒 Zeitstatistik",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          loggedDays == 0
              ? "Noch keine Arbeitszeit erfasst"
              : "${_formatHours(_totalHours)} Std insgesamt an $loggedDays "
                  "${loggedDays == 1 ? 'Tag' : 'Tagen'} erfasst",
        ),
        const SizedBox(height: 4),
        Text(
          activeProfile == null
              ? "Kein aktives Profil – unter \"Profile verwalten\" eines "
                  "per Radiobox aktivieren."
              : todaySchedule == null
                  ? "Aktives Profil: ${activeProfile.name} – heute laut "
                      "Profil kein Arbeitstag"
                  : "Aktives Profil: ${activeProfile.name} – heute "
                      "${_formatHours(todaySchedule.hours)} Std Arbeitstag",
          style: TextStyle(color: Colors.teal.shade700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      TimeProfilesScreen(projectId: project.id),
                ),
              ),
              icon: const Icon(Icons.tune, size: 18),
              label: const Text("Profile verwalten"),
            ),
            OutlinedButton.icon(
              onPressed: () => _showManualTimeDialog(context, project),
              icon: const Icon(Icons.event_available, size: 18),
              label: const Text("Manuell Zeit hinzufügen"),
            ),
            OutlinedButton.icon(
              onPressed: () => _showQuickHoursDialog(context, project),
              icon: const Icon(Icons.add_alarm, size: 18),
              label: const Text("Manuell Stunden hinzufügen"),
            ),
          ],
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text("Erweiterter Kalender"),
          subtitle: const Text(
            "Zeigt Stunden/Helferanzahl direkt im Kalender und erlaubt "
            "Wochen-/Monatsansicht statt nur Monat.",
          ),
          value: extended,
          onChanged: (value) => store.updateExtendedTimeCalendar(
            project.id,
            enabled: value ?? false,
          ),
        ),
        TableCalendar(
          locale: 'de_DE',
          startingDayOfWeek: StartingDayOfWeek.monday,
          firstDay: DateTime.now()
              .subtract(Duration(days: extended ? 730 : 180)),
          lastDay:
              DateTime.now().add(Duration(days: extended ? 730 : 60)),
          focusedDay: focusedDay,
          calendarFormat: calendarFormat,
          availableCalendarFormats: extended
              ? const {
                  CalendarFormat.month: 'Monat',
                  CalendarFormat.twoWeeks: '2 Wochen',
                  CalendarFormat.week: 'Woche',
                }
              : const {CalendarFormat.month: 'Monat'},
          headerStyle: HeaderStyle(
            formatButtonVisible: extended,
            titleCentered: true,
          ),
          onFormatChanged: (format) =>
              setState(() => calendarFormat = format),
          selectedDayPredicate: (day) =>
              selectedDay != null && isSameDay(day, selectedDay),
          onDaySelected: (selected, focused) {
            setState(() {
              focusedDay = focused;
              selectedDay = selected;
            });
          },
          calendarBuilders: CalendarBuilders(defaultBuilder: _dayBuilder),
          // ✅ Gleiche Farbcodierung wie der Kalender im Überblick: Heute =
          // blau, angeklickt/ausgewählt = lila.
          calendarStyle: const CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(color: Colors.white),
            selectedDecoration: BoxDecoration(
              color: Colors.purple,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: TextStyle(color: Colors.white),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            "Helfer werden im Überblick über \"Helfer eintragen\" erfasst "
            "und erscheinen hier automatisch, wenn der Tag laut aktivem "
            "Profil ein Arbeitstag ist. \"Ich bin auf der Baustelle\", "
            "\"Manuell Zeit hinzufügen\" und \"Manuell Stunden hinzufügen\" "
            "tragen zusätzlich zu diesen Stunden bei, statt sie zu "
            "ersetzen. Tag antippen zeigt die Details.",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        if (selectedDay != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: selectedEntry == null
                ? Text(
                    "${selectedDay!.day}.${selectedDay!.month}."
                    "${selectedDay!.year}: keine Zeit erfasst",
                    style: const TextStyle(color: Colors.grey),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "${selectedDay!.day}.${selectedDay!.month}."
                              "${selectedDay!.year}: "
                              "${_formatHours(selectedEntry.hours)} Std",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: "Tag korrigieren",
                            onPressed: () => _showEditDayDialog(
                                context, project, selectedEntry),
                          ),
                        ],
                      ),
                      if (selectedEntry.helperNames.isEmpty)
                        const Text("Keine Helfer eingetragen")
                      else
                        Text(
                          "Helfer: ${selectedEntry.helperNames.map((p) => p.person).join(', ')}",
                        ),
                    ],
                  ),
          ),
      ],
    );
  }
}

// "Manuell Zeit hinzufügen": Von/Bis/Pause + Personenzahl direkt eingeben
// (kein gespeichertes Profil mehr nötig) und die Stunden auf beliebig viele,
// frei per Kalender antippbare (nicht zwingend zusammenhängende) Tage
// anwenden.
void _showManualTimeDialog(BuildContext context, Project project) {
  final store = context.read<ProjectStore>();
  final actor = context.read<SettingsStore>().currentUserKurzzeichen;
  var personCount = 1;
  var start = const TimeOfDay(hour: 7, minute: 0);
  var end = const TimeOfDay(hour: 17, minute: 0);
  final breakController = TextEditingController(text: '0');
  final selectedDays = <DateTime>{};
  var calendarFocusedDay = DateTime.now();

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final breakMinutes =
              int.tryParse(breakController.text.trim()) ?? 0;
          final perPersonHours = WeekdaySchedule(
            weekday: 1,
            startTime: _formatTime(start),
            endTime: _formatTime(end),
            breakMinutes: breakMinutes,
          ).hours;
          final totalHours = perPersonHours * personCount;
          return AlertDialog(
            title: const Text("Manuell Zeit hinzufügen"),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        "Wird zu den an den gewählten Tagen bereits "
                        "erfassten Stunden dazugerechnet – z.B. für einen "
                        "zusätzlich, später oder früher hinzukommenden "
                        "Helfer.",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                    Row(
                      children: [
                        const Text("Personen"),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: personCount > 1
                              ? () =>
                                  setDialogState(() => personCount--)
                              : null,
                        ),
                        Text(
                          '$personCount',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () =>
                              setDialogState(() => personCount++),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await show24hTimePicker(
                                  context: context, initialTime: start);
                              if (picked != null) {
                                setDialogState(() => start = picked);
                              }
                            },
                            child: Text("Von ${_formatTime(start)}"),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await show24hTimePicker(
                                  context: context, initialTime: end);
                              if (picked != null) {
                                setDialogState(() => end = picked);
                              }
                            },
                            child: Text("Bis ${_formatTime(end)}"),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: breakController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Pause",
                              suffixText: "min",
                              isDense: true,
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "${_formatHours(perPersonHours)} Std/Person"
                      "${personCount > 1 ? ' × $personCount = ${_formatHours(totalHours)} Std' : ''} "
                      "je ausgewähltem Tag",
                      style: TextStyle(color: Colors.teal.shade700),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      selectedDays.isEmpty
                          ? "Noch keine Tage ausgewählt – Tage im Kalender "
                              "antippen."
                          : "${selectedDays.length} Tag"
                              "${selectedDays.length == 1 ? '' : 'e'} "
                              "ausgewählt",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(
                      height: 300,
                      child: TableCalendar(
                        locale: 'de_DE',
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        firstDay: DateTime.now()
                            .subtract(const Duration(days: 365)),
                        lastDay:
                            DateTime.now().add(const Duration(days: 365)),
                        focusedDay: calendarFocusedDay,
                        rowHeight: 34,
                        daysOfWeekHeight: 16,
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleTextStyle: TextStyle(fontSize: 14),
                        ),
                        selectedDayPredicate: (day) =>
                            selectedDays.any((d) => isSameDay(d, day)),
                        onDaySelected: (selected, focused) {
                          setDialogState(() {
                            calendarFocusedDay = focused;
                            final match = selectedDays
                                .where((d) => isSameDay(d, selected))
                                .toList();
                            if (match.isNotEmpty) {
                              selectedDays.removeAll(match);
                            } else {
                              selectedDays.add(selected);
                            }
                          });
                        },
                        calendarStyle: const CalendarStyle(
                          todayDecoration: BoxDecoration(
                              color: Colors.blue, shape: BoxShape.circle),
                          todayTextStyle: TextStyle(color: Colors.white),
                          selectedDecoration: BoxDecoration(
                              color: Colors.purple, shape: BoxShape.circle),
                          selectedTextStyle: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Abbrechen"),
              ),
              ElevatedButton(
                onPressed: selectedDays.isEmpty || perPersonHours <= 0
                    ? null
                    : () {
                        store.addManualTimeEntry(
                          project.id,
                          days: selectedDays,
                          startTime: _formatTime(start),
                          endTime: _formatTime(end),
                          breakMinutes: breakMinutes,
                          personCount: personCount,
                          actor: actor,
                        );
                        Navigator.pop(dialogContext);
                      },
                child: const Text("Hinzufügen"),
              ),
            ],
          );
        },
      );
    },
  ).then((_) => breakController.dispose());
}

// "Manuell Stunden hinzufügen": schneller Zugang ohne Zeitraum/Personenzahl
// - addiert eine direkt eingetippte Stundenzahl zu HEUTE dazu, optional mit
// einer Notiz (landet im Verlauf des Tages).
void _showQuickHoursDialog(BuildContext context, Project project) {
  final store = context.read<ProjectStore>();
  final actor = context.read<SettingsStore>().currentUserKurzzeichen;
  final hoursController = TextEditingController();
  final noteController = TextEditingController();

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text("Manuell Stunden hinzufügen"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Wird zu den heute bereits erfassten Stunden dazugerechnet.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: hoursController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Stunden",
                suffixText: "Std",
              ),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: "Notiz (optional)"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Abbrechen"),
          ),
          ElevatedButton(
            onPressed: () {
              final hours = double.tryParse(
                  hoursController.text.trim().replaceAll(',', '.'));
              if (hours == null || hours <= 0) return;
              store.addQuickHourEntry(
                project.id,
                hours: hours,
                note: noteController.text,
                actor: actor,
              );
              Navigator.pop(dialogContext);
            },
            child: const Text("Hinzufügen"),
          ),
        ],
      );
    },
  ).then((_) {
    hoursController.dispose();
    noteController.dispose();
  });
}

// Korrektur eines einzelnen bereits erfassten Tages: Stunden direkt
// überschreiben (anders als die additiven Erfassungswege) oder einzelne
// Helfer/den ganzen Tag entfernen - für versehentliche Mehrfach-Erfassungen.
void _showEditDayDialog(
  BuildContext context,
  Project project,
  WorkDayEntry entry,
) {
  final store = context.read<ProjectStore>();
  final actor = context.read<SettingsStore>().currentUserKurzzeichen;
  final hoursController =
      TextEditingController(text: _formatHours(entry.hours));

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              "Zeit korrigieren – ${entry.date.day}.${entry.date.month}."
              "${entry.date.year}",
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: hoursController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: "Stunden",
                      suffixText: "Std",
                    ),
                    autofocus: true,
                  ),
                  if (entry.helperNames.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text("Helfer",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ...entry.helperNames.map((p) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(p.person),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: "Helfer entfernen",
                            onPressed: () {
                              store.removeWorkDayHelper(
                                  project.id, entry.id, p.person);
                              setDialogState(() {});
                            },
                          ),
                        )),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _confirmDeleteDay(context, store, project, entry);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("Tag löschen"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Abbrechen"),
              ),
              ElevatedButton(
                onPressed: () {
                  final hours = double.tryParse(
                      hoursController.text.trim().replaceAll(',', '.'));
                  if (hours == null || hours < 0) return;
                  store.updateWorkDayEntryHours(
                    project.id,
                    entry.id,
                    hours: hours,
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
  ).then((_) => hoursController.dispose());
}

void _confirmDeleteDay(
  BuildContext context,
  ProjectStore store,
  Project project,
  WorkDayEntry entry,
) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Tag löschen?"),
      content: Text(
        "Die erfassten ${_formatHours(entry.hours)} Std am "
        "${entry.date.day}.${entry.date.month}.${entry.date.year} werden "
        "entfernt.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text("Abbrechen"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            store.removeWorkDayEntry(project.id, entry.id);
            Navigator.pop(dialogContext);
          },
          child: const Text("Löschen"),
        ),
      ],
    ),
  );
}
