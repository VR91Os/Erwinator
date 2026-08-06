import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/modules/contact_module.dart';
import '../../models/modules/file_module.dart';
import '../../models/modules/todo_module.dart';
import '../../state/project_store.dart';

void showModulePickerDialog(
  BuildContext context,
  String projectId,
  String gewerkId,
) {
  final store = context.read<ProjectStore>();

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
