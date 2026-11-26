import 'strings.dart';
import 'package:flutter/material.dart';
import 'island.dart';
import 'sfx.dart';
import 'theme.dart';

// Warna dibaca dari palet aktif (terang/gelap + warna tema), jadi BUKAN const.
// Nama lama dipertahankan supaya seluruh kode lain tetap sama.
Color get kOrange => Pal.accent; // warna tema
Color get kGlow => Pal.accent.withAlpha(0x38);
Color get kCard => Pal.card;
Color get kBorder => Pal.border;
Color get kIn => Pal.income;
Color get kOut => Pal.expense;
Color get kText => Pal.text;
Color get kMuted => Pal.muted;
Color get kBg => Pal.bg;
Color get kBg2 => Pal.bg2;
Color get kPanel => Pal.panel;
Color get kSheet => Pal.sheet;
/// Teks/ikon di atas warna tema (tombol utama, dll).
const kOnAccent = Color(0xFF0A0D0E);
TextStyle get kTitle => TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: kText);

/// Latar gradient standar semua layar.
BoxDecoration get kBgDecoration => BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [kBg, kBg, kBg2],
        stops: const [0, 0.6, 1],
      ),
    );

bool kDecimals = false;

/// Matriks perspektif untuk efek 3D (dipakai bareng rotateX/rotateY/translate z).
Matrix4 persp([double p = 0.0012]) => Matrix4.identity()..setEntry(3, 2, p);

String money(int cents, {bool? dec}) {
  final showDec = dec ?? kDecimals;
  final neg = cents < 0;
  final a = cents.abs();
  var whole = a ~/ 100;
  final frac = a % 100;
  if (!showDec && frac >= 50) whole += 1;
  final s = whole
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  final d = showDec ? ',${frac.toString().padLeft(2, '0')}' : '';
  return '${neg ? '-' : ''}Rp $s$d';
}

int? parseMoney(String s) {
  final t = s.trim().replaceAll(' ', '').replaceAll('.', '').replaceAll(',', '.');
  final d = double.tryParse(t);
  if (d == null) return null;
  return (d * 100).round();
}

String two(int n) => n.toString().padLeft(2, '0');
List<String> get _bln => ['Jan', 'Feb', 'Mar', 'Apr', tr('Mei'), 'Jun', 'Jul', tr('Agu'), 'Sep', tr('Okt'), 'Nov', tr('Des')];
String fmtDate(DateTime d) =>
    '${d.day} ${_bln[d.month - 1]} ${d.year}, ${two(d.hour)}:${two(d.minute)}';

Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(t, style: TextStyle(color: kMuted, fontSize: 13)),
    );

void toast(BuildContext c, String m) =>
    showIsland(c, title: m, icon: Icons.info_outline_rounded, color: kOrange, sound: 'info');

/// Bungkus apa saja supaya ada animasi tekan (mengecil sedikit lalu memantul)
/// + suara klik. Dipakai di semua tombol.
class Bounce extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool sound;
  const Bounce({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.95,
    this.sound = true,
  });

  @override
  State<Bounce> createState() => _BounceState();
}

class _BounceState extends State<Bounce> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.sound) Sfx.click();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 90 : 220),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Tombol standar Viemos (isi penuh atau garis tepi), sudah ada animasi tekan.
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color? color;
  final bool outlined;
  final IconData? icon;
  final double height;
  final Color? fg;
  const AppButton(
    this.text, {
    super.key,
    required this.onTap,
    this.color,
    this.outlined = false,
    this.icon,
    this.height = 52,
    this.fg,
  });

  @override
  Widget build(BuildContext context) {
    final fg = this.fg ?? (outlined ? kText : kOnAccent);
    final color = this.color ?? kOrange;
    return Bounce(
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(18),
          border: outlined ? Border.all(color: this.fg ?? kBorder, width: 1.5) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 8)],
            Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg)),
          ],
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: kBorder),
      ),
      child: Padding(padding: padding, child: child),
    );
    return onTap == null ? card : Bounce(onTap: onTap, onLongPress: onLongPress, scale: 0.97, child: card);
  }
}
