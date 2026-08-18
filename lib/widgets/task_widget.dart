import 'package:flutter/material.dart';

import '../models/task.dart';
import '../screens/task_detail_screen.dart';
import '../utils/light_surface_colors.dart';
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
  required int warningDays,
}) {
  final color = taskUrgencyColor(task, warningDays: warningDays);

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

  // Kompakte IconButtons statt der Material-Standardgröße (48x48 Touch-
  // Ziel je Button) - bei 4 Icons pro Aufgabe sonst sehr platzraubend.
  Widget compactIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color color = Colors.black54,
  }) =>
      IconButton(
        icon: Icon(icon, size: 18, color: color),
        tooltip: tooltip,
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      );

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
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              compactIconButton(
                icon: icon,
                tooltip: statusTooltip,
                onPressed: onStatusTap,
              ),
              if (task.isHighPriority)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Tooltip(
                    message: "Hohe Priorität",
                    child: Text("🔥", style: TextStyle(fontSize: 13)),
                  ),
                ),
              Expanded(
                child: Text(
                  task.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: lightSurfaceTextColor,
                  ),
                ),
              ),
            ],
          ),
          if (task.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 38, top: 2, bottom: 2),
              child: Text(
                task.description,
                style:
                    const TextStyle(color: lightSurfaceTextColor, fontSize: 13),
              ),
            ),
          ...task.checklist.take(3).map((item) {
            return Padding(
              padding: const EdgeInsets.only(left: 38),
              child: Row(
                children: [
                  Tooltip(
                    message: item.isDone ? "Erledigt" : "Offen",
                    child: Icon(
                      item.isDone
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 15,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(item.text,
                      style: const TextStyle(
                          fontSize: 13, color: lightSurfaceTextColor)),
                ],
              ),
            );
          }),
          Row(
            children: [
              compactIconButton(
                icon: Icons.schedule,
                tooltip: "Fälligkeit um 1 Tag verschieben",
                onPressed: onShiftDate,
              ),
              compactIconButton(
                icon: Icons.fast_forward,
                tooltip:
                    "Fälligkeit um $shiftDays Tage verschieben "
                    "(landet nie auf Sonntag/Feiertag)",
                onPressed: onShiftDateByDefault,
              ),
              compactIconButton(
                icon: Icons.archive,
                tooltip: "Aufgabe archivieren",
                onPressed: onArchive,
              ),
              const Spacer(),
              if (task.dueDate != null)
                Text(
                  "${task.dueDate!.day}.${task.dueDate!.month}",
                  style:
                      const TextStyle(fontSize: 12, color: lightSurfaceTextColor),
                ),
              const SizedBox(width: 6),
              AuditInfoIcon(history: task.history),
            ],
          ),
        ],
      ),
    ),
  );
}
