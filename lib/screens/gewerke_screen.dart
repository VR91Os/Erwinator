import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/gewerk.dart';
import '../models/modules/contact_module.dart';
import '../models/modules/file_module.dart';
import '../models/modules/gewerk_module.dart';
import '../models/modules/todo_module.dart';
import '../models/project.dart';
import '../state/project_store.dart';
import '../widgets/app_bar.dart';
import '../widgets/dialogs/new_gewerk_dialog.dart';
import '../widgets/modules/contact_module_widget.dart';
import '../widgets/modules/file_module_widget.dart';
import '../widgets/modules/module_picker_dialog.dart';
import '../widgets/modules/todo_module_widget.dart';
import '../utils/task_urgency.dart';
import '../widgets/file_archive_tab.dart';
import '../widgets/overview_tab.dart';
import 'gewerk_settings_screen.dart';
import 'overview_settings_screen.dart';

const _overviewTabId = '__overview__';
const _fileArchiveTabId = '__files__';

class GewerkeScreen extends StatefulWidget {
  final String projectId;

  const GewerkeScreen({super.key, required this.projectId});

  @override
  State<GewerkeScreen> createState() => _GewerkeScreenState();
}

class _GewerkeScreenState extends State<GewerkeScreen> {
  // ✅ Überblick ist immer der Startreiter.
  String selectedTabId = _overviewTabId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProjectStore>();
    final project =
        store.projects.firstWhere((p) => p.id == widget.projectId);

    final selectedGewerkIndex =
        project.gewerke.indexWhere((g) => g.id == selectedTabId);
    final isFileArchive = selectedTabId == _fileArchiveTabId;
    final isOverview = !isFileArchive &&
        (selectedTabId == _overviewTabId || selectedGewerkIndex == -1);
    final selectedGewerk =
        (isOverview || isFileArchive) ? null : project.gewerke[selectedGewerkIndex];

    if (selectedGewerkIndex == -1 &&
        selectedTabId != _overviewTabId &&
        selectedTabId != _fileArchiveTabId) {
      // Reiter wurde entfernt -> zurück zu Überblick.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => selectedTabId = _overviewTabId);
      });
    }

    return Scaffold(
      // ✅ Titel = wo man sich befindet: Überblick -> Projektname,
      // Dateiablage -> fester Titel, sonst -> Name des Gewerk-Reiters.
      appBar: buildAppBar(
        isOverview
            ? project.name
            : isFileArchive
                ? "Dateiablage"
                : selectedGewerk!.name,
        context,
        true,
        // ✅ Plus erzeugt immer die Ebene direkt unter der aktuellen Ansicht.
        // In der Dateiablage gibt es keine eigene "Anlegen"-Aktion.
        onCreate: isOverview
            ? () => showNewGewerkDialog(context, project.id)
            : isFileArchive
                ? null
                : () => showModulePickerDialog(
                    context, project.id, selectedGewerk!.id),
        createTooltip: isOverview ? "Neues Gewerk" : "Modul hinzufügen",
        // ✅ Optionen unterscheiden sich je Ebene: Überblick -> Export,
        // Gewerk-Reiter -> umbenennen/löschen (nicht die App-Optionen).
        onSettings: isOverview
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        OverviewSettingsScreen(projectId: project.id),
                  ),
                )
            : isFileArchive
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GewerkSettingsScreen(
                          projectId: project.id,
                          gewerkId: selectedGewerk!.id,
                          initialName: selectedGewerk.name,
                        ),
                      ),
                    ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _tabChip(
                  label: "Überblick",
                  selected: selectedTabId == _overviewTabId,
                  accent: true,
                  urgent: projectHasUrgentPriorityTask(project),
                  onTap: () => setState(() => selectedTabId = _overviewTabId),
                ),
                ...project.gewerke.map((gewerk) {
                  return _tabChip(
                    label: gewerk.name,
                    selected: selectedTabId == gewerk.id,
                    urgent: gewerkHasUrgentPriorityTask(
                        gewerk, project.priorityWarningDays),
                    onTap: () => setState(() => selectedTabId = gewerk.id),
                  );
                }),
                // ✅ Dateiablage bleibt immer der letzte Reiter, ganz rechts.
                _tabChip(
                  label: "Dateiablage",
                  selected: isFileArchive,
                  accent: true,
                  onTap: () =>
                      setState(() => selectedTabId = _fileArchiveTabId),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: isOverview
                  ? OverviewTab(project: project)
                  : isFileArchive
                      ? FileArchiveTab(
                          project: project,
                          onOpenGewerk: (gewerkId) =>
                              setState(() => selectedTabId = gewerkId),
                        )
                      : _buildGewerkContent(project, selectedGewerk!),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ "Überblick" und "Dateiablage" sind feste System-Reiter (im Gegensatz
  // zu den frei anlegbaren Gewerken) und bekommen dauerhaft einen blauen
  // Hintergrund, damit sie sich auch unausgewählt von den Gewerken abheben.
  Widget _tabChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool accent = false,
    bool urgent = false,
  }) {
    final Color color;
    final Color textColor;
    if (urgent) {
      // ✅ Überschreibt Blau/Grau: offene Prio-Aufgabe hat die projektweit
      // eingestellte Warnschwelle vor Fälligkeit erreicht.
      color = selected ? Colors.red.shade400 : Colors.red.shade200;
      textColor = selected ? Colors.white : Colors.red.shade900;
    } else if (accent) {
      color = selected ? Colors.blue.shade400 : Colors.blue.shade200;
      textColor = selected ? Colors.white : Colors.blue.shade900;
    } else {
      color = selected ? Colors.grey.shade400 : Colors.grey.shade300;
      textColor = Colors.black;
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(label, style: TextStyle(color: textColor)),
        ),
      ),
    );
  }

  Widget _buildGewerkContent(Project project, Gewerk gewerk) {
    return ListView(
      children: [
        if (gewerk.modules.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text("Noch keine Module – oben links hinzufügen"),
          ),
        ...gewerk.modules.map((module) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _moduleWidget(project.id, gewerk.id, module),
          );
        }),
      ],
    );
  }

  Widget _moduleWidget(String projectId, String gewerkId, GewerkModule module) {
    if (module is ContactModule) {
      return ContactModuleWidget(
          projectId: projectId, gewerkId: gewerkId, module: module);
    }
    if (module is TodoModule) {
      return TodoModuleWidget(
          projectId: projectId, gewerkId: gewerkId, module: module);
    }
    if (module is FileModule) {
      return FileModuleWidget(
          projectId: projectId, gewerkId: gewerkId, module: module);
    }
    return const SizedBox.shrink();
  }
}
