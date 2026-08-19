import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/project_store.dart';
import '../../utils/safe_notify.dart';

void showNewProjectDialog(BuildContext context) {
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final store = context.read<ProjectStore>();
  // ⛔ Auswahl "Art des Projekts" (Neubau/Sanierung) entfernt – legte
  // vorgefertigte Start-Gewerke an. Ein neues Projekt bekommt jetzt immer
  // nur einen Reiter "Allgemein" mit allen Modulen (siehe addProject).

  showDialog(
    context: context,
    builder: (dialogContext) {
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
              final name = nameController.text.trim();
              if (name.isEmpty) {
                return;
              }
              final address = addressController.text.trim();
              popDialogThen(
                dialogContext,
                () => store.addProject(name, address: address),
              );
            },
            child: const Text("Erstellen"),
          ),
        ],
      );
    },
  );
}
