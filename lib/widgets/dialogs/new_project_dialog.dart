import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/project_store.dart';

void showNewProjectDialog(BuildContext context) {
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final store = context.read<ProjectStore>();
  String projectType = 'neubau';

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Neues Projekt"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Name *"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: "Adresse"),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Art des Projekts",
                    style: TextStyle(color: Colors.grey),
                  ),
                  Text(
                    "Legt die Start-Gewerke an "
                    "(Neubau: Architekt, Erdbau, Behörde · "
                    "Sanierung: Abrissfirma, Baumeister).",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  RadioGroup<String>(
                    groupValue: projectType,
                    onChanged: (value) {
                      setDialogState(() => projectType = value ?? 'neubau');
                    },
                    child: const Column(
                      children: [
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          value: 'neubau',
                          title: Text("Neubau"),
                        ),
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          value: 'sanierung',
                          title: Text("Sanierung"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Abbrechen"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    return;
                  }
                  store.addProject(
                    nameController.text.trim(),
                    address: addressController.text.trim(),
                    projectType: projectType,
                  );
                  Navigator.pop(dialogContext);
                },
                child: const Text("Erstellen"),
              ),
            ],
          );
        },
      );
    },
  );
}
