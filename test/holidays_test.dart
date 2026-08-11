import 'package:flutter_test/flutter_test.dart';

import 'package:baustelli/utils/holidays.dart';

void main() {
  group('publicHolidays', () {
    test('Österreich 2026 enthält Fixtermine und bewegliche Feiertage', () {
      final holidays = publicHolidays(2026, 'AT');
      expect(holidays, contains(DateTime(2026, 1, 1))); // Neujahr
      expect(holidays, contains(DateTime(2026, 5, 1))); // Staatsfeiertag
      expect(holidays, contains(DateTime(2026, 12, 25))); // Christtag
      // Ostersonntag 2026 fällt auf den 5. April -> Ostermontag 6. April.
      expect(holidays, contains(DateTime(2026, 4, 6)));
    });

    test('unbekanntes/leeres Land liefert keine Feiertage', () {
      expect(publicHolidays(2026, ''), isEmpty);
      expect(publicHolidays(2026, 'XX'), isEmpty);
    });
  });

  group('nextWorkday', () {
    test('lässt einen normalen Werktag unverändert', () {
      final tuesday = DateTime(2026, 4, 7); // Dienstag, kein Feiertag
      expect(nextWorkday(tuesday, 'AT'), tuesday);
    });

    test('Samstag bleibt gültig (nur Sonntag/Feiertag werden übersprungen)',
        () {
      final saturday = DateTime(2026, 4, 4);
      expect(nextWorkday(saturday, 'AT'), saturday);
    });

    test('Sonntag rückt vor, auch über einen folgenden Feiertag hinweg', () {
      // 5.4.2026 ist Ostersonntag (Sonntag), 6.4.2026 Ostermontag
      // (Feiertag in AT) -> erster gültiger Tag ist der 7.4. (Dienstag).
      final sunday = DateTime(2026, 4, 5);
      expect(sunday.weekday, DateTime.sunday);
      expect(nextWorkday(sunday, 'AT'), DateTime(2026, 4, 7));
    });

    test('Feiertag rückt so lange vor, bis ein gültiger Tag erreicht ist',
        () {
      // 1.1.2026 ist ein Donnerstag (Neujahr, Feiertag in AT) -> gültig ist
      // der 2.1.2026 (Freitag).
      final result = nextWorkday(DateTime(2026, 1, 1), 'AT');
      expect(result, DateTime(2026, 1, 2));
    });

    test('ohne Land wird nur Sonntag übersprungen', () {
      final sunday = DateTime(2026, 4, 5);
      expect(nextWorkday(sunday, ''), DateTime(2026, 4, 6));
    });
  });
}
