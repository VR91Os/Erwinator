import 'package:flutter/widgets.dart';

// Schließt einen Dialog und führt [mutate] (i.d.R. einen Store-Aufruf) erst
// im nächsten Frame aus. Nötig, weil eine Mutation, die synchron
// notifyListeners() auslöst, mit dem Element-Abbau kollidieren kann, den
// Navigator.pop noch im selben Frame durchführt ("_dependents.isEmpty"-
// Assertion) - unabhängig davon, ob pop() vor oder nach der Mutation
// aufgerufen wird. Ersetzt die zuvor an >20 Stellen wiederholte
// Navigator.pop(...) + WidgetsBinding.instance.addPostFrameCallback(...)
// -Kombination durch einen einzigen, immer korrekt benutzten Aufruf.
void popDialogThen(BuildContext dialogContext, VoidCallback mutate) {
  Navigator.pop(dialogContext);
  WidgetsBinding.instance.addPostFrameCallback((_) => mutate());
}

// Wie [popDialogThen], aber ohne einen Dialog zu schließen - für
// Provider-Rebuilds, die mit einer anderen laufenden Element-Umstrukturierung
// kollidieren können, z.B. während ReorderableListView/SliverReorderableList
// das Drag-Ende noch intern verarbeitet.
void deferredNotify(VoidCallback mutate) {
  WidgetsBinding.instance.addPostFrameCallback((_) => mutate());
}
