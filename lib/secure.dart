import 'package:flutter/services.dart';

/// Blokir screenshot / rekaman layar / pratinjau di "aplikasi terbaru"
/// (FLAG_SECURE di sisi Android, lihat ci/patch_android.py).
class Secure {
  Secure._();
  static const _ch = MethodChannel('viemos/secure');

  static Future<void> apply(bool on) async {
    try {
      await _ch.invokeMethod<void>('set', {'on': on});
    } catch (_) {
      // platform lain / belum dipatch: abaikan
    }
  }
}
