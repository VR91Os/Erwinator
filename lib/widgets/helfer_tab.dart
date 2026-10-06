import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../state/project_store.dart';
import '../state/settings_store.dart';
import '../utils/excel_export.dart';
import '../utils/file_export.dart';
import '../utils/name_capitalization.dart';
import '../utils/safe_notify.dart';
import '../utils/time_picker_24h.dart';
import 'audit_info_icon.dart';
import 'helper_demand_calendar.dart';

// "Ganze Woche" meint den Rest der aktuellen Arbeitswoche bis einschließlich
// Samstag (Baustellen-Konvention Mo-Sa), nicht einfach 6 Tage ab dem
// gewählten Tag - sonst würde z.B. ein Mittwoch-Start bis in die nächste
// Woche (Dienstag) hineinreichen statt an diesem Samstag zu enden. Für
// Sonntag (kein Werktag) ergibt das den kommenden Samstag.
DateTime _endOfWorkWeek(DateTime day) =>
    day.add(Duration(days: (DateTime.saturday - day.weekday) % 7));

// Eigener Reiter für die komplette Helferbedarf-Verwaltung (Bedarf/Zusagen),
// vorher Teil von OverviewTab - inklusive einer größeren Kopie des dortigen
// Kalenders (gleiches Farbschema, siehe helper_demand_calendar.dart).
class HelferTab extends StatefulWidget {
  final Project project;

  const HelferTab({super.key, required this.project});

  @override
  State<HelferTab> createState() => _HelferTabState();
}

class _HelferTabState extends State<HelferTab> {
  DateTime selectedDay = DateTime.now();
  DateTime focusedDay = DateTime.now();

  Future<void> _exportExcel(BuildContext context) async {
    final bytes = buildHelperDemandExcel(widget.project.helperDemands);
    await exportBinaryFile(
      fileName: '${widget.project.name}_helferbedarf.xlsx',
      bytes: Uint8List.fromList(bytes),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Helferbedarf exportiert")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<ProjectStore>();
    final demand = findDemandForDay(widget.project.helperDemands, selectedDay);
    final signups = [...?demand?.signups]
      ..sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? ''));

    return ListView(
      children: [
        const Text(
          "Kalender",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        HelperDemandCalendar(
          demands: widget.project.helperDemands,
          selectedDay: selectedDay,
          focusedDay: focusedDay,
          compact: false,
          onDaySelected: (selected, focused) {
            setState(() {
              selectedDay = selected;
              focusedDay = focused;
            });
          },
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  selectedDay = DateTime.now();
                  focusedDay = DateTime.now();
                });
              },
              icon: const Icon(Icons.today, size: 16),
              label: const Text("Heute"),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _exportExcel(context),
              icon: const Icon(Icons.table_chart, size: 18),
              label: const Text("Als Excel exportieren"),
            ),
          ],
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
                              to = _endOfWorkWeek(selectedDay);
                            });
                          },
                          child: const Text("Rest der Woche"),
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
                            if (picked == null) return;
                            setDialogState(() {
                              from = picked;
                              if (to.isBefore(from)) to = from;
                            });
                            // ✅ Direkt weiter zur Bis-Auswahl, statt dafür
                            // extra den zweiten Button antippen zu müssen.
                            if (!context.mounted) return;
                            final pickedTo = await showDatePicker(
                              context: context,
                              initialDate: to,
                              firstDate: from,
                              lastDate: DateTime(2100),
                            );
                            if (pickedTo != null) {
                              setDialogState(() => to = pickedTo);
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
                              to = _endOfWorkWeek(selectedDay);
                            });
                          },
                          child: const Text("Rest der Woche"),
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
                            if (picked == null) return;
                            setDialogState(() {
                              from = picked;
                              if (to.isBefore(from)) to = from;
                            });
                            // ✅ Direkt weiter zur Bis-Auswahl, statt dafür
                            // extra den zweiten Button antippen zu müssen.
                            if (!context.mounted) return;
                            final pickedTo = await showDatePicker(
                              context: context,
                              initialDate: to,
                              firstDate: from,
                              lastDate: DateTime(2100),
                            );
                            if (pickedTo != null) {
                              setDialogState(() => to = pickedTo);
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
