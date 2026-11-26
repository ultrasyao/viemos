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

/// Animasi masuk 3D: huruf "Viemos" terbang masuk dari kejauhan dan membalik,
/// punya ketebalan (extrude) + perspektif, bergoyang pelan sambil berkilau,
/// lalu memipih dan membesar ke arah layar — huruf-hurufnya jadi "jendela"
/// yang membuka dan aplikasi terlihat dari baliknya. Ditaruh DI ATAS aplikasi.
/// [progress] (0..1) dipakai Root untuk menarik aplikasi masuk 3D bersamaan.
class Intro extends StatefulWidget {
  final VoidCallback onDone;
  final ValueNotifier<double>? progress;
  const Intro({super.key, required this.onDone, this.progress});
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
    widget.progress?.value = _c.value;
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

  /// Satu huruf. [face] = muka depan (ada blur masuk); selain itu = lapisan tebal.
  Widget _letter(String ch, int i, Color color, {bool face = false}) {
    final st = 0.04 + i * 0.05;
    final t = Interval(st, st + 0.24, curve: Curves.easeOutCubic).transform(_c.value);
    Widget w = Text(ch, style: _style.copyWith(color: color));
    final sig = (1 - t) * 10;
    if (face && sig > 0.2) {
      w = ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: sig, sigmaY: sig), child: w);
    }
    return Opacity(
      opacity: t,
      child: Transform(
        alignment: Alignment.center,
        // terbang dari jauh (z positif = menjauh) sambil membalik ke atas
        transform: Matrix4.translationValues(0, (1 - t) * 40, (1 - t) * 170) *
            Matrix4.rotationX((1 - t) * -1.3),
        child: w,
      ),
    );
  }

  Widget _row(Color color, {bool face = false}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (var i = 0; i < _word.length; i++) _letter(_word[i], i, color, face: face)],
      );

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

          // ---- parameter 3D
          final grow = const Interval(0.10, 0.32, curve: Curves.easeOutCubic).transform(c);
          final collapse = 1 - const Interval(0.60, 0.665, curve: Curves.easeIn).transform(c);
          final depthF = c >= _zoomAt ? 0.0 : grow * collapse; // 0..1 ketebalan
          final sw = const Interval(0.08, 0.64).transform(c);
          final rotY = math.sin(sw * math.pi * 2) * 0.62; // bergoyang, berhenti rata
          final rotX = -0.26 * math.sin(sw * math.pi);
          final glow = c >= _zoomAt
              ? 0.0
              : const Interval(0.05, 0.5, curve: Curves.easeOut).transform(c) *
                  (1 - antic * 0.6);

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

          const layers = 10;
          final Widget word3d = Transform(
            alignment: Alignment.center,
            transform: persp(0.001) *
                Matrix4.rotationX(rotX) *
                Matrix4.rotationY(rotY) *
                Matrix4.diagonal3Values(scale, scale, 1.0),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // ketebalan huruf: salinan makin gelap & makin jauh di belakang
                if (depthF > 0.02)
                  for (var k = layers; k >= 1; k--)
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.translationValues(0, 0, k * 2.2 * depthF),
                      child: _row(Color.lerp(const Color(0xFFFFB066), const Color(0xFF2B1B21), k / layers)!),
                    ),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (r) => LinearGradient(
                    begin: Alignment(-2 + 4 * shine, 0),
                    end: Alignment(-1 + 4 * shine, 0),
                    colors: const [Colors.white, Color(0xFFFFC98F), Colors.white],
                    stops: const [0, 0.5, 1],
                  ).createShader(r),
                  child: _row(Colors.white, face: true),
                ),
              ],
            ),
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              backdrop,
              if (glow > 0)
                Center(
                  child: Container(
                    width: 380,
                    height: 380,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [kOrange.withAlpha((46 * glow).round()), Colors.transparent],
                      ),
                    ),
                  ),
                ),
              if (glow > 0)
                // pantulan cahaya di "lantai" di bawah huruf
                Align(
                  alignment: const Alignment(0, 0.2),
                  child: Opacity(
                    opacity: (0.55 * glow * (0.6 + 0.4 * depthF)).clamp(0.0, 1.0).toDouble(),
                    child: Container(
                      width: 230,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [BoxShadow(color: kOrange.withAlpha(90), blurRadius: 34, spreadRadius: 4)],
                      ),
                    ),
                  ),
                ),
              if (whiteOp > 0)
                Center(
                  child: Opacity(opacity: whiteOp, child: word3d),
                ),
              if (tag > 0)
                Align(
                  alignment: const Alignment(0, 0.24),
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
