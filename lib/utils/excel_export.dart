import 'package:excel/excel.dart';

import '../models/helper_demand.dart';

// Zwei Nullen auffüllen, z.B. 3 -> "03" - für das deutsche Datumsformat
// dd.MM.yyyy, analog zu den Hilfsfunktionen in ics_export.dart.
String _pad2(int value) => value.toString().padLeft(2, '0');
String _formatDate(DateTime date) =>
    '${_pad2(date.day)}.${_pad2(date.month)}.${date.year}';

// "HH:MM–HH:MM" falls beide Zeiten gesetzt sind, sonst leer - Zusagen ohne
// Zeitrahmen (siehe showTime-Checkbox im Eintragen-Dialog) sind normal und
// sollen hier keinen Platzhalter wie "null" erzeugen.
String _formatSignupTime(HelperSignup signup) {
  final start = signup.startTime;
  final end = signup.endTime;
  if (start == null || end == null) return '';
  return '$start–$end';
}

// Erzeugt eine .xlsx-Datei mit einer Zeile pro Helferbedarf-Tag (Datum,
// benötigte/bestätigte Helfer, Namen, Zeiten) - für den Export-Button im
// Helfer-Reiter. Reine Daten->Bytes-Funktion, keine I/O (siehe
// lib/utils/file_export.dart für die Auslieferung der Bytes als Datei).
List<int> buildHelperDemandExcel(List<HelperDemand> demands) {
  final excel = Excel.createExcel();
  const sheetName = 'Helferbedarf';
  final defaultSheet = excel.getDefaultSheet();
  if (defaultSheet != null && defaultSheet != sheetName) {
    excel.rename(defaultSheet, sheetName);
  }

  excel.appendRow(sheetName, [
    TextCellValue('Datum'),
    TextCellValue('Benötigt'),
    TextCellValue('Bestätigt'),
    TextCellValue('Namen'),
    TextCellValue('Zeiten'),
    TextCellValue('Notiz'),
  ]);

  final sorted = List<HelperDemand>.of(demands)
    ..sort((a, b) => a.date.compareTo(b.date));
  for (final demand in sorted) {
    excel.appendRow(sheetName, [
      TextCellValue(_formatDate(demand.date)),
      IntCellValue(demand.neededCount),
      IntCellValue(demand.signups.length),
      TextCellValue(demand.signups.map((s) => s.name).join(', ')),
      TextCellValue(
          demand.signups.map(_formatSignupTime).join(', ')),
      TextCellValue(demand.note),
    ]);
  }

  return excel.encode()!;
}
