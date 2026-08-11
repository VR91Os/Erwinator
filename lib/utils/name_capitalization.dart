import 'package:flutter/services.dart';

// Großschreibt automatisch den ersten Buchstaben jedes Wortes (nach
// Leerzeichen, Komma, Bindestrich oder Zeilenanfang), z.B. für
// Helfer-/Personennamen. Der Rest der Eingabe bleibt unangetastet, damit
// z.B. bewusst großgeschriebene Buchstaben in der Mitte (z.B. "McCoy")
// nicht überschrieben werden.
final _wordBoundary = RegExp(r'[ ,\-]');

// Großschreibt den ersten Buchstaben jedes Wortes (nach Leerzeichen, Komma,
// Bindestrich oder Zeichenkettenanfang). Der Rest bleibt unangetastet, damit
// z.B. bewusst großgeschriebene Buchstaben in der Mitte (z.B. "McCoy")
// nicht überschrieben werden. Für programmatische Änderungen, z.B. nach
// Auswahl aus einer Autovervollständigung.
String capitalizeName(String input) {
  final buffer = StringBuffer();
  var capitalizeNext = true;
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    buffer.write(capitalizeNext ? char.toUpperCase() : char);
    capitalizeNext = _wordBoundary.hasMatch(char);
  }
  return buffer.toString();
}

// Wie [capitalizeName], aber live während der Eingabe in ein TextField.
class NameCapitalizationFormatter extends TextInputFormatter {
  const NameCapitalizationFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    return newValue.copyWith(text: capitalizeName(text));
  }
}

// Trennt eine Namenseingabe an Kommas in einzelne, getrimmte, großgeschriebene
// Personennamen, z.B. "anna huber, max mustermann" -> ["Anna Huber", "Max
// Mustermann"].
List<String> splitNames(String input) => input
    .split(',')
    .map((n) => capitalizeName(n.trim()))
    .where((n) => n.isNotEmpty)
    .toList();
