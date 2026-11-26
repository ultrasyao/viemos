import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'prefs.dart';
import 'sfx.dart';
import 'ui.dart';

const kPinLen = 6;

class Lock {
  Lock._();
  static final ValueNotifier<bool> locked = ValueNotifier<bool>(false);
  static bool _skip = false;
  static int _fails = 0;
  static DateTime? _until;

  /// Panggil sebelum membuka picker file / share sheet supaya app tidak
  /// ikut terkunci saat kembali dari sana.
  static void skipNext() => _skip = true;

  static void lockNow() {
    if (Prefs.hasPin) locked.value = true;
  }

  /// null = PIN benar. Selain itu = pesan error.
  static Future<String?> check(String pin) async {
    final u = _until;
    if (u != null && DateTime.now().isBefore(u)) {
      return 'Coba lagi dalam ${u.difference(DateTime.now()).inSeconds + 1} detik';
    }
    if (Prefs.checkPin(pin)) {
      _fails = 0;
      _until = null;
      return null;
    }
    _fails++;
    if (_fails >= 5) {
      final secs = 30 * (1 << math.min(_fails - 5, 4));
      _until = DateTime.now().add(Duration(seconds: secs));
      return 'Terlalu banyak salah. Tunggu $secs detik';
    }
    return 'PIN salah (${5 - _fails} percobaan lagi)';
  }
}

/// Bungkus seluruh app: menampilkan layar PIN di atas segalanya saat terkunci.
class AppLock extends StatefulWidget {
  final Widget child;
  const AppLock({super.key, required this.child});
  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  DateTime? _bg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) {
      _bg = DateTime.now();
    } else if (s == AppLifecycleState.resumed) {
      final b = _bg;
      _bg = null;
      if (Lock._skip) {
        Lock._skip = false;
        return;
      }
      if (b != null &&
          Prefs.hasPin &&
          !Lock.locked.value &&
          DateTime.now().difference(b).inSeconds >= Prefs.lockAfter) {
        Navigator.of(context).popUntil((r) => r.isFirst);
        Lock.locked.value = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        ValueListenableBuilder<bool>(
          valueListenable: Lock.locked,
          builder: (_, v, __) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 480),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (cur, prev) => Stack(
              fit: StackFit.expand,
              children: [...prev, if (cur != null) cur],
            ),
            // buka kunci: layar PIN memudar sambil sedikit membesar ke arah kita
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(
                scale: Tween<double>(begin: 1.1, end: 1.0).animate(a),
                child: child,
              ),
            ),
            child: v
                ? const _LockScreen(key: ValueKey('lock'))
                : const SizedBox.shrink(key: ValueKey('open')),
          ),
        ),
      ],
    );
  }
}

const _bgGradient = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A0D0E), Color(0xFF0A0D0E), Color(0xFF2B1B21)],
    stops: [0, 0.55, 1],
  ),
);

/// Latar standar layar PIN (gradient sama dengan app).
class _PinBg extends StatelessWidget {
  final Widget child;
  const _PinBg({required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: _bgGradient,
        child: SafeArea(child: child),
      );
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Material(
          color: const Color(0xFF0A0D0E),
          child: _PinBg(
            child: Column(
              children: [
                const SizedBox(height: 30),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.6, end: 1.0),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutBack,
                  builder: (_, t, child) => Transform.scale(scale: t, child: child),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kOrange.withAlpha(24),
                      border: Border.all(color: kOrange, width: 2.5),
                      boxShadow: const [BoxShadow(color: kGlow, blurRadius: 30, spreadRadius: 3)],
                    ),
                    child: const Icon(Icons.lock_rounded, color: kOrange, size: 30),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Viemos',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 2),
                const Text('Aplikasi terkunci', style: TextStyle(color: kMuted, fontSize: 13)),
                Expanded(
                  child: PinPad(
                    title: 'Masukkan PIN',
                    onSubmit: (p) async {
                      final e = await Lock.check(p);
                      if (e == null) {
                        Sfx.play('open');
                        Lock.locked.value = false;
                      }
                      return e;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Keypad PIN. [onSubmit] return null kalau diterima, atau pesan error.
class PinPad extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Future<String?> Function(String pin) onSubmit;
  final VoidCallback? onCancel;
  final bool clearOnSuccess;
  const PinPad({
    super.key,
    required this.title,
    required this.onSubmit,
    this.subtitle,
    this.onCancel,
    this.clearOnSuccess = false,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String pin = '';
  String? err;
  bool busy = false;
  int status = 0; // 0 biasa, 1 salah, 2 benar
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _tap(String d) {
    if (busy || pin.length >= kPinLen) return;
    Sfx.click();
    HapticFeedback.selectionClick();
    setState(() {
      pin += d;
      err = null;
    });
    if (pin.length == kPinLen) _submit();
  }

  void _del() {
    if (busy || pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => pin = pin.substring(0, pin.length - 1));
  }

  void _clear() {
    if (busy || pin.isEmpty) return;
    setState(() => pin = '');
  }

  Future<void> _submit() async {
    busy = true;
    final e = await widget.onSubmit(pin);
    if (!mounted) return;
    if (e != null) {
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
      setState(() {
        err = e;
        status = 1;
      });
      await Future.delayed(const Duration(milliseconds: 460));
      if (!mounted) return;
      setState(() {
        pin = '';
        status = 0;
        busy = false;
      });
    } else {
      HapticFeedback.lightImpact();
      setState(() => status = 2);
      if (widget.clearOnSuccess) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        setState(() {
          pin = '';
          status = 0;
          busy = false;
        });
      } else {
        busy = false;
      }
    }
  }

  Widget _digit(String d) => _PadKey(
        onTap: () => _tap(d),
        child: Text(d, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
      );

  Widget _row(int k, List<Widget> keys) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: Duration(milliseconds: 380 + 90 * k),
        curve: Curves.easeOutCubic,
        builder: (_, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * 26), child: child),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: keys),
      );

  @override
  Widget build(BuildContext context) {
    final sub = err ?? widget.subtitle;
    final dotColor = status == 1 ? kOut : (status == 2 ? kIn : kOrange);
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SizedBox(
              height: 38,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(sub ?? '',
                      key: ValueKey(sub),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: err != null ? kOut : kMuted)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: _shake,
              builder: (_, child) => Transform.translate(
                offset: Offset(math.sin(_shake.value * math.pi * 6) * 12 * (1 - _shake.value), 0),
                child: child,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < kPinLen; i++)
                    AnimatedScale(
                      scale: i < pin.length ? 1.0 : 0.82,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < pin.length ? dotColor : Colors.transparent,
                          border: Border.all(color: i < pin.length ? dotColor : kBorder, width: 2),
                          boxShadow: i < pin.length
                              ? [BoxShadow(color: dotColor.withAlpha(90), blurRadius: 10)]
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            _row(0, [_digit('1'), _digit('2'), _digit('3')]),
            _row(1, [_digit('4'), _digit('5'), _digit('6')]),
            _row(2, [_digit('7'), _digit('8'), _digit('9')]),
            _row(3, [
              widget.onCancel == null
                  ? const SizedBox(width: 92, height: 88)
                  : _PadKey(
                      ghost: true,
                      onTap: widget.onCancel,
                      child: const Icon(Icons.close_rounded, color: kMuted, size: 28),
                    ),
              _digit('0'),
              _PadKey(
                ghost: true,
                onTap: _del,
                onLong: _clear,
                child: const Icon(Icons.backspace_outlined, color: kMuted, size: 25),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Tombol keypad bulat: menyala oranye & memantul saat ditekan.
class _PadKey extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLong;
  final bool ghost;
  const _PadKey({required this.child, this.onTap, this.onLong, this.ghost = false});
  @override
  State<_PadKey> createState() => _PadKeyState();
}

class _PadKeyState extends State<_PadKey> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.ghost;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      onLongPress: widget.onLong,
      child: SizedBox(
        width: 92,
        height: 88,
        child: Center(
          child: AnimatedScale(
            scale: _down ? 0.86 : 1,
            duration: Duration(milliseconds: _down ? 80 : 240),
            curve: _down ? Curves.easeOut : Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 74,
              height: 74,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: g ? Colors.transparent : (_down ? kOrange.withAlpha(64) : kCard.withAlpha(210)),
                border: g ? null : Border.all(color: _down ? kOrange : kBorder, width: 1.5),
                boxShadow: (_down && !g) ? const [BoxShadow(color: kGlow, blurRadius: 20)] : null,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

Route<T> _pinRoute<T>(Widget page) {
  Sfx.play('open');
  return PageRouteBuilder<T>(
    opaque: true,
    fullscreenDialog: true,
    transitionDuration: const Duration(milliseconds: 460),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, a, __, child) {
      final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Minta PIN lalu return true kalau benar.
Future<bool> verifyPin(BuildContext context, {String title = 'Masukkan PIN'}) async {
  final r = await Navigator.of(context).push<bool>(_pinRoute<bool>(
    Builder(
      builder: (c) => Scaffold(
        body: _PinBg(
          child: PinPad(
            title: title,
            onCancel: () => Navigator.pop(c, false),
            onSubmit: (p) async {
              final e = await Lock.check(p);
              if (e == null && c.mounted) Navigator.pop(c, true);
              return e;
            },
          ),
        ),
      ),
    ),
  ));
  return r == true;
}

/// Buat PIN baru (diminta dua kali). true = tersimpan.
Future<bool> setupPin(BuildContext context) async {
  final r = await Navigator.of(context).push<bool>(_pinRoute<bool>(const _PinSetup()));
  return r == true;
}

class _PinSetup extends StatefulWidget {
  const _PinSetup();
  @override
  State<_PinSetup> createState() => _PinSetupState();
}

class _PinSetupState extends State<_PinSetup> {
  String? first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _PinBg(
        child: PinPad(
          title: first == null ? 'Buat PIN baru' : 'Ulangi PIN',
          subtitle: 'PIN $kPinLen digit. Jangan sampai lupa — tidak ada fitur reset.',
          clearOnSuccess: true,
          onCancel: () => Navigator.pop(context, false),
          onSubmit: (p) async {
            if (first == null) {
              setState(() => first = p);
              return null;
            }
            if (p != first) {
              setState(() => first = null);
              return 'PIN tidak sama, ulangi dari awal';
            }
            await Prefs.setPin(p);
            if (mounted) Navigator.pop(context, true);
            return null;
          },
        ),
      ),
    );
  }
}
