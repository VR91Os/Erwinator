import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/audit_entry.dart';
import '../../models/task.dart';
import '../../state/project_store.dart';
import '../../state/settings_store.dart';
import '../../utils/id_generator.dart';
import '../../utils/safe_notify.dart';

void showTaskDialog(
  BuildContext context,
  String projectId,
  String gewerkId,
  String moduleId,
) {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final store = context.read<ProjectStore>();
  final actor = context.read<SettingsStore>().currentUserKurzzeichen;

  bool isHighPriority = false;
  DateTime? dueDate;

  // .then(...) statt eines State-Objekts: der Dialog wird über eine lose
  // Funktion statt eines StatefulWidgets aufgebaut, daher gibt es keinen
  // dispose()-Lebenszyklus. showDialog()s Future wird aber garantiert bei
  // jedem Schließen (Speichern, Verwerfen, Zurück-Taste, Tap außerhalb)
  // abgeschlossen, das reicht hier als Ersatz.
  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Neue Aufgabe"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Name *",
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Beschreibung",
                    ),
                  ),
                  const SizedBox(height: 15),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Hohe Priorität"),
                    value: isHighPriority,
                    onChanged: (value) {
                      setDialogState(() {
                        isHighPriority = value ?? false;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    dueDate == null
                        ? "📅 Kein Fälligkeitsdatum"
                        : "📅 Fällig: ${dueDate!.day}.${dueDate!.month}.${dueDate!.year}",
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setDialogState(() {
                            dueDate =
                                DateTime.now().add(const Duration(days: 1));
                          });
                        },
                        child: const Text("Morgen"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setDialogState(() {
                            dueDate =
                                DateTime.now().add(const Duration(days: 7));
                          });
                        },
                        child: const Text("Nächste Woche"),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              dueDate = picked;
                            });
                          }
                        },
                        child: const Text("Kalender"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text("Verwerfen"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    return;
                  }

                  final newTask = Task(
                    newId(),
                    nameController.text.trim(),
                    description: descriptionController.text.trim(),
                    isHighPriority: isHighPriority,
                    dueDate: dueDate,
                    createdBy: actor,
                    history: [
                      AuditEntry(kurzzeichen: actor, action: 'erstellt'),
                    ],
                  );

                  popDialogThen(
                    dialogContext,
                    () => store.addTaskToTodoModule(
                      projectId,
                      gewerkId,
                      moduleId,
                      newTask,
                    ),
                  );
                },
                child: const Text("Speichern"),
              ),
            ],
          );
        },
      );
    },
  ).then((_) {
    nameController.dispose();
    descriptionController.dispose();
  });
}
