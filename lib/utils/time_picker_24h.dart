import 'package:flutter/material.dart';

// Liest ein "HH:MM"-Zeitstring (Arbeitszeitprofile, Helfer-Zusagen) wieder
// als TimeOfDay ein; null bei ungültigem/fehlendem Format statt zu werfen.
TimeOfDay? parseTimeOfDay(String? hhmm) {
  if (hhmm == null) return null;
  final parts = hhmm.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

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
