import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/modules/contact_module.dart';
import '../../models/modules/file_module.dart';
import '../../models/modules/finance_module.dart';
import '../../models/modules/todo_module.dart';
import '../../models/project.dart';
import '../../state/project_store.dart';
import '../../utils/safe_notify.dart';

void showModulePickerDialog(
  BuildContext context,
  String projectId,
  String gewerkId,
) {
  final store = context.read<ProjectStore>();
  Project? foundProject;
  for (final p in store.projects) {
    if (p.id == projectId) foundProject = p;
  }
  // Projekt wurde inzwischen gelöscht (z.B. durch Sync von einem anderen
  // Gerät) - statt abzustürzen einfach keinen Dialog öffnen.
  if (foundProject == null) return;
  final project = foundProject;

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text("Modul hinzufügen"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.contact_phone),
              title: const Text("Kontakt"),
              onTap: () => popDialogThen(
                dialogContext,
                () => store.addModule(
                    projectId, gewerkId, ContactModule.moduleType),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text("Todo-Liste"),
              onTap: () => popDialogThen(
                dialogContext,
                () => store.addModule(
                    projectId, gewerkId, TodoModule.moduleType),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text("File-Ablage"),
              onTap: () => popDialogThen(
                dialogContext,
                () => store.addModule(
                    projectId, gewerkId, FileModule.moduleType),
              ),
            ),
            // Nur anlegbar, wenn das Finanzen-Modul in den Überblick-Optionen
            // aktiviert ist (analog zur Zeitstatistik) - bleibt aber sichtbar
            // (statt zu verschwinden), damit der Grund auffindbar ist, statt
            // wie ein fehlendes Feature zu wirken.
            ListTile(
              leading: Icon(Icons.euro,
                  color: project.financeEnabled ? null : Colors.grey),
              title: const Text("Finanzen"),
              subtitle: project.financeEnabled
                  ? null
                  : const Text(
                      "Zuerst im Überblick unter Optionen aktivieren",
                      style: TextStyle(fontSize: 11),
                    ),
              enabled: project.financeEnabled,
              onTap: () => popDialogThen(
                dialogContext,
                () => store.addModule(
                    projectId, gewerkId, FinanceModule.moduleType),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Abbrechen"),
          ),
        ],
      );
    },
  );
}
