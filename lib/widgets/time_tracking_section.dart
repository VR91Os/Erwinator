import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/project.dart';
import '../models/time_tracking.dart';
import '../screens/time_profiles_screen.dart';
import '../state/project_store.dart';
import '../state/settings_store.dart';
import '../utils/light_surface_colors.dart';

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
              onPressed: () => _showApplyProfileDialog(context, project),
              icon: const Icon(Icons.event_available, size: 18),
              label: const Text("Zeit erfassen"),
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
            "Profil ein Arbeitstag ist. \"Ich bin auf der Baustelle\" und "
            "\"Zeit erfassen\" tragen zusätzlich zu diesen Stunden bei, "
            "statt sie zu ersetzen. Tag antippen zeigt die Details.",
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

void _showApplyProfileDialog(BuildContext context, Project project) {
  if (project.workTimeProfiles.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Zuerst unter \"Profile verwalten\" ein Arbeitszeitprofil anlegen.",
        ),
      ),
    );
    return;
  }

  final store = context.read<ProjectStore>();
  final actor = context.read<SettingsStore>().currentUserKurzzeichen;
  WorkTimeProfile selectedProfile =
      project.activeWorkTimeProfile ?? project.workTimeProfiles.first;
  DateTime from = DateTime.now();
  DateTime to = DateTime.now();

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Zeit erfassen"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      "Wird zu den an den gewählten Tagen bereits erfassten "
                      "Stunden dazugerechnet – z.B. für einen zusätzlich, "
                      "später oder früher hinzukommenden Helfer.",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  DropdownButtonFormField<WorkTimeProfile>(
                    initialValue: selectedProfile,
                    decoration: const InputDecoration(labelText: "Profil"),
                    items: project.workTimeProfiles
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.name),
                            ))
                        .toList(),
                    onChanged: (value) => setDialogState(
                        () => selectedProfile = value ?? selectedProfile),
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
                            from = DateTime.now();
                            to = DateTime.now();
                          });
                        },
                        child: const Text("Nur heute"),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          setDialogState(() {
                            from = DateTime.now();
                            to = DateTime.now().add(const Duration(days: 6));
                          });
                        },
                        child: const Text("Diese Woche"),
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
                  store.applyWorkTimeProfile(
                    project.id,
                    profile: selectedProfile,
                    from: from,
                    to: to,
                    actor: actor,
                  );
                  Navigator.pop(dialogContext);
                },
                child: const Text("Anwenden"),
              ),
            ],
          );
        },
      );
    },
  );
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
