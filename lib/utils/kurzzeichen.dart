// Erzeugt automatisch ein 4-stelliges Namenskürzel aus Vor- und Nachname
// (je 2 Buchstaben). Kollidiert das Kürzel mit einem bereits vergebenen,
// wird eine fortlaufende Ziffer angehängt, bis es eindeutig ist.
String generateKurzzeichen(String fullName, Iterable<String> existing) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  final vorname = parts.isNotEmpty ? parts.first : '';
  final nachname = parts.length > 1 ? parts.last : '';

  String twoLetters(String name) {
    final letters = name.toUpperCase();
    if (letters.length >= 2) return letters.substring(0, 2);
    return letters.padRight(2, 'X');
  }

  final base = twoLetters(vorname) + twoLetters(nachname);
  final taken = existing.map((e) => e.toUpperCase()).toSet();

  if (!taken.contains(base)) return base;

  var suffix = 2;
  while (taken.contains('$base$suffix')) {
    suffix++;
  }
  return '$base$suffix';
}
