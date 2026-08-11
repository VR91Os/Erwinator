// Gesetzliche Feiertage rein lokal berechnet (keine Internetverbindung
// nötig) für die für diese App relevanten DACH-Länder. Bewegliche
// Feiertage (Ostern und daraus abgeleitete) über die Gaußsche
// Osterformel; deckt nicht landesweit unterschiedliche Bundesland-/
// Kantons-Feiertage ab (bewusste Vereinfachung).

const List<String> holidayCountries = ['AT', 'DE', 'CH'];

String holidayCountryLabel(String code) => switch (code) {
      'AT' => 'Österreich',
      'DE' => 'Deutschland',
      'CH' => 'Schweiz',
      _ => 'Keine Feiertage berücksichtigen',
    };

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _easterSunday(int year) {
  // Gaußsche Osterformel.
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = (h + l - 7 * m + 114) % 31 + 1;
  return DateTime(year, month, day);
}

// Gesetzliche Feiertage eines Jahres für [countryCode]. Leeres Set, wenn
// kein oder ein nicht unterstütztes Land übergeben wird.
Set<DateTime> publicHolidays(int year, String countryCode) {
  final easter = _easterSunday(year);
  DateTime plus(int days) => easter.add(Duration(days: days));

  switch (countryCode) {
    case 'AT':
      return {
        DateTime(year, 1, 1), // Neujahr
        DateTime(year, 1, 6), // Heilige Drei Könige
        plus(1), // Ostermontag
        DateTime(year, 5, 1), // Staatsfeiertag
        plus(39), // Christi Himmelfahrt
        plus(50), // Pfingstmontag
        plus(60), // Fronleichnam
        DateTime(year, 8, 15), // Mariä Himmelfahrt
        DateTime(year, 10, 26), // Nationalfeiertag
        DateTime(year, 11, 1), // Allerheiligen
        DateTime(year, 12, 8), // Mariä Empfängnis
        DateTime(year, 12, 25), // Christtag
        DateTime(year, 12, 26), // Stefanitag
      };
    case 'DE':
      // Bundesweite Feiertage; landesspezifische (z.B. Fronleichnam nur in
      // manchen Bundesländern) bewusst ausgelassen.
      return {
        DateTime(year, 1, 1),
        plus(-2), // Karfreitag
        plus(1), // Ostermontag
        DateTime(year, 5, 1),
        plus(39), // Christi Himmelfahrt
        plus(50), // Pfingstmontag
        DateTime(year, 10, 3), // Tag der Deutschen Einheit
        DateTime(year, 12, 25),
        DateTime(year, 12, 26),
      };
    case 'CH':
      // Landesweit anerkannte Feiertage; kantonale Unterschiede bewusst
      // ausgelassen.
      return {
        DateTime(year, 1, 1),
        plus(-2), // Karfreitag
        plus(1), // Ostermontag
        plus(39), // Auffahrt
        plus(50), // Pfingstmontag
        DateTime(year, 8, 1), // Bundesfeier
        DateTime(year, 12, 25),
        DateTime(year, 12, 26),
      };
    default:
      return {};
  }
}

bool isPublicHoliday(DateTime date, String countryCode) {
  if (countryCode.isEmpty) return false;
  return publicHolidays(date.year, countryCode).contains(_dateOnly(date));
}

// Rückt [date] so lange einen Tag weiter, bis es weder Sonntag noch ein
// gesetzlicher Feiertag im gewählten Land ist. Samstage bleiben bewusst
// gültige Arbeitstage.
DateTime nextWorkday(DateTime date, String countryCode) {
  var result = _dateOnly(date);
  while (result.weekday == DateTime.sunday ||
      isPublicHoliday(result, countryCode)) {
    result = result.add(const Duration(days: 1));
  }
  return result;
}
