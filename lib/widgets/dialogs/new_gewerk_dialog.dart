import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/project_store.dart';
import '../../utils/safe_notify.dart';

void showNewGewerkDialog(BuildContext context, String projectId) {
  final controller = TextEditingController();
  final store = context.read<ProjectStore>();

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text("Neues Gewerk"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Name des Gewerks"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Abbrechen"),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) {
                return;
              }
              popDialogThen(dialogContext, () => store.addGewerk(projectId, name));
            },
            child: const Text("Erstellen"),
          ),
        ],
      );
    },
  );
}
