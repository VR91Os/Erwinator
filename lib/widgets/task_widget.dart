import 'package:flutter/material.dart';

import '../models/task.dart';
import '../screens/task_detail_screen.dart';
import '../utils/task_urgency.dart';
import 'audit_info_icon.dart';

Widget taskWidget(
  Task task,
  BuildContext context, {
  required String projectId,
  required String gewerkId,
  required String moduleId,
  required VoidCallback onStatusTap,
  required VoidCallback onShiftDate,
  required VoidCallback onShiftDateByDefault,
  required int shiftDays,
  required VoidCallback onArchive,
}) {
  final color = taskUrgencyColor(task);

  IconData icon;
  String statusTooltip;
  switch (task.status) {
    case "erledigt":
      icon = Icons.check_circle;
      statusTooltip = "Erledigt – antippen, um Status zurückzusetzen";
      break;
    case "teilweise":
      icon = Icons.radio_button_checked;
      statusTooltip = "Teilweise erledigt – antippen für 'Erledigt'";
      break;
    case "archiviert":
      icon = Icons.archive;
      statusTooltip = "Archiviert – antippen, um Status zurückzusetzen";
      break;
    default:
      icon = Icons.circle_outlined;
      statusTooltip = "Offen – antippen für 'Teilweise erledigt'";
  }

  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaskDetailScreen(
            projectId: projectId,
            gewerkId: gewerkId,
            moduleId: moduleId,
            taskId: task.id,
          ),
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
                tooltip: statusTooltip,
                onPressed: onStatusTap,
              ),
              Expanded(
                child: Row(
                  children: [
                    if (task.isHighPriority)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Tooltip(
                          message: "Hohe Priorität",
                          child: Text("🔥"),
                        ),
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
                  Tooltip(
                    message: item.isDone ? "Erledigt" : "Offen",
                    child: Icon(
                      item.isDone
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                    ),
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
              AuditInfoIcon(history: task.history),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.schedule),
                tooltip: "Fälligkeit um 1 Tag verschieben",
                onPressed: onShiftDate,
              ),
              IconButton(
                icon: const Icon(Icons.fast_forward),
                tooltip:
                    "Fälligkeit um $shiftDays Tage verschieben "
                    "(landet nie auf Sonntag/Feiertag)",
                onPressed: onShiftDateByDefault,
              ),
              IconButton(
                icon: const Icon(Icons.archive),
                tooltip: "Aufgabe archivieren",
                onPressed: onArchive,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
