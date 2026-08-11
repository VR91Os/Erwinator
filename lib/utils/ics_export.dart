import '../models/task.dart';

// Erzeugt eine .ics-Datei (iCalendar), importierbar in Google Kalender,
// Outlook, Apple Kalender etc. – ohne eigene Kalender-Anbindung nötig.
String buildIcs(List<Task> tasks, {required String calendarName}) {
  final buffer = StringBuffer();
  buffer.writeln('BEGIN:VCALENDAR');
  buffer.writeln('VERSION:2.0');
  buffer.writeln('PRODID:-//Erwinator//DE');
  buffer.writeln('X-WR-CALNAME:${_escape(calendarName)}');

  for (final task in tasks) {
    final due = task.dueDate;
    if (due == null) continue;

    buffer.writeln('BEGIN:VEVENT');
    buffer.writeln('UID:${task.id}@baustelli');
    buffer.writeln('DTSTAMP:${_stamp(DateTime.now())}');
    buffer.writeln('DTSTART;VALUE=DATE:${_date(due)}');
    buffer.writeln('SUMMARY:${_escape(task.name)}');
    if (task.description.isNotEmpty) {
      buffer.writeln('DESCRIPTION:${_escape(task.description)}');
    }
    buffer.writeln('END:VEVENT');
  }

  buffer.writeln('END:VCALENDAR');
  return buffer.toString();
}

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}'
    '${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

String _stamp(DateTime d) =>
    '${_date(d)}T'
    '${d.hour.toString().padLeft(2, '0')}'
    '${d.minute.toString().padLeft(2, '0')}'
    '${d.second.toString().padLeft(2, '0')}Z';

String _escape(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll(',', '\\,')
    .replaceAll(';', '\\;')
    .replaceAll('\n', '\\n');
