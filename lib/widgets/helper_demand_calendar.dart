import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/helper_demand.dart';
import '../utils/light_surface_colors.dart';

// Gemeinsame Lookup-Logik für "welcher Helferbedarf gilt an diesem Tag" -
// von OverviewTab (Kalender-Einfärbung) UND HelferTab (Kalender + Text-
// Sektion) genutzt, damit die Zuordnung nur an einer Stelle gepflegt wird.
HelperDemand? findDemandForDay(List<HelperDemand> demands, DateTime day) {
  for (final demand in demands) {
    if (isSameDay(demand.date, day)) return demand;
  }
  return null;
}

Color demandColor(HelperDemand demand) {
  if (demand.signups.length >= demand.neededCount) {
    return Colors.green.shade600;
  }
  if (demand.signups.isNotEmpty) {
    return const Color(0xFFE0A800);
  }
  return const Color(0xFFD32F2F);
}

// Der Helferbedarfs-Kalender aus dem Überblick, herausgelöst, damit sowohl
// der Überblick (kompakt, zusätzlich mit Aufgaben-Dringlichkeits-Kreisen)
// als auch der Helfer-Reiter (groß, ohne Aufgabenbezug) dieselbe
// Darstellung/Farbcodierung verwenden, ohne sie zu duplizieren.
class HelperDemandCalendar extends StatelessWidget {
  final List<HelperDemand> demands;
  final DateTime selectedDay;
  final DateTime focusedDay;
  final void Function(DateTime selected, DateTime focused) onDaySelected;
  // Kompakt (Überblick) vs. groß (Helfer-Reiter) - steuert nur die
  // Kachel-/Schriftgrößen, Farbschema bleibt identisch.
  final bool compact;
  // Nur im Überblick gesetzt: färbt den Tag zusätzlich nach
  // Aufgaben-Dringlichkeit ein (siehe OverviewTab._dayColor). Im
  // Helfer-Reiter null, da dort kein Aufgabenbezug besteht.
  final Color? Function(DateTime day)? taskColorBuilder;

  const HelperDemandCalendar({
    super.key,
    required this.demands,
    required this.selectedDay,
    required this.focusedDay,
    required this.onDaySelected,
    this.compact = true,
    this.taskColorBuilder,
  });

  Widget? _dayBuilder(BuildContext context, DateTime day, DateTime focused) {
    final color = taskColorBuilder?.call(day);
    final demand = findDemandForDay(demands, day);
    if (color == null && demand == null) return null;

    final fontSize = compact ? 13.0 : 16.0;
    final dayNumber = Container(
      margin: const EdgeInsets.all(2),
      decoration:
          color == null ? null : BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          fontSize: fontSize,
          color: color == null ? null : lightSurfaceTextColor,
        ),
      ),
    );
    if (demand == null) return dayNumber;

    final dotSize = compact ? 8.0 : 11.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        dayNumber,
        Positioned(
          right: compact ? 4 : 6,
          top: compact ? 4 : 6,
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: demandColor(demand),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 13.0 : 16.0;
    final weekdayFontSize = compact ? 11.0 : 13.0;
    final titleFontSize = compact ? 15.0 : 18.0;

    return TableCalendar(
      locale: 'de_DE',
      startingDayOfWeek: StartingDayOfWeek.monday,
      firstDay: DateTime.now().subtract(const Duration(days: 365)),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: focusedDay,
      selectedDayPredicate: (day) => isSameDay(day, selectedDay),
      onDaySelected: onDaySelected,
      calendarBuilders: CalendarBuilders(defaultBuilder: _dayBuilder),
      // ✅ compact=true reproduziert die bisherige Überblick-Größe
      // (deutlich weniger Höhe, da der Kalender dort nur einer von mehreren
      // Abschnitten ist); compact=false ist die größere Helfer-Reiter-
      // Variante mit mehr Platz für die Farbcodierung.
      rowHeight: compact ? 38 : 64,
      daysOfWeekHeight: compact ? 14 : 24,
      headerStyle: HeaderStyle(
        titleTextStyle:
            TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold),
        headerPadding: const EdgeInsets.symmetric(vertical: 4),
        // Ohne calendarFormat/onFormatChanged hier ohnehin wirkungslos.
        formatButtonVisible: false,
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(fontSize: weekdayFontSize, color: Colors.grey),
        weekendStyle: TextStyle(fontSize: weekdayFontSize, color: Colors.grey),
      ),
      calendarStyle: CalendarStyle(
        cellMargin: const EdgeInsets.all(2),
        defaultTextStyle: TextStyle(fontSize: fontSize),
        weekendTextStyle: TextStyle(fontSize: fontSize),
        outsideTextStyle: TextStyle(fontSize: fontSize, color: Colors.grey.shade400),
        // ✅ Heute = blau, angeklickt/ausgewählt = lila - eindeutig
        // unterscheidbar statt der ähnlichen Blautöne des Paket-Standards.
        todayDecoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(color: Colors.white, fontSize: fontSize),
        selectedDecoration: const BoxDecoration(
          color: Colors.purple,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: TextStyle(color: Colors.white, fontSize: fontSize),
      ),
    );
  }
}
