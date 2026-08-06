import 'package:flutter/material.dart';

import '../models/task.dart';
import '../widgets/app_bar.dart';
import '../widgets/box_dummy.dart';

class TaskDetailScreen extends StatelessWidget {
  final Task task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar("Aufgabe", context, true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            task.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text("Status: ${task.status}"),
          const SizedBox(height: 10),
          if (task.dueDate != null)
            ...[
              Text("Fällig: ${task.dueDate}"),
              const SizedBox(height: 20),
            ],
          const Text("Beschreibung"),
          const SizedBox(height: 5),
          const Text("Hier können später Details stehen."),
          const SizedBox(height: 20),
          const Text("Dokumente"),
          boxDummy("📄 Angebot.pdf"),
          boxDummy("📄 Rechnung.pdf"),
          const SizedBox(height: 20),
          const Text("Fotos"),
          boxDummy("📸 Baustelle 01"),
          boxDummy("📸 Baustelle 02"),
          const SizedBox(height: 20),
          const Text("Notizen"),
          const Text("Noch keine Notizen vorhanden"),
        ],
      ),
    );
  }
}
