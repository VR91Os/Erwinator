import 'package:flutter/material.dart';

import '../models/task.dart';
import '../screens/task_detail_screen.dart';
import '../utils/task_urgency.dart';

Widget taskWidget(
  Task task,
  BuildContext context, {
  required VoidCallback onStatusTap,
  required VoidCallback onShiftDate,
  required VoidCallback onArchive,
}) {
  final color = taskUrgencyColor(task);

  IconData icon;
  switch (task.status) {
    case "erledigt":
      icon = Icons.check_circle;
      break;
    case "teilweise":
      icon = Icons.radio_button_checked;
      break;
    case "archiviert":
      icon = Icons.archive;
      break;
    default:
      icon = Icons.circle_outlined;
  }

  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaskDetailScreen(task: task),
        ),
      );
    },
    child: Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(icon),
                onPressed: onStatusTap,
              ),
              Expanded(
                child: Row(
                  children: [
                    if (task.isHighPriority)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Text("🔥"),
                      ),
                    Expanded(
                      child: Text(
                        task.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (task.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 4),
              child: Text(
                task.description,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          ...task.checklist.take(3).map((item) {
            return Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Row(
                children: [
                  Icon(
                    item.isDone
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(item.text),
                ],
              ),
            );
          }),
          Row(
            children: [
              const Spacer(),
              if (task.dueDate != null)
                Text(
                  "${task.dueDate!.day}.${task.dueDate!.month}",
                  style: const TextStyle(fontSize: 12),
                ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 18),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Erstellt von: ${task.createdBy}\n"
                        "Erstellt am: ${task.createdAt}\n"
                        "Letzte Änderung: ${task.updatedAt}",
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.schedule),
                onPressed: onShiftDate,
              ),
              IconButton(
                icon: const Icon(Icons.archive),
                onPressed: onArchive,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
