import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'secure.dart';
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
    Secure.apply(secureScreen);
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

  /// Blokir screenshot & pratinjau di daftar aplikasi terbaru (default aktif).
  static bool get secureScreen => _p.getBool('secure_screen') ?? true;
  static Future<void> setSecureScreen(bool v) async {
    await _p.setBool('secure_screen', v);
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

  // ---- PIN
  // Disimpan sebagai PBKDF2-HMAC-SHA256 (20.000 putaran) + salt acak, bukan PIN asli.
  // Format baru: "pin2" = "salt:hash". Format lama (pin_hash/pin_salt, SHA-256
  // sekali jalan) tetap bisa dipakai dan otomatis diupgrade saat PIN benar.
  static const _iters = 20000;

  static bool get hasPin => _p.getString('pin2') != null || _p.getString('pin_hash') != null;
  static int get lockAfter => _p.getInt('lock_after') ?? 30; // detik
  static Future<void> setLockAfter(int s) => _p.setInt('lock_after', s);

  // hitungan salah-PIN disimpan permanen supaya tidak bisa direset dengan
  // menutup paksa aplikasi
  static int get pinFails => _p.getInt('pin_fails') ?? 0;
  static int get pinLockedUntil => _p.getInt('pin_until') ?? 0;
  static Future<void> setPinFails(int v) => _p.setInt('pin_fails', v);
  static Future<void> setPinLockedUntil(int v) => _p.setInt('pin_until', v);

  static Future<String> _derive(String pin, String salt) =>
      Isolate.run(() => _pbkdf2(pin, salt, _iters));

  static String _legacy(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static bool _eq(String a, String b) {
    if (a.length != b.length) return false;
    var d = 0;
    for (var i = 0; i < a.length; i++) {
      d |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return d == 0;
  }

  static Future<void> setPin(String pin) async {
    final r = Random.secure();
    final salt = base64UrlEncode(List<int>.generate(16, (_) => r.nextInt(256)));
    final h = await _derive(pin, salt);
    await _p.setString('pin2', '$salt:$h');
    await _p.remove('pin_hash');
    await _p.remove('pin_salt');
    await _p.remove('pin_v');
    await setPinFails(0);
    await setPinLockedUntil(0);
  }

  static Future<bool> checkPin(String pin) async {
    final v2 = _p.getString('pin2');
    if (v2 != null) {
      final i = v2.indexOf(':');
      if (i <= 0) return false;
      final salt = v2.substring(0, i);
      final h = v2.substring(i + 1);
      return _eq(await _derive(pin, salt), h);
    }
    final h = _p.getString('pin_hash'), s = _p.getString('pin_salt');
    if (h == null || s == null) return true; // tidak ada PIN
    final ok = _eq(_legacy(pin, s), h);
    if (ok) await setPin(pin); // upgrade ke format baru
    return ok;
  }

  static Future<void> clearPin() async {
    await _p.remove('pin2');
    await _p.remove('pin_hash');
    await _p.remove('pin_salt');
    await setPinFails(0);
    await setPinLockedUntil(0);
  }
}

/// PBKDF2-HMAC-SHA256, 1 blok (32 byte). Fungsi murni supaya bisa jalan di isolate.
String _pbkdf2(String pin, String salt, int iters) {
  final hmac = Hmac(sha256, utf8.encode(pin));
  var u = hmac.convert([...utf8.encode(salt), 0, 0, 0, 1]).bytes;
  final t = List<int>.from(u);
  for (var i = 1; i < iters; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < t.length; j++) {
      t[j] ^= u[j];
    }
  }
  return base64UrlEncode(t);
}
