import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/modules/todo_module.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../state/project_store.dart';
import '../utils/file_export.dart';
import '../utils/ics_export.dart';
import '../utils/profile_prompt.dart';
import '../widgets/app_bar.dart';
import 'share_project_screen.dart';

// Optionen für den "Überblick"-Reiter: steuert den Export des gesamten
// Projekts (Daten + optional Kalenderdatei), nicht die App-weiten
// Einstellungen aus dem Zahnrad im Startbildschirm.
class OverviewSettingsScreen extends StatelessWidget {
  final String projectId;

  const OverviewSettingsScreen({super.key, required this.projectId});

  List<Task> _allTasks(Project project) {
    final tasks = <Task>[];
    for (final gewerk in project.gewerke) {
      for (final module in gewerk.modules.whereType<TodoModule>()) {
        tasks.addAll(module.tasks);
      }
    }
    return tasks;
  }

  Future<void> _exportProject(BuildContext context, Project project) async {
    final json = const JsonEncoder.withIndent('  ').convert(project.toMap());
    await exportTextFile(
      fileName: '${project.name}_export.json',
      content: json,
    );

    if (project.exportAllDatedTodos || project.exportPriorityTasks) {
      final tasks = _allTasks(project).where((t) {
        if (t.status == 'archiviert' || t.dueDate == null) return false;
        if (project.exportAllDatedTodos) return true;
        return t.isHighPriority;
      }).toList();

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

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProjectStore>();
    final project = store.projects.firstWhere((p) => p.id == projectId);

    return Scaffold(
      appBar: buildAppBar("Optionen – Überblick", context, true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Alle ToDos mit Datum in Kalender exportieren"),
            value: project.exportAllDatedTodos,
            onChanged: (value) => store.updateExportPrefs(
              projectId,
              exportAllDatedTodos: value ?? false,
              exportPriorityTasks: project.exportPriorityTasks,
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Prio-Aufgaben exportieren"),
            value: project.exportPriorityTasks,
            onChanged: (value) => store.updateExportPrefs(
              projectId,
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
                      ShareProjectScreen(projectId: projectId),
                ),
              );
            },
            icon: const Icon(Icons.group_add),
            label: Text(
              project.sharedId == null ? "Projekt teilen" : "Teilen verwalten",
            ),
          ),
        ],
      ),
    );
  }
}
