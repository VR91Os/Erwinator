import 'package:flutter/material.dart';

// Aktuell nirgends aufgerufen (bereits vor dem Refactor toter Code) —
// bewusst unverändert übernommen, nicht neu angebunden.
int defaultShiftDays = 3;

DateTime adjustDate(DateTime date, BuildContext context) {
  bool isSunday = date.weekday == DateTime.sunday;
  bool isHoliday = false;

  if (isSunday || isHoliday) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            "Achtung: Sonntag/Feiertag → Datum +1 Tag nach hinten verschoben"),
      ),
    );
    return date.add(const Duration(days: 1));
  }

  return date;
}
