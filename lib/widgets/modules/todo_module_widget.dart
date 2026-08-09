import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/modules/todo_module.dart';
import '../../state/project_store.dart';
import '../../state/settings_store.dart';
import '../dialogs/task_dialog.dart';
import '../task_widget.dart';
import 'module_card.dart';

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
    final actor = context.watch<SettingsStore>().currentUserKurzzeichen;

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
          ...module.tasks.map((task) {
            return taskWidget(
              task,
              context,
              onStatusTap: () => store.updateTaskStatus(
                  projectId, gewerkId, module.id, task.id,
                  actor: actor),
              onShiftDate: () => store.shiftTaskDueDate(
                  projectId, gewerkId, module.id, task.id,
                  actor: actor),
              onArchive: () => store.archiveTask(
                  projectId, gewerkId, module.id, task.id,
                  actor: actor),
            );
          }),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () =>
                showTaskDialog(context, projectId, gewerkId, module.id),
            child: const Text("➕ Aufgabe hinzufügen"),
          ),
        ],
      ),
    );
  }
}
