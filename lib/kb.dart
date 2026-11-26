import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'money_input.dart';
import 'sfx.dart';
import 'ui.dart';

/// Isi satu kolom yang diketik lewat keyboard Viemos (bukan keyboard HP).
/// Mode [money]: otomatis titik ribuan, koma untuk desimal (maks 2 digit).
class InputCtl extends ChangeNotifier {
  final bool money;
  final int maxLen;
  String _t;
  InputCtl({this.money = false, this.maxLen = 60, String text = ''}) : _t = text;

  String get text => _t;

  void set(String v) {
    _t = v;
    notifyListeners();
  }

  void clear() => set('');

  void type(String ch) {
    if (money) {
      final raw = _t.replaceAll('.', '');
      if (ch == ',' && raw.contains(',')) return;
      final next = raw + ch;
      final ci = next.indexOf(',');
      final ip = ci >= 0 ? next.substring(0, ci) : next;
      final fp = ci >= 0 ? next.substring(ci + 1) : '';
      if (fp.length > 2) return;
      if (ip.replaceFirst(RegExp(r'^0+'), '').length > 12) return; // batas wajar
      _t = moneyFormatRaw(next);
    } else {
      if (_t.length >= maxLen) return;
      _t += ch;
    }
    notifyListeners();
  }

  void backspace() {
    if (_t.isEmpty) return;
    if (money) {
      final raw = _t.replaceAll('.', '');
      _t = moneyFormatRaw(raw.substring(0, raw.length - 1));
    } else {
      _t = _t.substring(0, _t.length - 1);
    }
    notifyListeners();
  }
}

// =============================================================== kolom isian

/// Kolom isian yang diketik lewat [AppKeyboard]. Tidak memanggil keyboard HP.
class KbField extends StatelessWidget {
  final InputCtl ctl;
  final bool active;
  final VoidCallback onTap;
  final String hint;
  final String? prefix;
  final String? helper;
  final TextStyle style;
  final Color accent;
  final int? maxLines;

  const KbField({
    super.key,
    required this.ctl,
    required this.active,
    required this.onTap,
    this.hint = '',
    this.prefix,
    this.helper,
    this.style = const TextStyle(fontSize: 16, color: kText),
    this.accent = kOrange,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final h = (style.fontSize ?? 16) * 1.15;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Sfx.click();
        onTap();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: active ? accent : Colors.transparent, width: 1.6),
              boxShadow: active ? [BoxShadow(color: accent.withAlpha(50), blurRadius: 14)] : null,
            ),
            child: ListenableBuilder(
              listenable: ctl,
              builder: (_, __) {
                final empty = ctl.text.isEmpty;
                final cursor = active
                    ? WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: _Cursor(color: accent, height: h),
                      )
                    : const TextSpan();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (prefix != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(prefix!, style: style.copyWith(color: accent)),
                      ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            if (empty) cursor,
                            TextSpan(
                              text: empty ? hint : ctl.text,
                              style: empty ? style.copyWith(color: kMuted.withAlpha(160)) : style,
                            ),
                            if (!empty) cursor,
                          ],
                        ),
                        maxLines: maxLines,
                        overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (helper != null)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 5),
              child: Text(helper!, style: const TextStyle(color: kMuted, fontSize: 11.5)),
            ),
        ],
      ),
    );
  }
}

class _Cursor extends StatefulWidget {
  final Color color;
  final double height;
  const _Cursor({required this.color, required this.height});
  @override
  State<_Cursor> createState() => _CursorState();
}

class _CursorState extends State<_Cursor> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: CurvedAnimation(parent: _c, curve: Curves.easeInOut),
        child: Container(
          width: 2.5,
          height: widget.height,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [BoxShadow(color: widget.color.withAlpha(120), blurRadius: 6)],
          ),
        ),
      );
}

// ===================================================================== dock

/// Tempat keyboard di dalam popup: meluncur masuk saat ada kolom aktif.
class KbDock extends StatelessWidget {
  final InputCtl? active;
  final VoidCallback onDone;
  final Color accent;
  const KbDock({super.key, required this.active, required this.onDone, this.accent = kOrange});

  @override
  Widget build(BuildContext context) {
    final a = active;
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: a == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 14),
              child: AppKeyboard(key: ValueKey(a), ctl: a, accent: accent, onDone: onDone),
            ),
    );
  }
}

// ================================================================== keyboard

class AppKeyboard extends StatefulWidget {
  final InputCtl ctl;
  final VoidCallback onDone;
  final Color accent;
  const AppKeyboard({super.key, required this.ctl, required this.onDone, this.accent = kOrange});

  @override
  State<AppKeyboard> createState() => _AppKeyboardState();
}

class _AppKeyboardState extends State<AppKeyboard> with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();
  late bool _shift = widget.ctl.text.isEmpty; // huruf besar di awal kalimat
  bool _sym = false;

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  void _buzz() {
    if (Sfx.haptic) HapticFeedback.selectionClick();
  }

  void _type(String ch) {
    _buzz();
    widget.ctl.type(ch);
  }

  void _letter(String ch) {
    _buzz();
    widget.ctl.type(_shift ? ch.toUpperCase() : ch);
    if (_shift) setState(() => _shift = false);
  }

  void _back() {
    _buzz();
    widget.ctl.backspace();
    if (!widget.ctl.money && widget.ctl.text.isEmpty && !_shift) setState(() => _shift = true);
  }

  Widget _wrap(Widget child) => AnimatedBuilder(
        animation: _in,
        child: child,
        builder: (_, c) {
          final t = Curves.easeOutCubic.transform(_in.value);
          return Opacity(
            opacity: t.clamp(0.0, 1.0).toDouble(),
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: persp(0.0014) * Matrix4.rotationX((1 - t) * 0.5),
              child: c,
            ),
          );
        },
      );

  // ---------------------------------------------------------------- angka
  Widget _numPad() {
    Widget k(String s, {int flex = 1}) => KbKey(
          flex: flex,
          height: 50,
          onTap: () => _type(s),
          child: Text(s, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        );
    Widget row(List<Widget> r) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: r),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([
          k('1'),
          k('2'),
          k('3'),
          KbKey(
            height: 50,
            special: true,
            repeat: true,
            onTap: _back,
            child: const Icon(Icons.backspace_outlined, color: kMuted, size: 22),
          ),
        ]),
        row([
          k('4'),
          k('5'),
          k('6'),
          KbKey(
            height: 50,
            special: true,
            onTap: () {
              _buzz();
              for (var i = 0; i < 3; i++) {
                widget.ctl.type('0');
              }
            },
            child: const Text('000', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kMuted)),
          ),
        ]),
        row([
          k('7'),
          k('8'),
          k('9'),
          KbKey(
            height: 50,
            special: true,
            onTap: () => _type(','),
            child: const Text(',', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: kMuted)),
          ),
        ]),
        Row(
          children: [
            k('0', flex: 2),
            KbKey(
              flex: 2,
              height: 50,
              fill: widget.accent,
              onTap: widget.onDone,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_rounded, color: Colors.black, size: 22),
                  SizedBox(width: 6),
                  Text('Selesai',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- huruf
  static const _r1 = 'qwertyuiop';
  static const _r2 = 'asdfghjkl';
  static const _r3 = 'zxcvbnm';
  static const _s1 = '1234567890';
  static const _s2 = '-/:;()&@"\'';
  static const _s3 = '.,?!%+=';

  Widget _textPad() {
    Widget ch(String s, {int flex = 2}) => KbKey(
          flex: flex,
          height: 44,
          onTap: () => _sym ? _type(s) : _letter(s),
          child: Text(
            _sym || !_shift ? s : s.toUpperCase(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        );
    Widget row(List<Widget> r) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: r),
        );
    final l1 = _sym ? _s1 : _r1;
    final l2 = _sym ? _s2 : _r2;
    final l3 = _sym ? _s3 : _r3;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([for (final c in l1.split('')) ch(c)]),
        row([
          const Spacer(flex: 1),
          for (final c in l2.split('')) ch(c),
          const Spacer(flex: 1),
        ]),
        row([
          KbKey(
            flex: 3,
            height: 44,
            special: true,
            fill: (!_sym && _shift) ? widget.accent.withAlpha(60) : null,
            onTap: () {
              _buzz();
              if (!_sym) setState(() => _shift = !_shift);
            },
            child: Icon(
              _sym ? Icons.more_horiz_rounded : Icons.keyboard_capslock_rounded,
              color: (!_sym && _shift) ? widget.accent : kMuted,
              size: 22,
            ),
          ),
          for (final c in l3.split('')) ch(c),
          KbKey(
            flex: 3,
            height: 44,
            special: true,
            repeat: true,
            onTap: _back,
            child: const Icon(Icons.backspace_outlined, color: kMuted, size: 22),
          ),
        ]),
        Row(
          children: [
            KbKey(
              flex: 3,
              height: 44,
              special: true,
              onTap: () {
                _buzz();
                setState(() => _sym = !_sym);
              },
              child: Text(_sym ? 'ABC' : '?123',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kMuted)),
            ),
            KbKey(
              flex: 8,
              height: 44,
              onTap: () => _type(' '),
              child: const Text('spasi', style: TextStyle(fontSize: 13, color: kMuted)),
            ),
            KbKey(
              flex: 5,
              height: 44,
              fill: widget.accent,
              onTap: widget.onDone,
              child: const Text('Selesai',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black)),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _wrap(
      Container(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0C1213),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: kBorder),
        ),
        child: widget.ctl.money ? _numPad() : _textPad(),
      ),
    );
  }
}

/// Tombol keyboard bergaya 3D: ada "tebal" di bawah, turun & miring saat ditekan.
class KbKey extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final int flex;
  final double height;
  final bool special;
  final bool repeat;
  final Color? fill;
  const KbKey({
    super.key,
    required this.child,
    required this.onTap,
    this.flex = 1,
    this.height = 46,
    this.special = false,
    this.repeat = false,
    this.fill,
  });

  @override
  State<KbKey> createState() => _KbKeyState();
}

class _KbKeyState extends State<KbKey> {
  bool _down = false;
  Offset _tilt = Offset.zero; // -1..1 dari titik sentuh
  Timer? _rep;

  @override
  void dispose() {
    _rep?.cancel();
    super.dispose();
  }

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  void _stopRepeat() {
    _rep?.cancel();
    _rep = null;
  }

  @override
  Widget build(BuildContext context) {
    final fill = widget.fill ??
        (widget.special ? const Color(0xFF1E282A) : const Color(0xFF182022));
    final depth = _down ? 1.0 : 4.0;
    return Expanded(
      flex: widget.flex,
      child: LayoutBuilder(builder: (context, bc) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final w = bc.maxWidth, h = widget.height;
            _tilt = Offset(
              ((d.localPosition.dx / w) - 0.5) * 2,
              ((d.localPosition.dy / h) - 0.5) * 2,
            );
            _set(true);
          },
          onTapUp: (_) => _set(false),
          onTapCancel: () => _set(false),
          onTap: () {
            Sfx.click();
            widget.onTap();
          },
          onLongPressStart: widget.repeat
              ? (_) {
                  _stopRepeat();
                  _rep = Timer.periodic(const Duration(milliseconds: 65), (_) => widget.onTap());
                }
              : null,
          onLongPressEnd: widget.repeat
              ? (_) {
                  _stopRepeat();
                  _set(false);
                }
              : null,
          onLongPressCancel: widget.repeat ? _stopRepeat : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedContainer(
              duration: Duration(milliseconds: _down ? 60 : 160),
              curve: _down ? Curves.easeOut : Curves.easeOutBack,
              height: widget.height,
              transformAlignment: Alignment.center,
              transform: persp(0.0016) *
                  Matrix4.translationValues(0, _down ? 3 : 0, 0) *
                  Matrix4.rotationX(_down ? _tilt.dy * 0.22 : 0) *
                  Matrix4.rotationY(_down ? -_tilt.dx * 0.22 : 0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _down && widget.fill == null
                    ? Color.alphaBlend(kOrange.withAlpha(46), fill)
                    : fill,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _down ? kOrange.withAlpha(150) : kBorder),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF040607), offset: Offset(0, depth)),
                  if (_down) BoxShadow(color: kGlow, blurRadius: 14),
                ],
              ),
              child: widget.child,
            ),
          ),
        );
      }),
    );
  }
}
