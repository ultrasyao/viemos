import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Pengingat harian (notifikasi sistem Android).
class Notifs {
  Notifs._();
  static final FlutterLocalNotificationsPlugin _p = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static const _id = 1001;

  static Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      const init = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _p.initialize(init);
      _ready = true;
    } catch (_) {}
  }

  /// Minta izin notifikasi (Android 13+). true = boleh.
  static Future<bool> ask() async {
    await init();
    try {
      final a = _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final ok = await a?.requestNotificationsPermission();
      return ok ?? true;
    } catch (_) {
      return false;
    }
  }

  static NotificationDetails _details() => const NotificationDetails(
        android: AndroidNotificationDetails(
          'viemos_reminder',
          'Pengingat harian',
          channelDescription: 'Pengingat untuk mencatat transaksi',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );

  // Zona waktu = zona HP saat ini (Indonesia tidak ada DST, jadi aman).
  static tz.Location _local() {
    final off = DateTime.now().timeZoneOffset.inMilliseconds;
    for (final n in const ['Asia/Jakarta', 'Asia/Makassar', 'Asia/Jayapura']) {
      final l = tz.getLocation(n);
      if (l.currentTimeZone.offset == off) return l;
    }
    for (final l in tz.timeZoneDatabase.locations.values) {
      if (l.currentTimeZone.offset == off) return l;
    }
    return tz.getLocation('Asia/Jakarta');
  }

  /// Jadwalkan notifikasi tiap hari jam [minutes] (menit sejak 00:00).
  static Future<void> scheduleDaily(int minutes) async {
    await init();
    if (!_ready) return;
    try {
      final loc = _local();
      final now = tz.TZDateTime.now(loc);
      var at = tz.TZDateTime(loc, now.year, now.month, now.day, minutes ~/ 60, minutes % 60);
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
      await _p.zonedSchedule(
        _id,
        'Waktunya catat keuangan',
        'Sudah catat transaksi hari ini? Ketuk untuk buka Viemos.',
        at,
        _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {}
  }

  static Future<void> cancel() async {
    await init();
    try {
      await _p.cancel(_id);
    } catch (_) {}
  }

  static Future<void> test() async {
    await init();
    try {
      await _p.show(1002, 'Tes pengingat', 'Notifikasi Viemos berfungsi 👍', _details());
    } catch (_) {}
  }
}
