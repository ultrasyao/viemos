import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class Sfx {
  Sfx._();
  static bool enabled = true;
  static final Map<String, AudioPlayer> _players = {};

  static Future<void> warm() async {
    for (final n in ['tap', 'pop', 'success']) {
      try {
        final p = AudioPlayer();
        _players[n] = p;
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setSource(AssetSource('sounds/$n.wav'));
      } catch (_) {}
    }
  }

  static Future<void> _play(String name, double vol) async {
    if (!enabled) return;
    try {
      var p = _players[name];
      if (p == null) {
        p = AudioPlayer();
        _players[name] = p;
        await p.setPlayerMode(PlayerMode.lowLatency);
      }
      await p.play(AssetSource('sounds/$name.wav'), volume: vol);
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  static void tap() {
    HapticFeedback.selectionClick();
    _play('tap', 0.7);
  }

  static void pop() {
    HapticFeedback.lightImpact();
    _play('pop', 0.8);
  }

  static void ok() {
    HapticFeedback.mediumImpact();
    _play('success', 0.9);
  }
}
