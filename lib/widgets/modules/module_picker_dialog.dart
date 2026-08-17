import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/modules/contact_module.dart';
import '../../models/modules/file_module.dart';
import '../../models/modules/finance_module.dart';
import '../../models/modules/todo_module.dart';
import '../../state/project_store.dart';

void showModulePickerDialog(
  BuildContext context,
  String projectId,
  String gewerkId,
) {
  final store = context.read<ProjectStore>();
  final project = store.projects.firstWhere((p) => p.id == projectId);

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
              onTap: () {
                store.addModule(
                    projectId, gewerkId, ContactModule.moduleType);
                Navigator.pop(dialogContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text("Todo-Liste"),
              onTap: () {
                store.addModule(projectId, gewerkId, TodoModule.moduleType);
                Navigator.pop(dialogContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text("File-Ablage"),
              onTap: () {
                store.addModule(projectId, gewerkId, FileModule.moduleType);
                Navigator.pop(dialogContext);
              },
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
              onTap: () {
                store.addModule(projectId, gewerkId, FinanceModule.moduleType);
                Navigator.pop(dialogContext);
              },
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
