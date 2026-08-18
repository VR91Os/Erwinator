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

class _TabDef {
  final String id;
  final String label;
  final bool accent;
  final bool urgent;

  const _TabDef({
    required this.id,
    required this.label,
    this.accent = false,
    this.urgent = false,
  });
}

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
            child: _buildTabBar(context, store, project, isFileArchive,
                isTimeTracking, isFinanceOverview),
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
                              : _buildGewerkContent(
                                  store, project, selectedGewerk!),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Frei per Drag&Drop sortierbare Reiter-Leiste: Reihenfolge kommt aus
  // project.tabOrder (IDs), neue/entfernte Reiter (neues Gewerk, gerade
  // aktiviertes Zeitstatistik-/Finanzen-Modul, gelöschtes Gewerk) werden
  // automatisch ergänzt bzw. herausgefiltert, ohne die gespeicherte
  // Reihenfolge der übrigen Reiter zu verändern.
  Widget _buildTabBar(
    BuildContext context,
    ProjectStore store,
    Project project,
    bool isFileArchive,
    bool isTimeTracking,
    bool isFinanceOverview,
  ) {
    final defaultTabs = <_TabDef>[
      _TabDef(
        id: _overviewTabId,
        label: "Überblick",
        accent: true,
        urgent: projectHasUrgentPriorityTask(project),
      ),
      ...project.gewerke.map((gewerk) => _TabDef(
            id: gewerk.id,
            label: gewerk.name,
            urgent: gewerkHasUrgentPriorityTask(
                gewerk, project.priorityWarningDays),
          )),
      const _TabDef(id: _fileArchiveTabId, label: "Dateiablage", accent: true),
      if (project.timeTrackingEnabled)
        const _TabDef(
            id: _timeTrackingTabId, label: "Zeitstatistik", accent: true),
      if (project.financeEnabled)
        const _TabDef(
            id: _financeOverviewTabId, label: "Finanzen", accent: true),
    ];

    final byId = {for (final t in defaultTabs) t.id: t};
    final tabs = <_TabDef>[];
    for (final id in project.tabOrder) {
      final t = byId.remove(id);
      if (t != null) tabs.add(t);
    }
    for (final t in defaultTabs) {
      if (byId.containsKey(t.id)) tabs.add(t);
    }

    return ReorderableListView.builder(
      scrollDirection: Axis.horizontal,
      buildDefaultDragHandles: false,
      itemCount: tabs.length,
      onReorderItem: (oldIndex, newIndex) {
        final ids = tabs.map((t) => t.id).toList();
        final moved = ids.removeAt(oldIndex);
        ids.insert(newIndex, moved);
        // Erst nach dem aktuellen Frame speichern: store.updateTabOrder löst
        // über notifyListeners() einen Provider-weiten Rebuild aus (u.a.
        // dieser ReorderableListView selbst) - passiert das noch synchron,
        // während SliverReorderableList das Drag-Ende intern verarbeitet,
        // kollidiert das mit dessen Element-Umhängung
        // ("_dependents.isEmpty"-Assertion).
        WidgetsBinding.instance
            .addPostFrameCallback((_) => store.updateTabOrder(project.id, ids));
      },
      itemBuilder: (context, index) {
        final tab = tabs[index];
        final selected = tab.id == _overviewTabId
            ? selectedTabId == _overviewTabId
            : tab.id == _fileArchiveTabId
                ? isFileArchive
                : tab.id == _timeTrackingTabId
                    ? isTimeTracking
                    : tab.id == _financeOverviewTabId
                        ? isFinanceOverview
                        : selectedTabId == tab.id;
        return ReorderableDelayedDragStartListener(
          key: ValueKey(tab.id),
          index: index,
          child: _tabChip(
            label: tab.label,
            selected: selected,
            accent: tab.accent,
            urgent: tab.urgent,
            onTap: () => setState(() => selectedTabId = tab.id),
          ),
        );
      },
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
      // eingestellte Warnschwelle vor Fälligkeit erreicht. Hellorange statt
      // Rot, konsistent mit der Aufgaben-/Kalenderfarbe (taskUrgencyColor).
      color = selected ? Colors.orange.shade400 : Colors.orange.shade200;
      textColor = selected ? Colors.white : Colors.orange.shade900;
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

  // ✅ Module lassen sich per Long-Press + Ziehen frei sortieren (analog zur
  // Reiter-Leiste oben, siehe _buildTabBar) - Reihenfolge landet direkt in
  // gewerk.modules statt in einem separaten Order-Feld.
  Widget _buildGewerkContent(
      ProjectStore store, Project project, Gewerk gewerk) {
    if (gewerk.modules.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text("Noch keine Module – oben links hinzufügen"),
      );
    }
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: gewerk.modules.length,
      // Verzögert (siehe _buildTabBar): sonst löst notifyListeners() einen
      // Rebuild aus, während SliverReorderableList das Drag-Ende noch
      // intern verarbeitet -> "_dependents.isEmpty"-Assertion.
      onReorderItem: (oldIndex, newIndex) =>
          WidgetsBinding.instance.addPostFrameCallback((_) =>
              store.reorderModules(project.id, gewerk.id, oldIndex, newIndex)),
      itemBuilder: (context, index) {
        final module = gewerk.modules[index];
        return ReorderableDelayedDragStartListener(
          key: ValueKey(module.id),
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _moduleWidget(project.id, gewerk.id, module),
          ),
        );
      },
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
