import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sfx.dart';
import 'ui.dart';

/// Semua pengaturan aplikasi. Panggil `await Prefs.load()` sekali di main().
class Prefs {
  Prefs._();
  static SharedPreferences? _sp;
  static SharedPreferences get _p => _sp!;

  static Future<void> load() async {
    _sp = await SharedPreferences.getInstance();
    apply();
  }

  /// Sinkronkan pengaturan ke variabel global yang dipakai layar lain.
  static void apply() {
    Sfx.enabled = sound;
    Sfx.haptic = haptic;
    kDecimals = decimals;
  }

  // ---- tampilan & suara
  static bool get sound => _p.getBool('sound') ?? true;
  static bool get haptic => _p.getBool('haptic') ?? true;
  static bool get decimals => _p.getBool('decimals') ?? false;
  static Future<void> setSound(bool v) async {
    await _p.setBool('sound', v);
    apply();
  }

  static Future<void> setHaptic(bool v) async {
    await _p.setBool('haptic', v);
    apply();
  }

  static Future<void> setDecimals(bool v) async {
    await _p.setBool('decimals', v);
    apply();
  }

  // ---- pengingat (menit sejak 00:00)
  static bool get reminderOn => _p.getBool('reminder_on') ?? false;
  static int get reminderMin => _p.getInt('reminder_min') ?? 21 * 60;
  static Future<void> setReminderOn(bool v) => _p.setBool('reminder_on', v);
  static Future<void> setReminderMin(int v) => _p.setInt('reminder_min', v);

  // ---- backup otomatis
  static bool get autoBackup => _p.getBool('auto_backup') ?? false;
  static String? get backupDir => _p.getString('backup_dir');
  static int get lastBackup => _p.getInt('last_backup') ?? 0;
  static Future<void> setAutoBackup(bool v) => _p.setBool('auto_backup', v);
  static Future<void> setBackupDir(String v) => _p.setString('backup_dir', v);
  static Future<void> setLastBackup(int v) => _p.setInt('last_backup', v);

  // ---- PIN (disimpan sebagai hash + salt, bukan PIN asli)
  static bool get hasPin => _p.getString('pin_hash') != null;
  static int get lockAfter => _p.getInt('lock_after') ?? 30; // detik
  static Future<void> setLockAfter(int s) => _p.setInt('lock_after', s);

  static String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static Future<void> setPin(String pin) async {
    final r = Random.secure();
    final salt = base64UrlEncode(List<int>.generate(12, (_) => r.nextInt(256)));
    await _p.setString('pin_salt', salt);
    await _p.setString('pin_hash', _hash(pin, salt));
  }

  static bool checkPin(String pin) {
    final h = _p.getString('pin_hash'), s = _p.getString('pin_salt');
    if (h == null || s == null) return true;
    return _hash(pin, s) == h;
  }

  static Future<void> clearPin() async {
    await _p.remove('pin_hash');
    await _p.remove('pin_salt');
  }
}
