import 'package:flutter/foundation.dart';

class AppErrorEntry {
  final DateTime time;
  final String message;
  final String? detail;

  AppErrorEntry({required this.time, required this.message, this.detail});
}

// Sammelt unerwartete Fehler app-weit sichtbar, statt sie nur (falls
// überhaupt) in der Konsole verschwinden zu lassen – wichtig, weil beim
// Testen auf dem Handy auf der Baustelle niemand eine Dev-Konsole
// mitlaufen hat. Kein externer Dienst (Sentry o.ä.) angebunden, bewusst
// rein lokal, bis das explizit gewünscht wird.
class ErrorLogService extends ChangeNotifier {
  ErrorLogService._();
  static final instance = ErrorLogService._();

  static const _maxEntries = 50;
  final List<AppErrorEntry> entries = [];

  void record(String message, [String? detail]) {
    entries.insert(0, AppErrorEntry(time: DateTime.now(), message: message, detail: detail));
    if (entries.length > _maxEntries) {
      entries.removeRange(_maxEntries, entries.length);
    }
    notifyListeners();
  }

  void clear() {
    entries.clear();
    notifyListeners();
  }
}
