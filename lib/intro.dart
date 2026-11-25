import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'ui.dart';

class Intro extends StatefulWidget {
  final VoidCallback onDone;
  const Intro({super.key, required this.onDone});
  @override
  State<Intro> createState() => _IntroState();
}

class _IntroState extends State<Intro> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
  bool _done = false;

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(_finish);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double a, double b, [Curve k = Curves.easeOutCubic]) =>
      Interval(a, b, curve: k).transform(_c.value);

  Widget _letter(String ch, int i) {
    final s = 0.25 + i * 0.06;
    final t = Interval(s, s + 0.25, curve: Curves.easeOutCubic).transform(_c.value);
    Widget w = Text(ch,
        style: const TextStyle(
            fontSize: 46, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1));
    final sig = (1 - t) * 10;
    if (sig > 0.2) {
      w = ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: sig, sigmaY: sig), child: w);
    }
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, (1 - t) * 26), child: w),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _finish,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0D0E),
        body: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final ring = _seg(0.0, 0.4, Curves.easeInOut);
            final burst = _seg(0.4, 0.7);
            final shine = _seg(0.72, 0.95, Curves.easeInOut);
            final tag = _seg(0.78, 0.95);
            const word = 'Viemos';
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: 1 - burst,
                          child: Transform.scale(
                            scale: 1 + burst * 0.5,
                            child: CustomPaint(size: const Size(220, 220), painter: _RingPainter(ring)),
                          ),
                        ),
                        ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (r) => LinearGradient(
                            begin: Alignment(-2 + 4 * shine, 0),
                            end: Alignment(-1 + 4 * shine, 0),
                            colors: const [Colors.white, Color(0xFFFFC98F), Colors.white],
                            stops: const [0, 0.5, 1],
                          ).createShader(r),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [for (var i = 0; i < word.length; i++) _letter(word[i], i)],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Opacity(
                    opacity: tag,
                    child: Transform.translate(
                      offset: Offset(0, (1 - tag) * 10),
                      child: const Text('Catat. Pantau. Tenang.',
                          style: TextStyle(color: kMuted, letterSpacing: 2, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double t;
  _RingPainter(this.t);

  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromCircle(center: s.center(Offset.zero), radius: s.width / 2 - 4);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = kGlow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = kOrange;
    final sweep = 2 * math.pi * t;
    c.drawArc(r, -math.pi / 2, sweep, false, glow);
    c.drawArc(r, -math.pi / 2, sweep, false, line);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.t != t;
}
