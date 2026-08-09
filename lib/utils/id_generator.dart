int _counter = 0;

// Zähler-Suffix verhindert kollidierende IDs, wenn mehrere IDs synchron
// in derselben Millisekunde erzeugt werden (z.B. Start-Gewerke beim
// Projekt-Anlegen).
String newId() {
  _counter++;
  return '${DateTime.now().millisecondsSinceEpoch}-$_counter';
}
