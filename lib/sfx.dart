import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Taruh suaramu di assets/sounds/ dengan nama click.mp3 / click.wav / click.ogg
class Sfx {
  Sfx._();
  static bool enabled = true;
  static AudioPlayer? _player;
  static String? _asset;
  static int _last = 0;

  static Future<void> init() async {
    try {
      final m = await AssetManifest.loadFromAssetBundle(rootBundle);
      final found =
          m.listAssets().where((a) => a.startsWith('assets/sounds/click.')).toList();
      if (found.isEmpty) return;
      _asset = found.first.substring('assets/'.length);
      final p = AudioPlayer();
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setSource(AssetSource(_asset!));
      _player = p;
    } catch (_) {}
  }

  static Future<void> warm() => init();

  static void tap() => click();

  static void click() {
    final p = _player, a = _asset;
    if (!enabled || p == null || a == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _last < 120) return;
    _last = now;
    _play(p, a);
  }

  static Future<void> _play(AudioPlayer p, String a) async {
    try {
      await p.stop();
      await p.play(AssetSource(a));
    } catch (_) {}
  }
}
