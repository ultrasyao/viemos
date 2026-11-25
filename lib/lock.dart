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
          builder: (_, v, __) => v ? const _LockScreen() : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen();
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        color: const Color(0xFF0A0D0E),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 36),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kOrange.withAlpha(28),
                  border: Border.all(color: kOrange.withAlpha(120), width: 2),
                ),
                child: const Icon(Icons.lock_outline_rounded, color: kOrange, size: 28),
              ),
              const SizedBox(height: 12),
              const Text('Viemos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              Expanded(
                child: PinPad(
                  title: 'Masukkan PIN',
                  onSubmit: (p) async {
                    final e = await Lock.check(p);
                    if (e == null) Lock.locked.value = false;
                    return e;
                  },
                ),
              ),
            ],
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
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _tap(String d) {
    if (busy || pin.length >= kPinLen) return;
    Sfx.click();
    setState(() {
      pin += d;
      err = null;
    });
    if (pin.length == kPinLen) _submit();
  }

  void _del() {
    if (busy || pin.isEmpty) return;
    setState(() => pin = pin.substring(0, pin.length - 1));
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
        pin = '';
        busy = false;
      });
    } else {
      setState(() {
        busy = false;
        if (widget.clearOnSuccess) pin = '';
      });
    }
  }

  Widget _key(Widget child, VoidCallback? on) => SizedBox(
        width: 78,
        height: 70,
        child: InkResponse(
          onTap: on,
          radius: 40,
          child: Center(child: child),
        ),
      );

  Widget _digit(String d) => _key(
        Text(d, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
        () => _tap(d),
      );

  @override
  Widget build(BuildContext context) {
    final sub = err ?? widget.subtitle;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SizedBox(
              height: 36,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(sub ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: err != null ? kOut : kMuted)),
              ),
            ),
            const SizedBox(height: 8),
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
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      margin: const EdgeInsets.symmetric(horizontal: 7),
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < pin.length ? kOrange : Colors.transparent,
                        border: Border.all(color: i < pin.length ? kOrange : kBorder, width: 2),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
            ])
              Row(mainAxisSize: MainAxisSize.min, children: [for (final d in row) _digit(d)]),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.onCancel == null
                    ? const SizedBox(width: 78, height: 70)
                    : _key(const Icon(Icons.close_rounded, color: kMuted),
                        () {
                        Sfx.click();
                        widget.onCancel!();
                      }),
                _digit('0'),
                _key(const Icon(Icons.backspace_outlined, color: kMuted, size: 24), _del),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Minta PIN lalu return true kalau benar.
Future<bool> verifyPin(BuildContext context, {String title = 'Masukkan PIN'}) async {
  final r = await Navigator.of(context).push<bool>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (c) => Scaffold(
      body: SafeArea(
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
  ));
  return r == true;
}

/// Buat PIN baru (diminta dua kali). true = tersimpan.
Future<bool> setupPin(BuildContext context) async {
  final r = await Navigator.of(context).push<bool>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _PinSetup()),
  );
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
      body: SafeArea(
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
