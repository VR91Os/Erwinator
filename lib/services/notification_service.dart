import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/modules/todo_module.dart';
import '../models/project.dart';
import 'error_log_service.dart';

// Plant echte Hintergrund-Benachrichtigungen für offene Prio-Aufgaben, die
// die projektweit einstellbare Warnschwelle (Tage vor Fälligkeit) erreichen.
// Bei jeder relevanten Änderung wird der komplette Soll-Zustand aus den
// Projektdaten neu berechnet und alle Benachrichtigungen entsprechend neu
// geplant (statt einzelne Termine gezielt zu suchen/aktualisieren) – das
// bleibt auch bei Statuswechseln, gelöschten Aufgaben oder geänderten
// Einstellungen automatisch korrekt.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      // Zeitzone nicht ermittelbar (z.B. Plattform ohne Unterstützung) ->
      // bei der Standard-Location (UTC) bleiben, statt abzustürzen.
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: darwinSettings,
          macOS: darwinSettings,
        ),
      );
    } catch (_) {
      // Plattform ohne Unterstützung (z.B. Linux ohne Notification-Server)
      // -> App bleibt nutzbar, es gibt dann einfach keine Push-Nachrichten.
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  // Stabile Notification-ID aus der (app-weit eindeutigen) Task-ID.
  int _notificationId(String taskId) => taskId.hashCode & 0x7fffffff;

  static const _channelDetails = AndroidNotificationDetails(
    'priority_warning',
    'Prio-Aufgaben-Warnung',
    channelDescription:
        'Benachrichtigung, wenn eine offene Prio-Aufgabe die '
        'eingestellte Warnschwelle vor der Fälligkeit erreicht.',
    importance: Importance.high,
    priority: Priority.high,
  );

  // Merkt sich lokal, für welche Aufgaben bereits eine
  // Nachhol-Benachrichtigung (siehe unten) gezeigt wurde, damit sie bei
  // jedem Sync (der bei jeder Projekt-Änderung läuft) nicht erneut feuert.
  static const _catchUpPrefsKey = 'baustelli_overdue_notified_task_ids';

  Future<void> syncForProjects(List<Project> projects) async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (e, stack) {
      // Nicht abbrechen: auch wenn das Aufräumen alter Termine fehlschlägt,
      // soll die Nachhol-Benachrichtigung für verpasste Warnschwellen unten
      // trotzdem laufen, statt auf Plattformen mit fehlschlagendem
      // cancelAll() dauerhaft und unbemerkt nie mehr auszulösen.
      ErrorLogService.instance
          .record('Benachrichtigungen zurücksetzen fehlgeschlagen', '$e\n$stack');
    }

    final prefs = await SharedPreferences.getInstance();
    final alreadyNotified =
        (prefs.getStringList(_catchUpPrefsKey) ?? const []).toSet();
    final stillOverdue = <String>{};

    final now = DateTime.now();
    for (final project in projects) {
      if (!project.notifyOnPriorityWarning) continue;
      for (final gewerk in project.gewerke) {
        for (final module in gewerk.modules.whereType<TodoModule>()) {
          for (final task in module.tasks) {
            if (task.status != 'offen' ||
                !task.isHighPriority ||
                task.dueDate == null) {
              continue;
            }
            final target = task.dueDate!
                .subtract(Duration(days: project.priorityWarningDays));
            if (target.isAfter(now)) {
              await _schedule(
                id: _notificationId(task.id),
                scheduledDate: target,
                title: 'Prio-Aufgabe bald fällig: ${gewerk.name}',
                body: '${project.name}: ${task.name}',
              );
              continue;
            }
            // Warnschwelle liegt bereits in der Vergangenheit – die App
            // war zu dem Zeitpunkt vermutlich nicht offen, sonst wäre
            // die Aufgabe schon oben geplant worden. Statt sie
            // stillschweigend zu überspringen, einmalig sofort nachholen.
            stillOverdue.add(task.id);
            if (!alreadyNotified.contains(task.id)) {
              await _showNow(
                id: _notificationId(task.id),
                title: 'Prio-Aufgabe überfällig: ${gewerk.name}',
                body: '${project.name}: ${task.name}',
              );
            }
          }
        }
      }
    }

    try {
      await prefs.setStringList(_catchUpPrefsKey, stillOverdue.toList());
    } catch (_) {}
  }

  Future<void> _schedule({
    required int id,
    required DateTime scheduledDate,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: _channelDetails,
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {
      // Fehlende Berechtigung o.ä. -> die farbliche Reiter-Markierung bleibt
      // in jedem Fall als Hinweis bestehen, die App darf nicht abstürzen.
    }
  }

  // Sofortige Nachhol-Benachrichtigung für eine Warnschwelle, die die App
  // bereits verpasst hat (siehe syncForProjects), statt einer zeitgeplanten.
  Future<void> _showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: _channelDetails,
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {
      // Fehlende Berechtigung o.ä. -> die farbliche Reiter-Markierung bleibt
      // in jedem Fall als Hinweis bestehen, die App darf nicht abstürzen.
    }
  }
}
