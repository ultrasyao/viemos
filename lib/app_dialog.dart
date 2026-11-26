import 'strings.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'kb.dart';
import 'sfx.dart';
import 'ui.dart';
import 'theme.dart';

/// Popup yang "mekar" dari atas layar ke tengah (seperti pulau yang melebar),
/// ada suara buka & tutup. Dipakai untuk SEMUA popup di app.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Color? accent,
  bool dismissible = true,
}) {
  Sfx.play('open');
  Sfx.buzz();
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: tr('Tutup'),
    barrierColor: Pal.scrim,
    transitionDuration: const Duration(milliseconds: 560),
    pageBuilder: (ctx, _, __) => _CloseSound(child: builder(ctx)),
    transitionBuilder: (ctx, a, __, child) => _expand(ctx, a, child),
  );
}

/// Transisi popup 3D: panel "jatuh" dari pulau di atas layar, terlipat ke
/// belakang lalu terbuka rata menghadap kita (ada pantulan kecil di akhir).
/// TIDAK ada clip sama sekali, jadi cahaya/bayangan panel tidak terpotong.
Widget _expand(BuildContext ctx, Animation<double> a, Widget child) {
  final bottom = MediaQuery.of(ctx).viewInsets.bottom;
  return AnimatedBuilder(
    animation: a,
    child: child,
    builder: (_, c) {
      final v = a.value;
      final pos = Curves.easeOutCubic.transform(const Interval(0.0, 0.85).transform(v));
      final flip = Curves.easeOutBack.transform(const Interval(0.04, 0.92).transform(v));
      final grow = Curves.easeOutCubic.transform(const Interval(0.0, 0.7).transform(v));
      final op = const Interval(0.0, 0.3).transform(v).clamp(0.0, 1.0).toDouble();
      final angle = (1 - flip) * 1.0; // terlipat ke belakang -> rata
      final s = 0.72 + 0.28 * grow;
      final safeB = MediaQuery.of(ctx).padding.bottom;
      // keyboard Viemos menempel di dasar layar; popup naik mengikuti (animasi halus)
      return ValueListenableBuilder<double>(
        valueListenable: Kb.inset,
        child: SafeArea(
          child: Align(
            alignment: Alignment(0, -1 + pos),
            child: Opacity(
              opacity: op,
              child: Transform(
                alignment: Alignment.topCenter,
                transform: persp(0.0011) *
                    Matrix4.rotationX(angle) *
                    Matrix4.diagonal3Values(s, s, 1.0),
                child: c,
              ),
            ),
          ),
        ),
        builder: (_, kb, child) => AnimatedPadding(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: math.max(bottom, kb - safeB)),
          child: child,
        ),
      );
    },
  );
}

class _CloseSound extends StatefulWidget {
  final Widget child;
  const _CloseSound({required this.child});
  @override
  State<_CloseSound> createState() => _CloseSoundState();
}

class _CloseSoundState extends State<_CloseSound> {
  Animation<double>? _a;

  void _l(AnimationStatus s) {
    if (s == AnimationStatus.reverse) Sfx.play('close');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_a == null) {
      _a = ModalRoute.of(context)?.animation;
      _a?.addStatusListener(_l);
    }
  }

  @override
  void dispose() {
    _a?.removeStatusListener(_l);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Kartu isi popup (lebar maks 440, bisa discroll kalau kepanjangan).
/// Cahaya warna [accent] digambar di LUAR kartu; padding luar sengaja longgar
/// supaya cahayanya tidak terpotong tepi layar.
class AppPanel extends StatelessWidget {
  final Widget child;
  final Color? accent;
  final EdgeInsets padding;
  const AppPanel({
    super.key,
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 20),
  });

  @override
  Widget build(BuildContext context) {
    final accent = this.accent ?? kOrange;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: kPanel,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: accent.withAlpha(90)),
              boxShadow: [
                BoxShadow(color: accent.withAlpha(64), blurRadius: 26, spreadRadius: 1),
                BoxShadow(color: Pal.shadow, blurRadius: 22, offset: const Offset(0, 10)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(27),
              child: Material(
                type: MaterialType.transparency,
                child: SingleChildScrollView(padding: padding, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog konfirmasi. true = tombol utama ditekan.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmText = 'OK',
  String cancelText = tr('Batal'),
  bool danger = false,
}) async {
  final c = danger ? kOut : kOrange;
  final r = await showAppDialog<bool>(
    context,
    accent: c,
    builder: (ctx) => AppPanel(
      accent: c,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          if (message != null) ...[
            const SizedBox(height: 10),
            Text(message, style: TextStyle(color: kMuted, height: 1.4)),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AppButton(cancelText, outlined: true, onTap: () => Navigator.pop(ctx, false)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(confirmText, color: c, onTap: () => Navigator.pop(ctx, true)),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return r == true;
}

/// Dialog pilih salah satu. Return nilai yang dipilih (null kalau ditutup).
Future<T?> choiceDialog<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  T? selected,
}) {
  return showAppDialog<T>(
    context,
    builder: (ctx) => AppPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Bounce(
                onTap: () => Navigator.pop(ctx, o.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: o.$1 == selected ? kOrange.withAlpha(36) : kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: o.$1 == selected ? kOrange : kBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(o.$2,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: o.$1 == selected ? kOrange : kText)),
                      ),
                      if (o.$1 == selected) Icon(Icons.check_rounded, color: kOrange, size: 20),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
