import 'package:flutter/material.dart';
import 'sfx.dart';
import 'ui.dart';

/// Popup yang "mekar" dari atas layar ke tengah (seperti pulau yang melebar),
/// ada suara buka & tutup. Dipakai untuk SEMUA popup di app.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Color accent = kOrange,
  bool dismissible = true,
}) {
  Sfx.play('open');
  Sfx.buzz();
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'Tutup',
    barrierColor: Colors.black.withAlpha(165),
    transitionDuration: const Duration(milliseconds: 560),
    pageBuilder: (ctx, _, __) => _CloseSound(child: builder(ctx)),
    transitionBuilder: (ctx, a, __, child) => _expand(ctx, a, child),
  );
}

Widget _expand(BuildContext ctx, Animation<double> a, Widget child) {
  final bottom = MediaQuery.of(ctx).viewInsets.bottom;
  return AnimatedBuilder(
    animation: a,
    child: child,
    builder: (_, c) {
      final v = a.value;
      // posisi: dari tepi atas ke tengah
      final pos = Curves.easeInOutCubic.transform(const Interval(0.0, 0.9).transform(v));
      // lebar & tinggi jendela membuka (isi panel terungkap, tidak gepeng)
      final w = Curves.easeOutCubic.transform(const Interval(0.0, 0.75).transform(v));
      final h = Curves.easeInOutCubic.transform(const Interval(0.08, 1.0).transform(v));
      final op = const Interval(0.0, 0.25).transform(v).clamp(0.0, 1.0).toDouble();
      final inner = const Interval(0.3, 0.85, curve: Curves.easeOut).transform(v);
      final r = 36 - 10 * h;
      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SafeArea(
          child: Align(
            alignment: Alignment(0, -1 + pos),
            child: Opacity(
              opacity: op,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(r),
                child: Align(
                  alignment: Alignment.topCenter,
                  widthFactor: 0.42 + 0.58 * w,
                  heightFactor: 0.12 + 0.88 * h,
                  child: Opacity(opacity: inner.clamp(0.0, 1.0).toDouble(), child: c),
                ),
              ),
            ),
          ),
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
class AppPanel extends StatelessWidget {
  final Widget child;
  final Color accent;
  final EdgeInsets padding;
  const AppPanel({
    super.key,
    required this.child,
    this.accent = kOrange,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 20),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SizedBox(
          width: double.infinity,
          child: Material(
            color: const Color(0xFF111718),
            elevation: 12,
            shadowColor: accent,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: accent.withAlpha(90)),
            ),
            child: SingleChildScrollView(padding: padding, child: child),
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
  String cancelText = 'Batal',
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
            Text(message, style: const TextStyle(color: kMuted, height: 1.4)),
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
                      if (o.$1 == selected) const Icon(Icons.check_rounded, color: kOrange, size: 20),
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
