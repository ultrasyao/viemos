import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Semua file di assets/sounds/ dimuat otomatis berdasar nama file:
///   click.*            -> klik tombol
///   notif_in.*         -> notifikasi pemasukan
///   notif_out.*        -> notifikasi pengeluaran
///   notif_transfer.*   -> notifikasi pindah saldo
///   success.*          -> cadangan kalau notif_<jenis> tidak ada
/// Ganti file dengan suaramu sendiri (mp3/wav/ogg) dengan nama yang sama.
class Sfx {
  Sfx._();
  static bool enabled = true;
  static bool haptic = true;
  static final Map<String, AudioPlayer> _players = {};
  static final Map<String, String> _assets = {};
  static int _last = 0;

  static Future<void> init() async {
    try {
      final m = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final a in m.listAssets()) {
        if (!a.startsWith('assets/sounds/')) continue;
        final file = a.substring('assets/sounds/'.length);
        final dot = file.lastIndexOf('.');
        if (dot <= 0) continue;
        _assets.putIfAbsent(file.substring(0, dot), () => a.substring('assets/'.length));
      }
      for (final e in _assets.entries) {
        try {
          final p = AudioPlayer();
          await p.setPlayerMode(PlayerMode.lowLatency);
          await p.setSource(AssetSource(e.value));
          _players[e.key] = p;
        } catch (_) {}
      }
    } catch (_) {}
  }

  static Future<void> warm() => init();

  static void tap() => click();

  static void click() {
    if (!enabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _last < 120) return;
    _last = now;
    _play('click');
  }

  /// Suara + getar untuk notifikasi. [type]: in / out / transfer / info.
  static void notify(String type) {
    if (haptic) HapticFeedback.mediumImpact();
    if (!enabled) return;
    for (final n in ['notif_$type', 'success', 'click']) {
      if (_players.containsKey(n)) {
        _play(n);
        return;
      }
    }
  }

  static void _play(String name) {
    final p = _players[name], a = _assets[name];
    if (p == null || a == null) return;
    _go(p, a);
  }

  static Future<void> _go(AudioPlayer p, String a) async {
    try {
      await p.stop();
      await p.play(AssetSource(a));
    } catch (_) {}
  }
}
