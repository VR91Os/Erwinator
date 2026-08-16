import 'package:flutter_test/flutter_test.dart';

import 'package:baustelli/models/finance_entry.dart';
import 'package:baustelli/utils/finance_detection.dart';

// Testet nur die reine Text-Heuristik (parseFinanceText), nicht die
// PDF-Extraktion selbst - die Regex-/Stichwort-Logik ist der Teil, der bei
// Fehleinschätzungen (falsches Layout, Zwischensumme statt Endsumme) am
// ehesten nachjustiert werden muss.
void main() {
  group('parseFinanceText', () {
    test('erkennt eine Rechnung mit Netto/Brutto getrennt', () {
      const text = '''
Mustermann GmbH
Rechnungsnummer: R-2026-004
Rechnungsdatum: 01.03.2026

Pos  Beschreibung          Menge   Preis    Summe
1    Elektroinstallation   1       800,00   800,00

Nettobetrag                        800,00 €
zzgl. 20% MwSt                     160,00 €
Gesamtbetrag                       960,00 €

Bitte überweisen Sie den Betrag bis 15.03.2026.
''';
      final result = parseFinanceText(text);
      expect(result.documentType, FinanceDocumentType.rechnung);
      expect(result.amountGross, 960.0);
      expect(result.amountNet, 800.0);
    });

    test('erkennt ein Angebot mit vierstelligem Betrag (Tausenderpunkt)', () {
      const text = '''
Mustermann GmbH
Angebotsnummer: A-2026-011
Kostenvoranschlag für Malerarbeiten

Nettobetrag                        1.200,00 €
zzgl. 20% MwSt                       240,00 €
Gesamtbetrag                       1.440,00 €

Dieses Angebot ist freibleibend und 30 Tage gültig.
''';
      final result = parseFinanceText(text);
      expect(result.documentType, FinanceDocumentType.angebot);
      expect(result.amountGross, 1440.0);
      expect(result.amountNet, 1200.0);
    });

    test('nur ein Betrag im Dokument gilt als Brutto, Netto bleibt leer', () {
      const text = '''
Kleinbetragsrechnung
Rechnungsnummer: R-2026-099
Betrag: 55,00 €
''';
      final result = parseFinanceText(text);
      expect(result.documentType, FinanceDocumentType.rechnung);
      expect(result.amountGross, 55.0);
      expect(result.amountNet, isNull);
    });

    test('unklarer Text ohne erkennbare Stichwörter liefert ein leeres Ergebnis', () {
      const text = 'Baustelle Nordseite, Foto vom 03.05.2026';
      final result = parseFinanceText(text);
      expect(result.isEmpty, isTrue);
    });
  });
}
