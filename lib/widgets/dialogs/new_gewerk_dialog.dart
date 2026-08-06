import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/project_store.dart';

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
              if (controller.text.trim().isEmpty) {
                return;
              }
              store.addGewerk(projectId, controller.text.trim());
              Navigator.pop(dialogContext);
            },
            child: const Text("Erstellen"),
          ),
        ],
      );
    },
  );
}
