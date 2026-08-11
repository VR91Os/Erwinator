import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/modules/todo_module.dart';
import '../../models/project.dart';
import '../../models/task.dart';
import '../../state/project_store.dart';
import '../../state/settings_store.dart';
import '../dialogs/task_dialog.dart';
import '../task_widget.dart';
import 'module_card.dart';

// Archivierte (bzw. bei aktivierter Option auch erledigte) Aufgaben wandern
// nach [Project.archiveAfterDays] Tagen ganz unten in einen eingeklappten
// Archivbereich, statt weiterhin zwischen offenen Aufgaben zu stehen.
bool _belongsInArchiveSection(Task task, Project project) {
  final daysSinceUpdate = DateTime.now().difference(task.updatedAt).inDays;
  if (daysSinceUpdate < project.archiveAfterDays) return false;
  if (task.status == 'archiviert') return true;
  return task.status == 'erledigt' && project.moveCompletedToArchiveToo;
}

class TodoModuleWidget extends StatelessWidget {
  final String projectId;
  final String gewerkId;
  final TodoModule module;

  const TodoModuleWidget({
    super.key,
    required this.projectId,
    required this.gewerkId,
    required this.module,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.read<ProjectStore>();
    final settingsStore = context.watch<SettingsStore>();
    final actor = settingsStore.currentUserKurzzeichen;
    final project = store.projects.firstWhere((p) => p.id == projectId);

    Widget buildTaskWidget(Task task) {
      return taskWidget(
        task,
        context,
        onStatusTap: () => store.updateTaskStatus(
            projectId, gewerkId, module.id, task.id,
            actor: actor),
        onShiftDate: () => store.shiftTaskDueDate(
            projectId, gewerkId, module.id, task.id,
            actor: actor),
        onShiftDateByDefault: () => store.shiftTaskDueDateByDefault(
            projectId, gewerkId, module.id, task.id,
            holidayCountry: settingsStore.settings.holidayCountry,
            actor: actor),
        shiftDays: project.shiftDays,
        onArchive: () => store.archiveTask(
            projectId, gewerkId, module.id, task.id,
            actor: actor),
      );
    }

    final visibleTasks = <Task>[];
    final archivedSectionTasks = <Task>[];
    for (final task in module.tasks) {
      if (_belongsInArchiveSection(task, project)) {
        archivedSectionTasks.add(task);
      } else {
        visibleTasks.add(task);
      }
    }

    return ModuleCard(
      projectId: projectId,
      gewerkId: gewerkId,
      moduleId: module.id,
      icon: "✅",
      defaultTitle: "Todo-Liste",
      label: module.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...visibleTasks.map(buildTaskWidget),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () =>
                showTaskDialog(context, projectId, gewerkId, module.id),
            child: const Text("➕ Aufgabe hinzufügen"),
          ),
          if (archivedSectionTasks.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text("📦 Archiv (${archivedSectionTasks.length})"),
              children: archivedSectionTasks.map(buildTaskWidget).toList(),
            ),
        ],
      ),
    );
  }
}
