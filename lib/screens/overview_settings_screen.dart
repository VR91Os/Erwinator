import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/modules/todo_module.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../state/project_store.dart';
import '../utils/file_export.dart';
import '../utils/ics_export.dart';
import '../state/settings_store.dart';
import '../utils/profile_prompt.dart';
import '../widgets/app_bar.dart';
import 'share_project_screen.dart';

// Optionen für den "Überblick"-Reiter: steuert den Export des gesamten
// Projekts (Daten + optional Kalenderdatei), nicht die App-weiten
// Einstellungen aus dem Zahnrad im Startbildschirm.
class OverviewSettingsScreen extends StatefulWidget {
  final String projectId;

  const OverviewSettingsScreen({super.key, required this.projectId});

  @override
  State<OverviewSettingsScreen> createState() =>
      _OverviewSettingsScreenState();
}

class _OverviewSettingsScreenState extends State<OverviewSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // ✅ "Neu"-Badge auf dem Zahnrad verschwindet, sobald die Optionen
    // einmal geöffnet wurden.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SettingsStore>().markFeatureHintSeen('time_tracking');
    });
  }

  List<Task> _allTasks(Project project) {
    final tasks = <Task>[];
    for (final gewerk in project.gewerke) {
      for (final module in gewerk.modules.whereType<TodoModule>()) {
        tasks.addAll(module.tasks);
      }
    }
    return tasks;
  }

  // Aufgaben, die laut den beiden Export-Checkboxen in die .ics gehören
  // (gemeinsam von _exportProject und _exportIcsOnly genutzt).
  List<Task> _icsTasks(Project project) => _allTasks(project).where((t) {
        if (t.status == 'archiviert' || t.dueDate == null) return false;
        if (project.exportAllDatedTodos) return true;
        return t.isHighPriority;
      }).toList();

  Future<void> _exportProject(BuildContext context, Project project) async {
    final json = const JsonEncoder.withIndent('  ').convert(project.toMap());
    await exportTextFile(
      fileName: '${project.name}_export.json',
      content: json,
    );

    if (project.exportAllDatedTodos || project.exportPriorityTasks) {
      final tasks = _icsTasks(project);
      if (tasks.isNotEmpty) {
        final ics = buildIcs(tasks, calendarName: project.name);
        await exportTextFile(
          fileName: '${project.name}_kalender.ics',
          content: ics,
        );
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Projekt exportiert")),
      );
    }
  }

  // Exportiert nur die .ics-Kalenderdatei, ohne den vollständigen
  // Projekt-Export – z.B. um sie erneut in einen Kalender zu importieren,
  // ohne dabei die komplette Projekt-JSON mit abzulegen.
  Future<void> _exportIcsOnly(BuildContext context, Project project) async {
    final tasks = _icsTasks(project);
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Keine passenden Aufgaben für die Kalenderdatei."),
        ),
      );
      return;
    }

    final ics = buildIcs(tasks, calendarName: project.name);
    await exportTextFile(
      fileName: '${project.name}_kalender.ics',
      content: ics,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kalenderdatei exportiert")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProjectStore>();
    final settingsStore = context.watch<SettingsStore>();
    final project = store.projects.firstWhere((p) => p.id == widget.projectId);

    return Scaffold(
      appBar: buildAppBar("Optionen – Überblick", context, true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ✅ Reihenfolge sinngemäß: alltägliche Verhaltens-Einstellungen
          // zuerst, danach optionale Module/Zusammenarbeit, Exportieren
          // (seltenste Aktion) ganz unten.
          const Text(
            "Design",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            // App-weit, nicht je Projekt - wirkt sich auch auf andere
            // Projekte aus.
            "Gilt für die ganze App, nicht nur für dieses Projekt.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'system', label: Text("System")),
              ButtonSegment(value: 'light', label: Text("Hell")),
              ButtonSegment(value: 'dark', label: Text("Dunkel")),
            ],
            selected: {settingsStore.settings.themeMode},
            onSelectionChanged: (selection) =>
                settingsStore.setThemeMode(selection.first),
          ),
          const Divider(height: 40),
          const Text(
            "Aufgaben-Status",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Normalerweise wechselt eine Aufgabe beim Antippen des "
            "Status-Symbols erst auf \"teilweise erledigt\" und danach auf "
            "\"erledigt\". Ist diese Option aktiv, springt eine offene "
            "Aufgabe direkt auf \"erledigt\".",
            style: TextStyle(color: Colors.grey),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              "Aufgaben sofort als erledigt markieren "
              "(Zwischenschritt \"teilweise erledigt\" überspringen)",
            ),
            value: project.skipPartialStatus,
            onChanged: (value) => store.updateSkipPartialStatus(
              widget.projectId,
              skipPartialStatus: value ?? false,
            ),
          ),
          const Divider(height: 40),
          const Text(
            "Warnschwelle für Prio-Aufgaben",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Ab wie vielen Tagen vor Fälligkeit eine offene Prio-Aufgabe "
            "den betroffenen Gewerk-Reiter (und den Überblick-Reiter) "
            "hellrot markiert.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: project.priorityWarningDays > 0
                    ? () => store.updatePriorityWarningSettings(
                          widget.projectId,
                          priorityWarningDays: project.priorityWarningDays - 1,
                          notifyOnPriorityWarning:
                              project.notifyOnPriorityWarning,
                        )
                    : null,
              ),
              Text(
                "${project.priorityWarningDays} "
                "${project.priorityWarningDays == 1 ? 'Tag' : 'Tage'}",
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => store.updatePriorityWarningSettings(
                  widget.projectId,
                  priorityWarningDays: project.priorityWarningDays + 1,
                  notifyOnPriorityWarning: project.notifyOnPriorityWarning,
                ),
              ),
            ],
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              "Soll eine Push-Nachricht erscheinen, wenn eine Prio-Aufgabe "
              "die Warnschwelle erreicht hat?",
            ),
            value: project.notifyOnPriorityWarning,
            onChanged: (value) => store.updatePriorityWarningSettings(
              widget.projectId,
              priorityWarningDays: project.priorityWarningDays,
              notifyOnPriorityWarning: value ?? false,
            ),
          ),
          const Divider(height: 40),
          const Text(
            "Kontaktdaten",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Ist die Checkbox aus, bleibt das Kontakt-Modul auf Name und "
            "Telefonnummer beschränkt. Aktiviert zeigt jede Person "
            "zusätzlich ein Email-Feld (manuell hinzufügen und bei "
            "bestehenden Personen).",
            style: TextStyle(color: Colors.grey),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Auch Email angeben"),
            value: project.showContactEmail,
            onChanged: (value) => store.updateShowContactEmail(
              widget.projectId,
              enabled: value ?? false,
            ),
          ),
          const Divider(height: 40),
          const Text(
            "Zeitstatistik",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Optionales Modul im Überblick-Reiter, um die gesamte am "
            "Projekt gearbeitete Zeit über Arbeitszeitprofile und einen "
            "Kalender zu erfassen.",
            style: TextStyle(color: Colors.grey),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Zeitstatistik-Modul aktivieren"),
            value: project.timeTrackingEnabled,
            onChanged: (value) => store.updateTimeTrackingEnabled(
              widget.projectId,
              enabled: value ?? false,
            ),
          ),
          const Divider(height: 40),
          const Text(
            "Finanzen",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Optionales Modul für Angebote/Rechnungen: Beträge können "
            "jederzeit manuell erfasst werden (\"Eintrag hinzufügen\" im "
            "Finanzen-Modul eines Gewerks oder in der Finanzen-Übersicht) "
            "und werden zusätzlich bei PDF-Uploads automatisch erkannt und "
            "vorgeschlagen (immer manuell zu bestätigen). Fasst alle "
            "Einträge projektweit sowie je Gewerk zusammen. Legt keine "
            "Dateien doppelt ab, nur die Betragsdaten.",
            style: TextStyle(color: Colors.grey),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Finanzen-Modul aktivieren"),
            value: project.financeEnabled,
            onChanged: (value) => store.updateFinanceEnabled(
              widget.projectId,
              enabled: value ?? false,
            ),
          ),
          const Divider(height: 40),
          const Text(
            "Projekt teilen",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            project.sharedId == null
                ? "Erzeugt einen Einladungscode/QR-Code, mit dem andere "
                    "beitreten können. Du musst jede Anfrage bestätigen."
                : "Bereits geteilt – hier Einladungscode anzeigen oder "
                    "offene Beitrittsanfragen bestätigen.",
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              final proceed = await ensureProfileForSharing(context);
              if (!proceed || !context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ShareProjectScreen(projectId: widget.projectId),
                ),
              );
            },
            icon: const Icon(Icons.group_add),
            label: Text(
              project.sharedId == null ? "Projekt teilen" : "Teilen verwalten",
            ),
          ),
          const Divider(height: 40),
          const Text(
            "Exportieren",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Alle ToDos mit Datum in Kalender exportieren"),
            value: project.exportAllDatedTodos,
            onChanged: (value) => store.updateExportPrefs(
              widget.projectId,
              exportAllDatedTodos: value ?? false,
              exportPriorityTasks: project.exportPriorityTasks,
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Prio-Aufgaben exportieren"),
            value: project.exportPriorityTasks,
            onChanged: (value) => store.updateExportPrefs(
              widget.projectId,
              exportAllDatedTodos: project.exportAllDatedTodos,
              exportPriorityTasks: value ?? false,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Ist eine der Checkboxen aktiv, wird beim Export zusätzlich eine "
            ".ics-Kalenderdatei erzeugt – importierbar in Google Kalender, "
            "Outlook etc.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed:
                (project.exportAllDatedTodos || project.exportPriorityTasks)
                    ? () => _exportIcsOnly(context, project)
                    : null,
            icon: const Icon(Icons.event),
            label: const Text("Nur Kalenderdatei (.ics) exportieren"),
          ),
          const SizedBox(height: 24),
          const Text(
            "Alle gesammelten Projektdaten werden als Datei auf der "
            "Festplatte abgelegt und können auf einem anderen System über "
            "\"Projekt importieren\" wieder eingelesen werden.",
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _exportProject(context, project),
            icon: const Icon(Icons.upload_file),
            label: const Text("Gesamtes Projekt exportieren"),
          ),
          const Divider(height: 40),
          const Text(
            "Projekt löschen",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Entfernt das Projekt unwiderruflich von diesem Gerät. Vorher "
            "am besten exportieren (siehe oben), falls noch gebraucht.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red,
            ),
            onPressed: () => _confirmDeleteProject(context, project),
            icon: const Icon(Icons.delete_forever),
            label: const Text("Projekt endgültig löschen"),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProject(BuildContext context, Project project) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Projekt endgültig löschen?"),
          content: Text(
            '"${project.name}" wird mit allen Gewerken, Aufgaben, Dateien '
            'und sonstigen Daten unwiderruflich von diesem Gerät entfernt.'
            '${project.sharedId == null ? '' : ' Andere Geräte/Team-Mitglieder behalten ihre eigene Kopie.'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<ProjectStore>().removeProject(project.id);
                // Zurück bis zum Start-Bildschirm - das gelöschte Projekt
                // existiert nicht mehr, GewerkeScreen darüber im Stack
                // würde sonst mit einer leeren firstWhere() abstürzen.
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text("Endgültig löschen"),
            ),
          ],
        );
      },
    );
  }
}
