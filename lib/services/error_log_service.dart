import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppErrorEntry {
  final DateTime time;
  final String message;
  final String? detail;

  AppErrorEntry({required this.time, required this.message, this.detail});

  Map<String, dynamic> toMap() => {
        'time': time.toIso8601String(),
        'message': message,
        'detail': detail,
      };

  factory AppErrorEntry.fromMap(Map<String, dynamic> map) => AppErrorEntry(
        time: DateTime.parse(map['time'] as String),
        message: map['message'] as String,
        detail: map['detail'] as String?,
      );
}

// Sammelt unerwartete Fehler app-weit sichtbar, statt sie nur (falls
// überhaupt) in der Konsole verschwinden zu lassen – wichtig, weil beim
// Testen auf dem Handy auf der Baustelle niemand eine Dev-Konsole
// mitlaufen hat. Kein externer Dienst (Sentry o.ä.) angebunden, bewusst
// rein lokal, bis das explizit gewünscht wird.
//
// Persistiert in SharedPreferences: gerade ein Absturz – der Hauptgrund für
// dieses Protokoll – führt oft zu einem Neustart der App, ein rein
// speicherresidentes Protokoll wäre dann bereits weg, bevor der Nutzer es
// je sehen konnte.
class ErrorLogService extends ChangeNotifier {
  ErrorLogService._() {
    _loadFuture = _load();
  }
  static final instance = ErrorLogService._();

  static const _maxEntries = 50;
  static const _prefsKey = 'baustelli_error_log';
  final List<AppErrorEntry> entries = [];

  // record()/_save() warten hierauf, bevor sie selbst SharedPreferences
  // anfassen - ohne diese Reihenfolge könnte ein sehr früher record()-Aufruf
  // (z.B. aus main.dart, falls Supabase.initialize() beim allerersten Start
  // fehlschlägt) seinen _save() abschließen, bevor _load() überhaupt
  // gelesen hat, wodurch _load() den gerade erst gespeicherten Eintrag ein
  // zweites Mal aus der Datei einliest und dupliziert.
  late final Future<void> _loadFuture;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey) ?? const [];
      entries.addAll(raw.map(
          (e) => AppErrorEntry.fromMap(jsonDecode(e) as Map<String, dynamic>)));
      if (entries.isNotEmpty) notifyListeners();
    } catch (_) {
      // Protokoll bleibt in diesem Fall einfach leer statt abzustürzen.
    }
  }

  Future<void> _save() async {
    try {
      await _loadFuture;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _prefsKey, entries.map((e) => jsonEncode(e.toMap())).toList());
    } catch (_) {}
  }

  void record(String message, [String? detail]) {
    entries.insert(
        0, AppErrorEntry(time: DateTime.now(), message: message, detail: detail));
    if (entries.length > _maxEntries) {
      entries.removeRange(_maxEntries, entries.length);
    }
    notifyListeners();
    _save();
  }

  void clear() {
    entries.clear();
    notifyListeners();
    _save();
  }
}
