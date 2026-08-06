import 'package:flutter/material.dart';

import '../models/task.dart';

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
