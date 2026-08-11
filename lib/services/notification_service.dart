import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/modules/todo_module.dart';
import '../models/project.dart';

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

  Future<void> syncForProjects(List<Project> projects) async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {
      return;
    }

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
            if (!target.isAfter(now)) continue;
            await _schedule(
              id: _notificationId(task.id),
              scheduledDate: target,
              title: 'Prio-Aufgabe bald fällig: ${gewerk.name}',
              body: '${project.name}: ${task.name}',
            );
          }
        }
      }
    }
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
          android: AndroidNotificationDetails(
            'priority_warning',
            'Prio-Aufgaben-Warnung',
            channelDescription:
                'Benachrichtigung, wenn eine offene Prio-Aufgabe die '
                'eingestellte Warnschwelle vor der Fälligkeit erreicht.',
            importance: Importance.high,
            priority: Priority.high,
          ),
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
