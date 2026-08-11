import 'package:flutter/material.dart';

// Arbeitszeiten werden immer im 24h-Format eingegeben/angezeigt (07:00,
// 17:00 …), unabhängig vom Geräte-Standardformat (12h AM/PM).
Future<TimeOfDay?> show24hTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
}
