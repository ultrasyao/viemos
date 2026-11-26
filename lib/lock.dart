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

  /// Panggil sebelum membuka picker file / share sheet supaya app tidak
  /// ikut terkunci saat kembali dari sana.
  static void skipNext() => _skip = true;

  static void lockNow() {
    if (Prefs.hasPin) locked.value = true;
  }

  /// null = PIN benar. Selain itu = pesan error.
  /// Hitungan salah & waktu tunggu disimpan permanen (tidak hilang walau
  /// aplikasi ditutup paksa).
  static Future<String?> check(String pin) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final until = Prefs.pinLockedUntil;
    if (until > now) {
      return 'Coba lagi dalam ${((until - now) / 1000).ceil()} detik';
    }
    if (await Prefs.checkPin(pin)) {
      await Prefs.setPinFails(0);
      await Prefs.setPinLockedUntil(0);
      return null;
    }
    final f = Prefs.pinFails + 1;
    await Prefs.setPinFails(f);
    if (f >= 5) {
      final secs = 30 * (1 << math.min(f - 5, 6));
      await Prefs.setPinLockedUntil(now + secs * 1000);
      return 'Terlalu banyak salah. Tunggu $secs detik';
    }
    return 'PIN salah (${5 - f} percobaan lagi)';
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
            duration: const Duration(milliseconds: 620),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (cur, prev) => Stack(
              fit: StackFit.expand,
              children: [...prev, if (cur != null) cur],
            ),
            // buka kunci: layar PIN miring ke belakang sambil membesar ke arah
            // kita dan memudar, aplikasi muncul dari baliknya
            transitionBuilder: (child, a) => AnimatedBuilder(
              animation: a,
              child: child,
              builder: (_, c) {
                final t = a.value.clamp(0.0, 1.0).toDouble();
                final s = 1 + (1 - t) * 0.28;
                return Opacity(
                  opacity: Curves.easeOut.transform(t),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: persp(0.001) *
                        Matrix4.rotationX((1 - t) * -0.32) *
                        Matrix4.diagonal3Values(s, s, 1.0),
                    child: c,
                  ),
                );
              },
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

// ============================================================ koin kunci 3D

/// Koin 3D berisi ikon gembok: bergoyang pelan (ada "tebal" di sisinya),
/// berputar & jadi gembok terbuka hijau saat PIN benar, merah saat salah.
class _LockCoin extends StatefulWidget {
  final ValueNotifier<int> status; // 0 biasa, 1 salah, 2 benar
  const _LockCoin({required this.status});
  @override
  State<_LockCoin> createState() => _LockCoinState();
}

class _LockCoinState extends State<_LockCoin> with TickerProviderStateMixin {
  late final AnimationController _idle =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 5200))..repeat();
  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  int _last = 0;

  @override
  void initState() {
    super.initState();
    widget.status.addListener(_onStatus);
  }

  void _onStatus() {
    final s = widget.status.value;
    if (s == 2 && _last != 2) _spin.forward(from: 0);
    _last = s;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.status.removeListener(_onStatus);
    _idle.dispose();
    _enter.dispose();
    _spin.dispose();
    super.dispose();
  }

  Widget _disc(double size, Color fill, Color edge, {List<BoxShadow>? glow}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: Border.all(color: edge, width: 2.5),
          boxShadow: glow,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final st = widget.status.value;
    final base = st == 1 ? kOut : (st == 2 ? kIn : kOrange);
    const size = 76.0;
    return AnimatedBuilder(
      animation: Listenable.merge([_idle, _enter, _spin]),
      builder: (_, __) {
        final e = Curves.easeOutBack.transform(_enter.value.clamp(0.0, 1.0).toDouble());
        final sway = math.sin(_idle.value * math.pi * 2) * 0.5;
        // satu putaran penuh saat berhasil
        final spin = Curves.easeInOutCubic.transform(_spin.value) * math.pi * 2;
        final rotY = (1 - e) * 1.6 + sway + spin;
        final tilt = math.cos(_idle.value * math.pi * 2) * 0.08;
        const layers = 9;
        final edgeColor = Color.lerp(base, Colors.black, 0.45)!;
        final sc = 0.6 + 0.4 * e;
        return Transform(
          alignment: Alignment.center,
          transform: persp(0.0016) *
              Matrix4.rotationX(tilt) *
              Matrix4.rotationY(rotY) *
              Matrix4.diagonal3Values(sc, sc, 1.0),
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // sisi koin: lapisan yang makin jauh ke belakang (z positif = menjauh)
                for (var i = layers; i >= 1; i--)
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.translationValues(0, 0, i * 1.7),
                    child: _disc(
                      size,
                      Color.lerp(edgeColor, Colors.black, i / (layers * 1.6))!,
                      Color.lerp(edgeColor, Colors.black, i / (layers * 1.3))!,
                    ),
                  ),
                // muka koin
                _disc(
                  size,
                  const Color(0xFF151C1D),
                  base,
                  glow: [BoxShadow(color: base.withAlpha(80), blurRadius: 28, spreadRadius: 2)],
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder: (c, a) =>
                      ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
                  child: Icon(
                    st == 2
                        ? Icons.lock_open_rounded
                        : (st == 1 ? Icons.lock_outline_rounded : Icons.lock_rounded),
                    key: ValueKey(st),
                    color: base,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LockScreen extends StatefulWidget {
  const _LockScreen({super.key});
  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  final ValueNotifier<int> _status = ValueNotifier<int>(0);

  @override
  void dispose() {
    _status.dispose();
    super.dispose();
  }

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
                const SizedBox(height: 26),
                _LockCoin(status: _status),
                const SizedBox(height: 16),
                const Text('Viemos',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 2),
                const Text('Aplikasi terkunci', style: TextStyle(color: kMuted, fontSize: 13)),
                Expanded(
                  child: PinPad(
                    title: 'Masukkan PIN',
                    onStatus: (s) => _status.value = s,
                    onSubmit: (p) async {
                      final e = await Lock.check(p);
                      if (e == null) Sfx.play('open');
                      return e;
                    },
                    // dipanggil setelah animasi sukses selesai
                    onSuccess: () => Lock.locked.value = false,
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

// ================================================================== keypad

/// Keypad PIN. [onSubmit] return null kalau diterima, atau pesan error.
/// [onSuccess] dipanggil SETELAH animasi sukses selesai.
class PinPad extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Future<String?> Function(String pin) onSubmit;
  final VoidCallback? onSuccess;
  final ValueChanged<int>? onStatus;
  final VoidCallback? onCancel;
  final bool clearOnSuccess;
  const PinPad({
    super.key,
    required this.title,
    required this.onSubmit,
    this.subtitle,
    this.onSuccess,
    this.onStatus,
    this.onCancel,
    this.clearOnSuccess = false,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with TickerProviderStateMixin {
  String pin = '';
  String? err;
  bool busy = false;
  int status = 0; // 0 biasa, 1 salah, 2 benar
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 460));
  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
  late final AnimationController _wave =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

  @override
  void dispose() {
    _shake.dispose();
    _enter.dispose();
    _wave.dispose();
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
      widget.onStatus?.call(1);
      setState(() {
        err = e;
        status = 1;
      });
      await Future.delayed(const Duration(milliseconds: 520));
      if (!mounted) return;
      setState(() {
        pin = '';
        status = 0;
        busy = false;
      });
      widget.onStatus?.call(0);
    } else {
      HapticFeedback.lightImpact();
      widget.onStatus?.call(2);
      setState(() => status = 2);
      _wave.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 560));
      if (!mounted) return;
      widget.onSuccess?.call();
      if (!mounted) return;
      if (widget.clearOnSuccess) {
        _wave.value = 0;
        setState(() {
          pin = '';
          status = 0;
          busy = false;
        });
        widget.onStatus?.call(0);
      } else if (widget.onSuccess == null) {
        busy = false;
      }
    }
  }

  /// Tombol keypad masuk dengan membalik 3D, berurutan menyerong dari kiri atas.
  Widget _enterKey(int idx, Widget key) => AnimatedBuilder(
        animation: _enter,
        child: key,
        builder: (_, c) {
          final s = 0.04 + idx * 0.055;
          final t = Interval(s, math.min(1.0, s + 0.42), curve: Curves.easeOutBack)
              .transform(_enter.value);
          return Opacity(
            opacity: t.clamp(0.0, 1.0).toDouble(),
            child: Transform(
              alignment: Alignment.center,
              transform: persp(0.0016) *
                  Matrix4.translationValues(0, (1 - t) * 30, (1 - t) * 90) *
                  Matrix4.rotationX((1 - t) * 1.25),
              child: c,
            ),
          );
        },
      );

  Widget _digit(String d, int idx) => _enterKey(
        idx,
        _PadKey(
          onTap: () => _tap(d),
          child: Text(d, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _dot(int i) {
    final filled = i < pin.length;
    final dotColor = status == 1 ? kOut : (status == 2 ? kIn : kOrange);
    // gelombang sukses: titik melompat berurutan
    final p = Interval(i / (kPinLen + 2), (i + 3) / (kPinLen + 2)).transform(_wave.value);
    final bump = status == 2 ? math.sin(p * math.pi) : 0.0;
    return Transform.translate(
      offset: Offset(0, -9 * bump),
      child: Transform.scale(
        scale: 1 + 0.25 * bump,
        child: AnimatedScale(
          scale: filled ? 1.0 : 0.8,
          duration: const Duration(milliseconds: 420),
          curve: Curves.elasticOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // terisi: tampak seperti bola bercahaya (gradient radial 3D)
              gradient: filled
                  ? RadialGradient(
                      center: const Alignment(-0.35, -0.4),
                      radius: 0.95,
                      colors: [
                        Color.lerp(dotColor, Colors.white, 0.55)!,
                        dotColor,
                        Color.lerp(dotColor, Colors.black, 0.35)!,
                      ],
                      stops: const [0, 0.5, 1],
                    )
                  : null,
              border: Border.all(color: filled ? dotColor : kBorder, width: 2),
              boxShadow: filled
                  ? [BoxShadow(color: dotColor.withAlpha(110), blurRadius: 12, spreadRadius: 1)]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = err ?? widget.subtitle;
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
              animation: Listenable.merge([_shake, _wave]),
              builder: (_, __) => Transform.translate(
                offset: Offset(math.sin(_shake.value * math.pi * 6) * 12 * (1 - _shake.value), 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [for (var i = 0; i < kPinLen; i++) _dot(i)],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _digit('1', 0),
              _digit('2', 1),
              _digit('3', 2),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _digit('4', 1),
              _digit('5', 2),
              _digit('6', 3),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _digit('7', 2),
              _digit('8', 3),
              _digit('9', 4),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _enterKey(
                3,
                widget.onCancel == null
                    ? const SizedBox(width: 92, height: 88)
                    : _PadKey(
                        ghost: true,
                        onTap: widget.onCancel,
                        child: const Icon(Icons.close_rounded, color: kMuted, size: 28),
                      ),
              ),
              _digit('0', 4),
              _enterKey(
                5,
                _PadKey(
                  ghost: true,
                  onTap: _del,
                  onLong: _clear,
                  child: const Icon(Icons.backspace_outlined, color: kMuted, size: 25),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Tombol keypad bulat bergaya 3D: ada "tebal" di bawah, tenggelam & miring ke
/// arah titik sentuh saat ditekan, lalu menyala oranye.
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
  Offset _tilt = Offset.zero;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.ghost;
    const d = 74.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (t) {
        _tilt = Offset(
          ((t.localPosition.dx / 92) - 0.5) * 2,
          ((t.localPosition.dy / 88) - 0.5) * 2,
        );
        _set(true);
      },
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      onLongPress: widget.onLong,
      child: SizedBox(
        width: 92,
        height: 88,
        child: Center(
          child: AnimatedContainer(
            duration: Duration(milliseconds: _down ? 70 : 260),
            curve: _down ? Curves.easeOut : Curves.easeOutBack,
            width: d,
            height: d,
            alignment: Alignment.center,
            transformAlignment: Alignment.center,
            transform: persp(0.0018) *
                Matrix4.translationValues(0, (_down && !g) ? 4 : 0, 0) *
                Matrix4.rotationX(_down ? _tilt.dy * 0.38 : 0) *
                Matrix4.rotationY(_down ? -_tilt.dx * 0.38 : 0) *
                Matrix4.diagonal3Values(_down ? 0.93 : 1.0, _down ? 0.93 : 1.0, 1.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: g
                  ? null
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: _down
                          ? [kOrange.withAlpha(90), kOrange.withAlpha(40)]
                          : [const Color(0xFF1D2729), const Color(0xFF131A1B)],
                    ),
              border: g ? null : Border.all(color: _down ? kOrange : kBorder, width: 1.5),
              boxShadow: g
                  ? null
                  : [
                      // "tebal" tombol: bayangan keras di bawah, mengecil saat ditekan
                      BoxShadow(color: const Color(0xFF050708), offset: Offset(0, _down ? 1 : 5)),
                      if (_down) const BoxShadow(color: kGlow, blurRadius: 22, spreadRadius: 1),
                    ],
            ),
            child: widget.child,
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
    transitionDuration: const Duration(milliseconds: 560),
    reverseTransitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, a, __, child) {
      final curved =
          CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn);
      return AnimatedBuilder(
        animation: curved,
        child: child,
        builder: (_, c) {
          final t = curved.value.clamp(0.0, 1.0).toDouble();
          return Opacity(
            opacity: t,
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: persp(0.0011) *
                  Matrix4.translationValues(0, (1 - t) * 60, 0) *
                  Matrix4.rotationX((1 - t) * 0.55) *
                  Matrix4.diagonal3Values(0.92 + 0.08 * t, 0.92 + 0.08 * t, 1.0),
              child: c,
            ),
          );
        },
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
              if (e == null) Sfx.play('open');
              return e;
            },
            onSuccess: () {
              if (c.mounted) Navigator.pop(c, true);
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
  bool _saved = false;

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
            _saved = true;
            return null;
          },
          onSuccess: () {
            if (_saved && mounted) Navigator.pop(context, true);
          },
        ),
      ),
    );
  }
}
