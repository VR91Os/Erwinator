import 'package:flutter/material.dart';

import '../models/gewerk.dart';
import '../models/modules/todo_module.dart';
import '../models/project.dart';
import '../models/task.dart';

// Ob eine offene Prio-Aufgabe in diesem Gewerk die projektweit eingestellte
// Warnschwelle (Tage vor Fälligkeit) erreicht oder bereits überschritten hat.
bool gewerkHasUrgentPriorityTask(Gewerk gewerk, int warningDays) {
  final now = DateTime.now();
  for (final module in gewerk.modules.whereType<TodoModule>()) {
    for (final task in module.tasks) {
      if (task.status != 'offen' ||
          !task.isHighPriority ||
          task.dueDate == null) {
        continue;
      }
      final diff = task.dueDate!.difference(now).inDays;
      if (diff <= warningDays) return true;
    }
  }
  return false;
}

bool projectHasUrgentPriorityTask(Project project) {
  return project.gewerke
      .any((g) => gewerkHasUrgentPriorityTask(g, project.priorityWarningDays));
}

Color taskUrgencyColor(Task task) {
  if (task.status == "erledigt") {
    return Colors.green.shade200;
  }
  if (task.status == "teilweise") {
    return Colors.blue.shade200;
  }
  if (task.status == "archiviert") {
    return Colors.grey.shade300;
  }
  if (task.status == "offen" && task.isHighPriority && task.dueDate != null) {
    final diff = task.dueDate!.difference(DateTime.now()).inDays;
    if (diff <= 1) {
      return const Color(0xFFFFD6D6); // kritisch
    }
    if (diff <= 3) {
      return const Color(0xFFFFF3CD); // bald
    }
  }
  return Colors.white;
}
