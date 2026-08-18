import 'package:flutter/services.dart';

// Setzt Tausenderpunkte in eine rein numerische Ziffernfolge (kein
// Vorzeichen, kein Dezimalteil), z.B. "1234" -> "1.234". Gemeinsam
// verwendet von formatAmount() und ThousandsSeparatorInputFormatter, damit
// die Gruppierungslogik nicht doppelt gepflegt werden muss.
String _groupThousands(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

// Formatiert einen Betrag im deutschen Format (Tausenderpunkt, Komma als
// Dezimaltrennzeichen), z.B. 1234.5 -> "1.234,50" (+ " €" mit [withSuffix]).
String formatAmount(double value, {bool withSuffix = true}) {
  final fixed = value.toStringAsFixed(2);
  final dotIndex = fixed.indexOf('.');
  final decPart = fixed.substring(dotIndex + 1);
  var intPart = fixed.substring(0, dotIndex);
  final negative = intPart.startsWith('-');
  if (negative) intPart = intPart.substring(1);

  final formatted =
      '${negative ? '-' : ''}${_groupThousands(intPart)},$decPart';
  return withSuffix ? '$formatted €' : formatted;
}

// Für die Vorbefüllung von Eingabefeldern (kein "€"-Suffix).
String formatAmountForInput(double? value) =>
    value == null ? '' : formatAmount(value, withSuffix: false);

// Liest eine Nutzereingabe im deutschen Format ("1.234,56", "1234,56" oder
// "1234.56") zurück in eine Zahl ein.
double? parseAmount(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  return double.tryParse(trimmed.replaceAll('.', '').replaceAll(',', '.'));
}

// Rundet kaufmännisch auf ganze Cent (vermeidet Fließkomma-Rundungsreste
// wie 123.449999999999999).
double roundToCents(double value) => (value * 100).round() / 100;

// Formatiert Betragsfelder live mit Tausenderpunkten während der Eingabe;
// die Nachkommastellen nach dem Komma bleiben dabei unangetastet.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final selectionFromEnd = newValue.text.length - newValue.selection.end;

    final commaIndex = newValue.text.indexOf(',');
    final intSection = commaIndex == -1
        ? newValue.text
        : newValue.text.substring(0, commaIndex);
    final intDigits = intSection.replaceAll(RegExp(r'[^0-9]'), '');
    final decDigits = commaIndex == -1
        ? ''
        : newValue.text
            .substring(commaIndex + 1)
            .replaceAll(RegExp(r'[^0-9]'), '');

    final groupedInt = _groupThousands(intDigits);
    final formatted =
        commaIndex == -1 ? groupedInt : '$groupedInt,$decDigits';

    final newOffset =
        (formatted.length - selectionFromEnd).clamp(0, formatted.length);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}
