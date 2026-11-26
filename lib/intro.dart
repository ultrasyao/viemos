import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'lock.dart';
import 'sfx.dart';
import 'ui.dart';

const _bg = Color(0xFF0A0D0E);
const _word = 'Viemos';
const _zoomLetter = 4; // huruf "o" — kamera masuk ke lubang tengahnya
const _fs = 46.0;
const _style = TextStyle(fontSize: _fs, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1);

/// Titik waktu (0..1) mulai zoom. Dipakai Root untuk menarik aplikasi masuk.
const kIntroZoomAt = 0.66;

/// Animasi masuk 3D: "Viemos" terbang masuk dan membalik, huruf-hurufnya
/// menebal (extrude) lalu bergoyang sebentar, kemudian kamera masuk ke dalam
/// lubang huruf "o" — lubangnya membesar sampai memenuhi layar dan aplikasi
/// terlihat dari baliknya. Ditaruh DI ATAS aplikasi.
/// [progress] (0..1) dipakai Root untuk menarik aplikasi masuk bersamaan.
///
/// Dibuat ringan (target 60fps): tanpa blur/saveLayer besar, lapisan tebal
/// digambar sebagai 1 teks per lapisan, dan tahap zoom cuma menggambar satu
/// huruf + satu mask berlubang.
class Intro extends StatefulWidget {
  final VoidCallback onDone;
  final ValueNotifier<double>? progress;
  const Intro({super.key, required this.onDone, this.progress});
  @override
  State<Intro> createState() => _IntroState();
}

class _Metrics {
  final double w, h;
  final Alignment oAlign; // titik pusat huruf "o" di dalam kotak kata
  final Offset oOff; // pusat "o" relatif pusat kata (px)
  const _Metrics(this.w, this.h, this.oAlign, this.oOff);
}

_Metrics _measure() {
  final ws = <double>[];
  double h = 0, base = 0;
  for (final ch in _word.split('')) {
    final tp = TextPainter(text: TextSpan(text: ch, style: _style), textDirection: TextDirection.ltr)
      ..layout();
    ws.add(tp.width);
    h = tp.height;
    base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  }
  final w = ws.fold<double>(0, (a, b) => a + b);
  var before = 0.0;
  for (var i = 0; i < _zoomLetter; i++) {
    before += ws[i];
  }
  final dx = before + (ws[_zoomLetter] - 1) / 2 - w / 2; // -1 = letterSpacing
  final dy = (base - _fs * 0.265) - h / 2; // pusat huruf kecil ≈ separuh tinggi-x
  return _Metrics(w, h, Alignment(dx / (w / 2), dy / (h / 2)), Offset(dx, dy));
}

class _IntroState extends State<Intro> with SingleTickerProviderStateMixin {
  static const _soundAt = kIntroZoomAt - 0.015;

  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3400));
  late final _Metrics _m = _measure();
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
    final c = _c.value;
    // Root hanya perlu tahu progres saat tahap zoom (hemat rebuild)
    if (c >= kIntroZoomAt - 0.02) widget.progress?.value = c;
    if (!_zoomSound && c >= _soundAt) {
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
    if (_c.value < _soundAt - 0.02) _c.forward(from: _soundAt - 0.04);
  }

  // ------------------------------------------------------------ bagian-bagian

  /// Muka depan: tiap huruf terbang masuk dari jauh sambil membalik.
  Widget _faceLetter(String ch, int i, double c) {
    final st = 0.03 + i * 0.045;
    final t = Interval(st, st + 0.2, curve: Curves.easeOutCubic).transform(c);
    if (t >= 1) return Text(ch, style: _style);
    return Opacity(
      opacity: t,
      child: Transform(
        alignment: Alignment.center,
        // z positif = menjauh dari kamera
        transform: Matrix4.translationValues(0, (1 - t) * 40, (1 - t) * 170) *
            Matrix4.rotationX((1 - t) * -1.3),
        child: Text(ch, style: _style),
      ),
    );
  }

  Widget _face(double c) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (var i = 0; i < _word.length; i++) _faceLetter(_word[i], i, c)],
      );

  /// Satu lapisan ketebalan = satu teks utuh (murah).
  Widget _slab(Color color) => Text(_word, style: _style.copyWith(color: color));

  /// Tahap zoom: kata datar, hanya "o" yang digambar penuh.
  Widget _zoomRow(double s, double ringAlpha) {
    final showOthers = s < 20; // sesudah itu huruf lain sudah di luar layar
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _word.length; i++)
          Text(
            _word[i],
            style: _style.copyWith(
              color: i == _zoomLetter
                  ? Colors.white.withAlpha((255 * ringAlpha).round())
                  : (showOthers ? Colors.white : Colors.transparent),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final c = _c.value;
          final zooming = c >= kIntroZoomAt;
          final zoomP = const Interval(kIntroZoomAt, 1.0).transform(c);
          final zq = Curves.easeInCubic.transform(zoomP);
          final antic = Interval(0.58, kIntroZoomAt, curve: Curves.easeInOut).transform(c);
          const maxScale = 115.0;
          // menarik napas (mengecil) lalu meluncur masuk ke "o"
          final scale = !zooming
              ? 1 - 0.08 * antic
              : 0.92 * math.exp(math.log(maxScale / 0.92) * zq);

          final tagIn = const Interval(0.36, 0.48, curve: Curves.easeOutCubic).transform(c);
          final tagOut = const Interval(0.56, 0.62).transform(c);
          final tag = tagIn * (1 - tagOut);

          // ---- 3D
          final grow = const Interval(0.46, 0.58, curve: Curves.easeOutCubic).transform(c);
          final collapse = 1 - const Interval(0.62, 0.655, curve: Curves.easeIn).transform(c);
          final depthF = grow * collapse; // 0..1 ketebalan huruf
          final sw = const Interval(0.44, 0.64).transform(c);
          final rotY = math.sin(sw * math.pi * 2) * 0.6; // goyang, lalu rata lagi
          final rotX = -0.22 * math.sin(sw * math.pi);
          final shine = const Interval(0.40, 0.60, curve: Curves.easeInOut).transform(c);
          final glow = zooming
              ? 0.0
              : const Interval(0.05, 0.5, curve: Curves.easeOut).transform(c) * (1 - antic * 0.6);

          // ---- kata
          Widget word;
          if (!zooming) {
            const layers = 8;
            word = Transform(
              alignment: Alignment.center,
              transform: persp(0.001) * Matrix4.rotationX(rotX) * Matrix4.rotationY(rotY),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (depthF > 0.02)
                    for (var k = layers; k >= 1; k--)
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.translationValues(0, 0, k * 2.6 * depthF),
                        child: _slab(Color.lerp(
                            const Color(0xFFFFB066), const Color(0xFF2B1B21), k / layers)!),
                      ),
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (r) => LinearGradient(
                      begin: Alignment(-2 + 4 * shine, 0),
                      end: Alignment(-1 + 4 * shine, 0),
                      colors: const [Colors.white, Color(0xFFFFC98F), Colors.white],
                      stops: const [0, 0.5, 1],
                    ).createShader(r),
                    child: _face(c),
                  ),
                ],
              ),
            );
          } else {
            // alpha cincin huruf: menghilang saat melewati tepi layar
            final ring = 1 - const Interval(0.75, 0.97).transform(zq);
            word = _zoomRow(scale, ring.clamp(0.0, 1.0).toDouble());
          }
          word = Transform.scale(scale: scale, alignment: _m.oAlign, child: word);

          // ---- mask: gelap di mana-mana KECUALI lubang tengah "o" (jendela ke app)
          final Widget backdrop = zooming
              ? CustomPaint(
                  painter: _HolePainter(
                    off: _m.oOff,
                    rx: _fs * 0.10 * scale, // sedikit lebih kecil dari lubang asli
                    ry: _fs * 0.14 * scale,
                  ),
                  size: Size.infinite,
                )
              : const ColoredBox(color: _bg);

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
                // pantulan cahaya di "lantai" (gradient statis, tanpa blur mahal)
                Align(
                  alignment: const Alignment(0, 0.2),
                  child: Container(
                    width: 280,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        kOrange.withAlpha((70 * glow * (0.6 + 0.4 * depthF)).round()),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
              Center(child: word),
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

/// Layar gelap dengan lubang elips di pusat "o" (tanpa saveLayer / ColorFilter).
class _HolePainter extends CustomPainter {
  final Offset off;
  final double rx, ry;
  const _HolePainter({required this.off, required this.rx, required this.ry});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2) + off;
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCenter(center: center, width: rx * 2, height: ry * 2));
    canvas.drawPath(path, Paint()..color = _bg);
  }

  @override
  bool shouldRepaint(_HolePainter o) => o.rx != rx || o.ry != ry || o.off != off;
}
