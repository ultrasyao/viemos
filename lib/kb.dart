import 'strings.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'money_input.dart';
import 'sfx.dart';
import 'theme.dart';
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
  final TextStyle? style;
  final Color? accent;
  final int? maxLines;

  const KbField({
    super.key,
    required this.ctl,
    required this.active,
    required this.onTap,
    this.hint = '',
    this.prefix,
    this.helper,
    this.style,
    this.accent,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final accent = this.accent ?? kOrange;
    final style = this.style ?? TextStyle(fontSize: 16, color: kText);
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
              child: Text(helper!, style: TextStyle(color: kMuted, fontSize: 11.5)),
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

// ===================================================================== sheet

/// Keyboard Viemos menempel di dasar layar (menutupi bar navigasi): naik
/// dengan pegas, barisnya muncul berurutan dari bawah, dan bisa ditarik ke
/// bawah untuk menutup. Popup di atasnya otomatis naik mengikuti lewat [inset].
class Kb {
  Kb._();

  /// Tinggi keyboard yang sedang tampil dari dasar layar. 0 = tertutup.
  static final ValueNotifier<double> inset = ValueNotifier<double>(0);
  static final ValueNotifier<(InputCtl, Color)?> _active =
      ValueNotifier<(InputCtl, Color)?>(null);
  static final GlobalKey<_KbSheetState> _key = GlobalKey<_KbSheetState>();
  static OverlayEntry? _entry;
  static VoidCallback? _onClosed;

  static const double _extra = 32; // area pegangan + padding sheet
  static double rowsHeight(InputCtl c) => c.money ? 218 : 194;

  /// Tampilkan keyboard untuk [ctl]. [onClosed] dipanggil saat keyboard
  /// ditutup (tombol Selesai / tarik ke bawah / [close]).
  static void open(BuildContext context, InputCtl ctl,
      {Color? accent, VoidCallback? onClosed}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _onClosed = onClosed;
    _active.value = (ctl, accent ?? kOrange);
    final safe = MediaQuery.paddingOf(overlay.context).bottom;
    inset.value = rowsHeight(ctl) + _extra + safe;
    final e = _entry;
    if (e == null || !e.mounted) {
      _entry = OverlayEntry(builder: (_) => _KbSheet(key: _key));
      overlay.insert(_entry!);
    } else {
      _key.currentState?.show();
    }
  }

  static void close({bool notify = true}) {
    final cb = _onClosed;
    _onClosed = null;
    inset.value = 0;
    final s = _key.currentState;
    if (s != null) {
      s.hide();
    } else {
      _remove();
    }
    if (notify) cb?.call();
  }

  static void _remove() {
    final e = _entry;
    _entry = null;
    if (e != null && e.mounted) e.remove();
    _active.value = null;
  }
}

class _KbSheet extends StatefulWidget {
  const _KbSheet({super.key});
  @override
  State<_KbSheet> createState() => _KbSheetState();
}

class _KbSheetState extends State<_KbSheet> with SingleTickerProviderStateMixin {
  // pegas sedikit memantul: terasa "hidup", bukan geser kaku
  static const _spring = SpringDescription(mass: 1, stiffness: 320, damping: 27);
  late final AnimationController _c = AnimationController.unbounded(vsync: this, value: 0);
  bool _closing = false;
  double _h = 320;

  @override
  void initState() {
    super.initState();
    show();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void show([double velocity = 0]) {
    _closing = false;
    _c.animateWith(SpringSimulation(_spring, _c.value, 1.0, velocity));
  }

  Future<void> hide() async {
    if (_closing) return;
    _closing = true;
    await _c.animateTo(0, duration: const Duration(milliseconds: 230), curve: Curves.easeInCubic);
    if (mounted && _closing) Kb._remove();
  }

  void _drag(DragUpdateDetails d) {
    _c.value = (_c.value - d.delta.dy / _h).clamp(0.0, 1.0).toDouble();
  }

  void _dragEnd(DragEndDetails d) {
    final vy = d.velocity.pixelsPerSecond.dy;
    if (vy > 500 || _c.value < 0.65) {
      Kb.close();
    } else {
      show(-vy / _h);
    }
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).bottom;
    return ValueListenableBuilder<(InputCtl, Color)?>(
      valueListenable: Kb._active,
      builder: (_, a, __) {
        if (a == null) return const SizedBox.shrink();
        final ctl = a.$1;
        final accent = a.$2;
        _h = Kb.rowsHeight(ctl) + Kb._extra + safe + 24;
        return Positioned(
          left: 0,
          right: 0,
          bottom: -24, // sedikit di luar layar: pantulan pegas tidak membuka celah
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, child) =>
                Transform.translate(offset: Offset(0, (1 - _c.value) * _h), child: child),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: _drag,
              onVerticalDragEnd: _dragEnd,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  padding: EdgeInsets.fromLTRB(10, 8, 10, 6 + safe + 24),
                  decoration: BoxDecoration(
                    color: kSheet,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border(top: BorderSide(color: accent.withAlpha(120), width: 1.2)),
                    boxShadow: [
                      BoxShadow(
                          color: accent.withAlpha(46), blurRadius: 30, offset: const Offset(0, -6)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration:
                            BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: AppKeyboard(
                          key: ValueKey(ctl),
                          ctl: ctl,
                          accent: accent,
                          anim: _c,
                          onDone: () => Kb.close(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ================================================================== keyboard

class AppKeyboard extends StatefulWidget {
  final InputCtl ctl;
  final VoidCallback onDone;
  final Color? accent;
  final Animation<double> anim; // 0..1 progres naiknya sheet (untuk stagger baris)
  const AppKeyboard({
    super.key,
    required this.ctl,
    required this.onDone,
    required this.anim,
    this.accent,
  });

  @override
  State<AppKeyboard> createState() => _AppKeyboardState();
}

class _AppKeyboardState extends State<AppKeyboard> {
  late bool _shift = widget.ctl.text.isEmpty; // huruf besar di awal kalimat
  bool _sym = false;

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

  /// Baris naik + memudar berurutan; baris paling bawah duluan ([fromBottom] = 0).
  Widget _rowIn(int fromBottom, Widget child) => AnimatedBuilder(
        animation: widget.anim,
        child: child,
        builder: (_, c) {
          final t = Curves.easeOutCubic
              .transform(((widget.anim.value - 0.06 - 0.075 * fromBottom) / 0.5).clamp(0.0, 1.0));
          return Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, (1 - t) * 22), child: c),
          );
        },
      );

  Widget _row(int fromBottom, List<Widget> r, {bool last = false}) => _rowIn(
        fromBottom,
        Padding(
          padding: EdgeInsets.only(bottom: last ? 0 : 6),
          child: Row(children: r),
        ),
      );

  // ---------------------------------------------------------------- angka
  Widget _numPad() {
    Widget k(String s, {int flex = 1}) => KbKey(
          flex: flex,
          height: 50,
          onTap: () => _type(s),
          child: Text(s, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _row(3, [
          k('1'),
          k('2'),
          k('3'),
          KbKey(
            height: 50,
            special: true,
            repeat: true,
            onTap: _back,
            child: Icon(Icons.backspace_outlined, color: kMuted, size: 22),
          ),
        ]),
        _row(2, [
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
            child: Text('000',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kMuted)),
          ),
        ]),
        _row(1, [
          k('7'),
          k('8'),
          k('9'),
          KbKey(
            height: 50,
            special: true,
            onTap: () => _type(','),
            child: Text(',',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: kMuted)),
          ),
        ]),
        _row(0, [
          k('0', flex: 2),
          KbKey(
            flex: 2,
            height: 50,
            fill: (widget.accent ?? kOrange),
            onTap: widget.onDone,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_rounded, color: kOnAccent, size: 22),
                SizedBox(width: 6),
                Text(tr('Selesai'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kOnAccent)),
              ],
            ),
          ),
        ], last: true),
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
    final l1 = _sym ? _s1 : _r1;
    final l2 = _sym ? _s2 : _r2;
    final l3 = _sym ? _s3 : _r3;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _row(3, [for (final c in l1.split('')) ch(c)]),
        _row(2, [
          const Spacer(flex: 1),
          for (final c in l2.split('')) ch(c),
          const Spacer(flex: 1),
        ]),
        _row(1, [
          KbKey(
            flex: 3,
            height: 44,
            special: true,
            fill: (!_sym && _shift) ? (widget.accent ?? kOrange).withAlpha(60) : null,
            onTap: () {
              _buzz();
              if (!_sym) setState(() => _shift = !_shift);
            },
            child: Icon(
              _sym ? Icons.more_horiz_rounded : Icons.keyboard_capslock_rounded,
              color: (!_sym && _shift) ? (widget.accent ?? kOrange) : kMuted,
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
            child: Icon(Icons.backspace_outlined, color: kMuted, size: 22),
          ),
        ]),
        _row(0, [
          KbKey(
            flex: 3,
            height: 44,
            special: true,
            onTap: () {
              _buzz();
              setState(() => _sym = !_sym);
            },
            child: Text(_sym ? 'ABC' : '?123',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kMuted)),
          ),
          KbKey(
            flex: 8,
            height: 44,
            onTap: () => _type(' '),
            child: Text(tr('spasi'), style: TextStyle(fontSize: 13, color: kMuted)),
          ),
          KbKey(
            flex: 5,
            height: 44,
            fill: (widget.accent ?? kOrange),
            onTap: widget.onDone,
            child: Text(tr('Selesai'),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kOnAccent)),
          ),
        ], last: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => widget.ctl.money ? _numPad() : _textPad();
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
        (widget.special ? Pal.keySpecial : Pal.key);
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
                  BoxShadow(color: Pal.keyShadow, offset: Offset(0, depth)),
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
