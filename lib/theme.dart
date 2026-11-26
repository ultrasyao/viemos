import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// ====================================================================== warna

/// Satu pilihan warna tema: nuansa untuk mode gelap & terang
/// (versi terang dibuat lebih pekat supaya tetap kontras di latar putih).
class AccentOpt {
  final String id;
  final String name; // kunci terjemahan
  final Color dark;
  final Color light;
  const AccentOpt(this.id, this.name, this.dark, this.light);
}

const kAccents = <AccentOpt>[
  AccentOpt('orange', 'Oranye', Color(0xFFFFB066), Color(0xFFE8791A)),
  AccentOpt('green', 'Hijau', Color(0xFF7BE0A8), Color(0xFF1E9E62)),
  AccentOpt('blue', 'Biru', Color(0xFF7DB8FF), Color(0xFF2B7BE4)),
  AccentOpt('purple', 'Ungu', Color(0xFFC3A0FF), Color(0xFF7B4FD6)),
  AccentOpt('pink', 'Pink', Color(0xFFFF9CC7), Color(0xFFD6407F)),
  AccentOpt('teal', 'Tosca', Color(0xFF5FD9D0), Color(0xFF0F9D95)),
];

/// Pengaturan tampilan yang sedang aktif. Semua warna di app dibaca dari sini
/// lewat getter di ui.dart (kOrange, kCard, kText, ...).
class Pal {
  Pal._();

  /// 0 = ikuti sistem, 1 = terang, 2 = gelap
  static int mode = 2;
  static int accentIdx = 0;
  static bool dark = true;

  static void refresh() {
    final sys = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    dark = mode == 2 || (mode == 0 && sys == Brightness.dark);
  }

  static AccentOpt get opt => kAccents[accentIdx.clamp(0, kAccents.length - 1).toInt()];
  static Color get accent => dark ? opt.dark : opt.light;

  static Color _p(Color d, Color l) => dark ? d : l;

  static Color get bg => _p(const Color(0xFF0A0D0E), const Color(0xFFF3F6F6));
  // ujung gradient latar: sedikit tersepuh warna aksen
  static Color get bg2 =>
      Color.alphaBlend(accent.withAlpha(dark ? 34 : 38), bg);
  static Color get card => _p(const Color(0xFF151C1D), const Color(0xFFFFFFFF));
  static Color get border => _p(const Color(0xFF2A3335), const Color(0xFFDCE3E4));
  static Color get text => _p(const Color(0xFFE6EEEE), const Color(0xFF0F1819));
  static Color get muted => _p(const Color(0xFF8A9A9C), const Color(0xFF5E6E70));
  static Color get income => _p(const Color(0xFF7BE0A8), const Color(0xFF1E9E62));
  static Color get expense => _p(const Color(0xFFFF8F85), const Color(0xFFD4443A));
  static Color get panel => _p(const Color(0xFF111718), const Color(0xFFFFFFFF));
  static Color get sheet => _p(const Color(0xFF0C1213), const Color(0xFFEEF2F2));
  static Color get key => _p(const Color(0xFF182022), const Color(0xFFFFFFFF));
  static Color get keySpecial => _p(const Color(0xFF1E282A), const Color(0xFFDDE4E5));
  static Color get keyShadow => _p(const Color(0xFF040607), const Color(0xFFB8C2C4));
  static Color get padTop => _p(const Color(0xFF1D2729), const Color(0xFFFFFFFF));
  static Color get padBottom => _p(const Color(0xFF131A1B), const Color(0xFFE9EEEF));
  static Color get padShadow => _p(const Color(0xFF050708), const Color(0xFFC3CCCE));
  static Color get fab => _p(const Color(0xFF171E1F), const Color(0xFFFFFFFF));
  static Color get scrim => dark ? const Color(0xA5000000) : const Color(0x66101818);
  static Color get shadow => dark ? const Color(0x99000000) : const Color(0x33000000);
}

// ====================================================================== bahasa

/// Bahasa aplikasi. Sumber teks = bahasa Indonesia; [tr] menerjemahkan ke
/// Inggris lewat kamus di strings.dart, dan kembali ke teks asli kalau
/// tidak ada terjemahannya.
class Lang {
  Lang._();
  static String code = 'id'; // 'id' | 'en'
  static bool get en => code == 'en';
}

// ============================================================ rebuild semua UI

/// Tandai semua elemen kotor supaya digambar ulang dengan warna/bahasa baru
/// (state, scroll, dan route tetap utuh).
void rebuildAllElements() {
  void visit(Element e) {
    e.markNeedsBuild();
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
}

// =============================================================== animasi ganti

/// Bungkus app. [ThemeFx.change] memotret layar sebelum perubahan, menerapkan
/// perubahan di bawahnya, lalu memperlihatkannya lewat animasi:
///  - lingkaran membesar dari titik ketukan (ganti terang/gelap),
///  - atau memudar halus (ganti warna / bahasa).
class ThemeFx extends StatefulWidget {
  final Widget child;
  const ThemeFx({super.key, required this.child});

  static final GlobalKey<_ThemeFxState> key = GlobalKey<_ThemeFxState>();

  static Future<void> change(
    VoidCallback apply, {
    Offset? origin,
    bool circle = false,
  }) async {
    final s = key.currentState;
    if (s == null) {
      apply();
      rebuildAllElements();
      return;
    }
    await s._run(apply, origin, circle);
  }

  @override
  State<ThemeFx> createState() => _ThemeFxState();
}

class _ThemeFxState extends State<ThemeFx> with SingleTickerProviderStateMixin {
  final _boundary = GlobalKey();
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 760));
  ui.Image? _old;
  Offset _origin = Offset.zero;
  bool _circle = false;
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    _old?.dispose();
    super.dispose();
  }

  Future<void> _run(VoidCallback apply, Offset? origin, bool circle) async {
    if (_busy) {
      apply();
      rebuildAllElements();
      return;
    }
    _busy = true;
    ui.Image? img;
    try {
      final ro = _boundary.currentContext?.findRenderObject();
      if (ro is RenderRepaintBoundary) {
        img = await ro.toImage(pixelRatio: MediaQuery.of(context).devicePixelRatio);
      }
    } catch (_) {
      img = null;
    }
    if (img == null || !mounted) {
      apply();
      rebuildAllElements();
      _busy = false;
      return;
    }
    final size = MediaQuery.sizeOf(context);
    setState(() {
      _old = img;
      _origin = origin ?? Offset(size.width / 2, size.height / 2);
      _circle = circle;
    });
    apply();
    rebuildAllElements();
    await _c.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _old?.dispose();
      _old = null;
    });
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    final old = _old;
    return Stack(
      fit: StackFit.expand,
      textDirection: TextDirection.ltr,
      children: [
        RepaintBoundary(key: _boundary, child: widget.child),
        if (old != null)
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => CustomPaint(
                painter: _FxPainter(
                  image: old,
                  t: _c.value,
                  origin: _origin,
                  circle: _circle,
                  ring: Pal.accent,
                ),
                size: Size.infinite,
              ),
            ),
          ),
      ],
    );
  }
}

class _FxPainter extends CustomPainter {
  final ui.Image image;
  final double t;
  final Offset origin;
  final bool circle;
  final Color ring;
  const _FxPainter({
    required this.image,
    required this.t,
    required this.origin,
    required this.circle,
    required this.ring,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Offset.zero & size;
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final paint = Paint()..filterQuality = FilterQuality.low;
    if (!circle) {
      // pudar: tampilan lama menghilang pelan
      final a = 1 - Curves.easeInOut.transform(t);
      paint.color = Color.fromRGBO(255, 255, 255, a);
      canvas.drawImageRect(image, src, dst, paint);
      return;
    }
    // tampilan lama dipotong lubang lingkaran yang membesar dari titik ketukan
    final far = [
      (origin - dst.topLeft).distance,
      (origin - dst.topRight).distance,
      (origin - dst.bottomLeft).distance,
      (origin - dst.bottomRight).distance,
    ].reduce(math.max);
    final e = Curves.easeInOutCubic.transform(t);
    final r = far * e;
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(dst)
      ..addOval(Rect.fromCircle(center: origin, radius: r));
    canvas.save();
    canvas.clipPath(path);
    canvas.drawImageRect(image, src, dst, paint);
    canvas.restore();
    // cincin cahaya di tepi lingkaran
    final fade = (1 - t).clamp(0.0, 1.0).toDouble();
    canvas.drawCircle(
      origin,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 + 10 * fade
        ..color = ring.withAlpha((150 * fade).round())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 10 * fade),
    );
  }

  @override
  bool shouldRepaint(_FxPainter o) => o.t != t || o.image != image || o.origin != origin;
}
