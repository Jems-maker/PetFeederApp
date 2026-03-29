import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) return;

    // Initialize timezone database
    tz_data.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    // v20: initialize() uses named parameter 'settings'
    await _notificationsPlugin.initialize(
      settings: initializationSettings,
    );
  }

  Future<void> requestPermissions() async {
    if (kIsWeb) return;

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.requestNotificationsPermission();
    // Also request exact alarm permission on Android 12+
    await androidImplementation?.requestExactAlarmsPermission();
  }

  // ── Immediate Notification ───────────────────────────────────────────────

  Future<void> showNotification(String title, String body) async {
    if (kIsWeb) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'pet_feeder_channel',
      'Pet Feeder Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // v20: show() uses named parameters
    await _notificationsPlugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  // ── Scheduled Reminder (5 mins before meal) ──────────────────────────────

  /// Schedules a reminder notification 5 minutes before [mealTime].
  /// [notifId]: 1 = morning, 2 = noon, 3 = afternoon
  Future<void> scheduleReminderNotification({
    required int notifId,
    required String title,
    required String body,
    required DateTime mealTime,
  }) async {
    if (kIsWeb) return;

    final reminderTime = mealTime.subtract(const Duration(minutes: 5));
    final now = DateTime.now();

    // Don't schedule if the reminder time is already in the past
    if (reminderTime.isBefore(now)) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'pet_feeder_reminder_channel',
      'Meal Reminders',
      channelDescription: 'Reminds you 5 minutes before scheduled meal times',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notifDetails =
        NotificationDetails(android: androidDetails);

    // v20: zonedSchedule() uses named parameters
    await _notificationsPlugin.zonedSchedule(
      id: notifId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
      notificationDetails: notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Cancel a specific scheduled reminder by its ID.
  Future<void> cancelNotification(int notifId) async {
    if (kIsWeb) return;
    // v20: cancel() uses named parameter 'id'
    await _notificationsPlugin.cancel(id: notifId);
  }

  /// Cancel all scheduled reminders (morning=1, noon=2, afternoon=3).
  Future<void> cancelAllReminders() async {
    if (kIsWeb) return;
    await _notificationsPlugin.cancel(id: 1);
    await _notificationsPlugin.cancel(id: 2);
    await _notificationsPlugin.cancel(id: 3);
  }
}
