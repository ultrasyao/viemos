import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'lock.dart';
import 'sfx.dart';
import 'ui.dart';

const _bg = Color(0xFF0A0D0E);
const _word = 'Viemos';
const _style = TextStyle(
    fontSize: 46, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1);

/// Animasi masuk ala X: "Viemos" muncul dengan suara, menahan sebentar lalu
/// langsung membesar ke arah layar — huruf-hurufnya jadi "jendela" yang
/// membuka dan aplikasi terlihat dari baliknya. Ditaruh DI ATAS aplikasi.
class Intro extends StatefulWidget {
  final VoidCallback onDone;
  const Intro({super.key, required this.onDone});
  @override
  State<Intro> createState() => _IntroState();
}

class _IntroState extends State<Intro> with SingleTickerProviderStateMixin {
  // titik waktu (0..1 dari total durasi)
  static const _zoomAt = 0.68;
  static const _soundAt = 0.655;

  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));
  bool _done = false, _started = false, _zoomSound = false;

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  void initState() {
    super.initState();
    _c.addListener(_tick);
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    });
    // kalau app dikunci PIN, tunggu sampai terbuka baru animasi jalan
    if (Lock.locked.value) {
      Lock.locked.addListener(_waitUnlock);
    } else {
      _start();
    }
  }

  void _waitUnlock() {
    if (Lock.locked.value) return;
    Lock.locked.removeListener(_waitUnlock);
    _start();
  }

  void _start() {
    if (_started || !mounted) return;
    _started = true;
    Sfx.whenReady().then((_) {
      if (mounted) Sfx.play('intro_appear');
    });
    _c.forward();
  }

  void _tick() {
    if (!_zoomSound && _c.value >= _soundAt) {
      _zoomSound = true;
      Sfx.play('intro_open');
      Sfx.buzz();
    }
  }

  @override
  void dispose() {
    Lock.locked.removeListener(_waitUnlock);
    _c.dispose();
    super.dispose();
  }

  void _skip() {
    if (!_started) return;
    // lompat ke tahap membuka kalau belum sampai sana
    if (_c.value < _soundAt - 0.02) _c.forward(from: _soundAt - 0.04);
  }

  Widget _letter(String ch, int i) {
    final s = 0.04 + i * 0.045;
    final t = Interval(s, s + 0.2, curve: Curves.easeOutCubic).transform(_c.value);
    Widget w = Text(ch, style: _style);
    final sig = (1 - t) * 10;
    if (sig > 0.2) {
      w = ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: sig, sigmaY: sig), child: w);
    }
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, (1 - t) * 26), child: w),
    );
  }

  Widget _plainWord() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (var i = 0; i < _word.length; i++) Text(_word[i], style: _style)],
      );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final c = _c.value;
          final zoomP = const Interval(_zoomAt, 1.0).transform(c); // 0..1 linear
          final zq = Curves.easeInCubic.transform(zoomP);
          final antic = Interval(0.60, _zoomAt, curve: Curves.easeInOut).transform(c);
          final base = 1 - 0.08 * antic; // menarik napas sebelum meledak
          const maxScale = 46.0;
          final scale = c < _zoomAt
              ? base
              : 0.92 * math.exp(math.log(maxScale / 0.92) * zq);
          final shine = Interval(0.42, 0.62, curve: Curves.easeInOut).transform(c);
          final whiteOp = c < _zoomAt ? 1.0 : (1 - zoomP / 0.22).clamp(0.0, 1.0).toDouble();
          final bgA = c < _zoomAt
              ? 1.0
              : (1 - const Interval(0.5, 0.95, curve: Curves.easeIn).transform(zq))
                  .clamp(0.0, 1.0)
                  .toDouble();
          final tagIn = const Interval(0.40, 0.52, curve: Curves.easeOutCubic).transform(c);
          final tagOut = const Interval(0.57, 0.64).transform(c);
          final tag = tagIn * (1 - tagOut);

          final Widget backdrop = c < _zoomAt
              ? const ColoredBox(color: _bg)
              // huruf = lubang: warna gelap di mana-mana KECUALI di dalam huruf
              : ColorFiltered(
                  colorFilter:
                      ColorFilter.mode(_bg.withAlpha((255 * bgA).round()), BlendMode.srcOut),
                  child: SizedBox.expand(
                    child: Center(child: Transform.scale(scale: scale, child: _plainWord())),
                  ),
                );

          return Stack(
            fit: StackFit.expand,
            children: [
              backdrop,
              if (whiteOp > 0)
                Center(
                  child: Opacity(
                    opacity: whiteOp,
                    child: Transform.scale(
                      scale: scale,
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (r) => LinearGradient(
                          begin: Alignment(-2 + 4 * shine, 0),
                          end: Alignment(-1 + 4 * shine, 0),
                          colors: const [Colors.white, Color(0xFFFFC98F), Colors.white],
                          stops: const [0, 0.5, 1],
                        ).createShader(r),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [for (var i = 0; i < _word.length; i++) _letter(_word[i], i)],
                        ),
                      ),
                    ),
                  ),
                ),
              if (tag > 0)
                Align(
                  alignment: const Alignment(0, 0.16),
                  child: Opacity(
                    opacity: tag,
                    child: Transform.translate(
                      offset: Offset(0, (1 - tagIn) * 10),
                      child: const Text('Catat. Pantau. Tenang.',
                          style: TextStyle(color: kMuted, letterSpacing: 2, fontSize: 13)),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
