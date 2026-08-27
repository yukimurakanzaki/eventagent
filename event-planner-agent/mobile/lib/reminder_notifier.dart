import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

abstract interface class ReminderNotifier {
  Future<void> initialize();

  Future<void> schedule({required String id, required String title, required DateTime dueAt, String note = ''});

  Future<void> cancel(String id);
}

class NoopReminderNotifier implements ReminderNotifier {
  const NoopReminderNotifier();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> schedule({required String id, required String title, required DateTime dueAt, String note = ''}) async {}

  @override
  Future<void> cancel(String id) async {}
}

class LocalReminderNotifier implements ReminderNotifier {
  LocalReminderNotifier({FlutterLocalNotificationsPlugin? plugin}) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'wargakas_deadlines';
  static const _channelName = 'Pengingat acara';
  static const _channelDescription = 'Pengingat pembayaran, pengumpulan, dan persiapan acara.';

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize() async {
    tz.initializeTimeZones();
    // The current MVP is for Indonesian community trips. Production should use the device timezone.
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> schedule({required String id, required String title, required DateTime dueAt, String note = ''}) async {
    final scheduled = tz.TZDateTime.from(dueAt, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      id: _notificationId(id),
      title: 'Wargakas: $title',
      body: note.isEmpty ? 'Pengingat untuk acara Wisata Dieng.' : note,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'reminder:$id',
    );
  }

  @override
  Future<void> cancel(String id) => _plugin.cancel(id: _notificationId(id));

  int _notificationId(String id) => id.codeUnits.fold(0, (value, unit) => (value * 31 + unit) & 0x7fffffff);
}
