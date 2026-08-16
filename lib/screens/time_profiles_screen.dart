import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/time_tracking.dart';
import '../state/project_store.dart';
import '../utils/id_generator.dart';
import '../utils/time_picker_24h.dart';
import '../widgets/app_bar.dart';

const _weekdayLabels = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

String _formatTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

TimeOfDay _parseTime(String hhmm) {
  final parts = hhmm.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

// Eine Zeile je Wochentag statt einer langen, schwer lesbaren Zeile –
// übersichtlicher für Profile mit vielen Arbeitstagen.
Widget _scheduleTable(WorkTimeProfile profile) {
  if (profile.schedules.isEmpty) {
    return const Text(
      "Keine Arbeitstage hinterlegt",
      style: TextStyle(color: Colors.grey),
    );
  }
  final sorted = [...profile.schedules]
    ..sort((a, b) => a.weekday.compareTo(b.weekday));
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: sorted
        .map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(_weekdayLabels[s.weekday - 1]),
                  ),
                  Text(
                    "${s.startTime}–${s.endTime}",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (s.breakMinutes > 0)
                    Text(
                      "  ·  ${s.breakMinutes} min Pause",
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                ],
              ),
            ))
        .toList(),
  );
}

class TimeProfilesScreen extends StatelessWidget {
  final String projectId;

  const TimeProfilesScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProjectStore>();
    final project = store.projects.firstWhere((p) => p.id == projectId);
    final profiles = project.workTimeProfiles;

    return Scaffold(
      appBar: buildAppBar(
        "Arbeitszeit-Profile",
        context,
        true,
        onCreate: () => _showProfileEditorDialog(context, projectId, null),
        createTooltip: "Neues Profil",
      ),
      body: profiles.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "Noch keine Profile angelegt. Mit dem + oben rechts ein "
                "Profil wie \"Kurzer Tag\" oder \"Lange Woche\" anlegen.",
              ),
            )
          : RadioGroup<String?>(
              groupValue: project.activeWorkTimeProfileId,
              onChanged: (value) =>
                  store.setActiveWorkTimeProfile(projectId, profileId: value),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: profiles.length + 1,
                itemBuilder: (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      "Nur ein Profil kann gleichzeitig aktiv sein (Radiobox "
                      "links). Helfer, die an einem Tag eingetragen werden, "
                      "der im aktiven Profil ein Arbeitstag ist, werden "
                      "automatisch mit den passenden Stunden in die "
                      "Zeitstatistik übernommen.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                final profile = profiles[index - 1];
                final isActive = project.activeWorkTimeProfileId == profile.id;
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: isActive
                        ? const BorderSide(color: Colors.teal, width: 2)
                        : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Radio<String?>(value: profile.id),
                            Expanded(
                              child: Text(
                                profile.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: "Profil bearbeiten",
                              onPressed: () => _showProfileEditorDialog(
                                  context, projectId, profile),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: "Profil löschen",
                              onPressed: () => store.removeWorkTimeProfile(
                                  projectId, profile.id),
                            ),
                          ],
                        ),
                        if (isActive)
                          const Padding(
                            padding: EdgeInsets.only(left: 40, bottom: 6),
                            child: Text(
                              "Aktiv",
                              style: TextStyle(
                                color: Colors.teal,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(left: 40),
                          child: _scheduleTable(profile),
                        ),
                      ],
                    ),
                  ),
                );
              },
              ),
            ),
    );
  }
}

class _WeekdayRowState {
  bool enabled;
  TimeOfDay start;
  TimeOfDay end;
  final TextEditingController breakController;

  _WeekdayRowState({
    required this.enabled,
    required this.start,
    required this.end,
    required int breakMinutes,
  }) : breakController = TextEditingController(text: '$breakMinutes');
}

void _showProfileEditorDialog(
  BuildContext context,
  String projectId,
  WorkTimeProfile? existing,
) {
  final store = context.read<ProjectStore>();
  final nameController = TextEditingController(text: existing?.name ?? '');
  final rows = List.generate(7, (i) {
    final weekday = i + 1;
    final schedule = existing?.scheduleFor(weekday);
    return _WeekdayRowState(
      enabled: schedule != null,
      start: schedule == null
          ? const TimeOfDay(hour: 7, minute: 0)
          : _parseTime(schedule.startTime),
      end: schedule == null
          ? const TimeOfDay(hour: 17, minute: 0)
          : _parseTime(schedule.endTime),
      breakMinutes: schedule?.breakMinutes ?? 0,
    );
  });

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title:
                Text(existing == null ? "Neues Profil" : "Profil bearbeiten"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Name *",
                      hintText: "z.B. Kurzer Tag, Lange Woche",
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < 7; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(_weekdayLabels[i]),
                            value: rows[i].enabled,
                            onChanged: (value) => setDialogState(
                                () => rows[i].enabled = value ?? false),
                          ),
                          if (rows[i].enabled)
                            Padding(
                              padding: const EdgeInsets.only(left: 32),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        final picked = await show24hTimePicker(
                                          context: context,
                                          initialTime: rows[i].start,
                                        );
                                        if (picked != null) {
                                          setDialogState(
                                              () => rows[i].start = picked);
                                        }
                                      },
                                      child: Text(
                                          "Von ${_formatTime(rows[i].start)}"),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        final picked = await show24hTimePicker(
                                          context: context,
                                          initialTime: rows[i].end,
                                        );
                                        if (picked != null) {
                                          setDialogState(
                                              () => rows[i].end = picked);
                                        }
                                      },
                                      child: Text(
                                          "Bis ${_formatTime(rows[i].end)}"),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    width: 72,
                                    child: TextField(
                                      controller: rows[i].breakController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: "Pause",
                                        suffixText: "min",
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
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
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final schedules = <WeekdaySchedule>[];
                  for (var i = 0; i < 7; i++) {
                    if (!rows[i].enabled) continue;
                    schedules.add(WeekdaySchedule(
                      weekday: i + 1,
                      startTime: _formatTime(rows[i].start),
                      endTime: _formatTime(rows[i].end),
                      breakMinutes:
                          int.tryParse(rows[i].breakController.text.trim()) ??
                              0,
                    ));
                  }
                  final profile = WorkTimeProfile(
                    id: existing?.id ?? newId(),
                    name: name,
                    schedules: schedules,
                  );
                  if (existing == null) {
                    store.addWorkTimeProfile(projectId, profile);
                  } else {
                    store.updateWorkTimeProfile(projectId, profile);
                  }
                  Navigator.pop(dialogContext);
                },
                child: const Text("Speichern"),
              ),
            ],
          );
        },
      );
    },
  ).then((_) {
    nameController.dispose();
    for (final row in rows) {
      row.breakController.dispose();
    }
  });
}
