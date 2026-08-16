import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/gewerk.dart';
import '../models/modules/contact_module.dart';
import '../models/modules/file_module.dart';
import '../models/modules/finance_module.dart';
import '../models/modules/gewerk_module.dart';
import '../models/modules/todo_module.dart';
import '../models/project.dart';
import '../state/project_store.dart';
import '../state/settings_store.dart';
import '../widgets/app_bar.dart';
import '../widgets/dialogs/new_gewerk_dialog.dart';
import '../widgets/finance_overview_section.dart';
import '../widgets/modules/contact_module_widget.dart';
import '../widgets/modules/file_module_widget.dart';
import '../widgets/modules/finance_module_widget.dart';
import '../widgets/modules/module_picker_dialog.dart';
import '../widgets/modules/todo_module_widget.dart';
import '../utils/task_urgency.dart';
import '../widgets/file_archive_tab.dart';
import '../widgets/overview_tab.dart';
import '../widgets/time_tracking_section.dart';
import 'gewerk_settings_screen.dart';
import 'overview_settings_screen.dart';

const _overviewTabId = '__overview__';
const _fileArchiveTabId = '__files__';
const _timeTrackingTabId = '__time__';
const _financeOverviewTabId = '__finance__';

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
  void initState() {
    super.initState();
    // ✅ "Ich bin auf der Baustelle" (V1): beim Öffnen des Projekts wird der
    // heutige Tag nachgezogen, falls jemand dauerhaft als anwesend markiert
    // ist – ohne dass dafür ein Helfer eingetragen werden muss.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final actor =
          context.read<SettingsStore>().currentUserKurzzeichen;
      final store = context.read<ProjectStore>();
      store.syncOnSitePresenceForToday(widget.projectId, actor: actor);
      // ✅ Räumt beim Öffnen abgelaufene archivierte Aufgaben endgültig
      // weg, falls in den Todo-Listen-Optionen aktiviert.
      store.cleanupExpiredArchivedTasks(widget.projectId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProjectStore>();
    final settingsStore = context.watch<SettingsStore>();
    final project =
        store.projects.firstWhere((p) => p.id == widget.projectId);

    final selectedGewerkIndex =
        project.gewerke.indexWhere((g) => g.id == selectedTabId);
    final isFileArchive = selectedTabId == _fileArchiveTabId;
    final isTimeTracking =
        selectedTabId == _timeTrackingTabId && project.timeTrackingEnabled;
    final isFinanceOverview =
        selectedTabId == _financeOverviewTabId && project.financeEnabled;
    final isOverview = !isFileArchive &&
        !isTimeTracking &&
        !isFinanceOverview &&
        (selectedTabId == _overviewTabId || selectedGewerkIndex == -1);
    final isFixedTab = isOverview || isFileArchive || isTimeTracking || isFinanceOverview;
    final selectedGewerk = isFixedTab ? null : project.gewerke[selectedGewerkIndex];

    final tabStillValid = selectedTabId == _overviewTabId ||
        selectedTabId == _fileArchiveTabId ||
        isTimeTracking ||
        isFinanceOverview ||
        selectedGewerkIndex != -1;
    if (!tabStillValid) {
      // Reiter wurde entfernt oder Zeitstatistik/Finanzen deaktiviert ->
      // zurück zu Überblick.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => selectedTabId = _overviewTabId);
      });
    }

    return Scaffold(
      // ✅ Titel = wo man sich befindet: Überblick -> Projektname,
      // Dateiablage/Zeitstatistik/Finanzen -> fester Titel, sonst -> Name
      // des Gewerk-Reiters.
      appBar: buildAppBar(
        isOverview
            ? project.name
            : isFileArchive
                ? "Dateiablage"
                : isTimeTracking
                    ? "Zeitstatistik"
                    : isFinanceOverview
                        ? "Finanzen"
                        : selectedGewerk!.name,
        context,
        true,
        // ✅ Plus erzeugt immer die Ebene direkt unter der aktuellen Ansicht.
        // In der Dateiablage/Zeitstatistik/Finanzen gibt es keine eigene
        // "Anlegen"-Aktion.
        onCreate: isOverview
            ? () => showNewGewerkDialog(context, project.id)
            : (isFileArchive || isTimeTracking || isFinanceOverview)
                ? null
                : () => showModulePickerDialog(
                    context, project.id, selectedGewerk!.id),
        createTooltip: isOverview ? "Neues Gewerk" : "Modul hinzufügen",
        showSettingsBadge: isOverview &&
            !settingsStore.hasSeenFeatureHint('time_tracking'),
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
            : (isFileArchive || isTimeTracking || isFinanceOverview)
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
                // ✅ Dateiablage ist immer der letzte feste System-Reiter vor
                // der optionalen Zeitstatistik, ganz rechts.
                _tabChip(
                  label: "Dateiablage",
                  selected: isFileArchive,
                  accent: true,
                  onTap: () =>
                      setState(() => selectedTabId = _fileArchiveTabId),
                ),
                // ✅ Nur sichtbar, wenn in den Überblick-Optionen aktiviert.
                if (project.timeTrackingEnabled)
                  _tabChip(
                    label: "Zeitstatistik",
                    selected: isTimeTracking,
                    accent: true,
                    onTap: () =>
                        setState(() => selectedTabId = _timeTrackingTabId),
                  ),
                if (project.financeEnabled)
                  _tabChip(
                    label: "Finanzen",
                    selected: isFinanceOverview,
                    accent: true,
                    onTap: () => setState(
                        () => selectedTabId = _financeOverviewTabId),
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
                      : isTimeTracking
                          ? TimeTrackingSection(project: project)
                          : isFinanceOverview
                              ? FinanceOverviewSection(project: project)
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
    if (module is FinanceModule) {
      return FinanceModuleWidget(
          projectId: projectId, gewerkId: gewerkId, module: module);
    }
    return const SizedBox.shrink();
  }
}
