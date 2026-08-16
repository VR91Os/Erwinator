import 'dart:typed_data';

import 'package:pdf_manipulator/pdf_manipulator.dart';

import '../models/finance_entry.dart';

// Automatische Voranalyse eines hochgeladenen PDFs: liest den Text aus und
// versucht per Stichwort-Heuristik zu erkennen, ob es sich um ein Angebot
// oder eine Rechnung handelt und welcher Netto-/Bruttobetrag genannt wird.
//
// Rein heuristisch (Stichwort-Suche + Zahlenformat), kein Layout-Verständnis
// und keine Garantie auf Korrektheit - das Ergebnis füllt ausschließlich den
// ohnehin vorhandenen manuellen Erfassen-Dialog vor, der immer vom Nutzer
// bestätigt werden muss. Bei Geldbeträgen gibt es hier bewusst keine
// automatische Übernahme ohne Bestätigung.
class FinanceDetectionResult {
  final String? documentType; // FinanceDocumentType.angebot | .rechnung
  final double? amountGross;
  final double? amountNet;

  const FinanceDetectionResult({
    this.documentType,
    this.amountGross,
    this.amountNet,
  });

  bool get isEmpty =>
      documentType == null && amountGross == null && amountNet == null;
}

final _amountPattern = RegExp(
  r'(\d{1,3}(?:\.\d{3})*,\d{2}|\d+,\d{2})\s*(?:€|EUR)?',
  caseSensitive: false,
);

// Reihenfolge relevant: je spezifischer das Stichwort, desto eher steht es
// tatsächlich neben dem gesuchten Betrag statt einer Zwischensumme.
const _grossKeywords = [
  'gesamtbetrag',
  'bruttobetrag',
  'endbetrag',
  'rechnungsbetrag',
  'zu zahlender betrag',
  'zu zahlen',
  'gesamtsumme',
];
const _grossFallbackKeywords = ['summe', 'betrag'];
const _netKeywords = ['nettobetrag', 'netto'];

double? _parseGermanAmount(String raw) {
  final cleaned = raw.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(cleaned);
}

// Sucht zeilenweise nach einem der Stichwörter und nimmt die zuletzt im
// Dokument gefundene Übereinstimmung (typisches Rechnungslayout: Zwischen-
// summen zuerst, Gesamtbetrag am Ende) statt der ersten.
double? _findAmountNear(String text, List<String> keywords) {
  double? found;
  for (final line in text.split('\n')) {
    final lower = line.toLowerCase();
    if (!keywords.any((k) => lower.contains(k))) continue;
    final matches = _amountPattern.allMatches(line).toList();
    if (matches.isEmpty) continue;
    final parsed = _parseGermanAmount(matches.last.group(1)!);
    if (parsed != null) found = parsed;
  }
  return found;
}

int _count(String haystack, String needle) => haystack.split(needle).length - 1;

String? _detectDocumentType(String text) {
  final lower = text.toLowerCase();
  final hasRechnungsnummer =
      lower.contains('rechnungsnummer') || lower.contains('rechnungs-nr');
  final hasAngebotsnummer = lower.contains('angebotsnummer') ||
      lower.contains('angebots-nr') ||
      lower.contains('kostenvoranschlag');
  if (hasRechnungsnummer && !hasAngebotsnummer) {
    return FinanceDocumentType.rechnung;
  }
  if (hasAngebotsnummer && !hasRechnungsnummer) {
    return FinanceDocumentType.angebot;
  }

  final rechnungCount = _count(lower, 'rechnung');
  final angebotCount = _count(lower, 'angebot') + _count(lower, 'kostenvoranschlag');
  if (rechnungCount == 0 && angebotCount == 0) return null;
  return rechnungCount >= angebotCount
      ? FinanceDocumentType.rechnung
      : FinanceDocumentType.angebot;
}

// Reine Text-Heuristik, ohne PDF-Zugriff - separat testbar von
// [detectFinanceInfo], das zusätzlich die PDF-Textextraktion übernimmt.
FinanceDetectionResult parseFinanceText(String text) {
  final gross = _findAmountNear(text, _grossKeywords) ??
      _findAmountNear(text, _grossFallbackKeywords);
  return FinanceDetectionResult(
    documentType: _detectDocumentType(text),
    amountGross: gross,
    // Wird nur eine Zahl im ganzen Dokument gefunden, gilt sie als Brutto
    // (siehe oben) - Netto bleibt dann bewusst leer statt geraten.
    amountNet: _findAmountNear(text, _netKeywords),
  );
}

// Gibt ein leeres Ergebnis zurück, wenn die Datei nicht gelesen werden kann
// (verschlüsselt, beschädigt, kein Text-PDF) - der manuelle Dialog öffnet
// sich dann einfach ohne Vorbefüllung, statt die Aktion abzubrechen.
Future<FinanceDetectionResult> detectFinanceInfo(Uint8List pdfBytes) async {
  final pdf = Pdf();
  try {
    final doc = await pdf.open(MemorySource(pdfBytes));
    try {
      final text = await doc.extract(pages: const PdfPages.all());
      return parseFinanceText(text);
    } finally {
      await doc.dispose();
    }
  } catch (_) {
    return const FinanceDetectionResult();
  } finally {
    await pdf.dispose();
  }
}
