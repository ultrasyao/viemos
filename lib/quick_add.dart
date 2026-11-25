import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'sfx.dart';
import 'ui.dart';

class _Item {
  final String type, label;
  final IconData icon;
  final Color color;
  const _Item(this.type, this.label, this.icon, this.color);
}

const _items = [
  _Item('in', 'Pemasukan', Icons.south_west_rounded, kIn),
  _Item('out', 'Pengeluaran', Icons.north_east_rounded, kOut),
  _Item('transfer', 'Pindah saldo', Icons.swap_horiz_rounded, kOrange),
];

class QuickAdd extends StatefulWidget {
  final bool visible;
  final double bottom;
  final void Function(String type) onPick;
  const QuickAdd({super.key, required this.visible, required this.bottom, required this.onPick});

  @override
  State<QuickAdd> createState() => _QuickAddState();
}

class _QuickAddState extends State<QuickAdd> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    reverseDuration: const Duration(milliseconds: 280),
  );
  bool open = false;
  bool _down = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(QuickAdd old) {
    super.didUpdateWidget(old);
    if (!widget.visible && open) {
      open = false;
      _c.reverse();
    }
  }

  void _toggle() {
    Sfx.click();
    setState(() => open = !open);
    open ? _c.forward() : _c.reverse();
  }

  void _close() {
    if (!open) return;
    setState(() => open = false);
    _c.reverse();
  }

  void _pick(String t) {
    Sfx.click();
    _close();
    Future.delayed(const Duration(milliseconds: 90), () {
      if (mounted) widget.onPick(t);
    });
  }

  Widget _dialItem(int k, double v) {
    final it = _items[k];
    final t = Interval(0.10 * k, 0.10 * k + 0.6, curve: Curves.easeOutBack).transform(v);
    return IgnorePointer(
      ignoring: !open,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Opacity(
          opacity: t.clamp(0.0, 1.0).toDouble(),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 36),
            child: Transform.scale(
              scale: 0.5 + 0.5 * t,
              alignment: Alignment.centerRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _pick(it.type),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: kCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kBorder),
                      ),
                      child: Text(it.label,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: kText)),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF151C1D),
                        border: Border.all(color: it.color, width: 2),
                        boxShadow: [BoxShadow(color: it.color.withAlpha(70), blurRadius: 18)],
                      ),
                      child: Icon(it.icon, color: it.color),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fab(double v) {
    final bg = Color.lerp(const Color(0xFF171E1F), kOrange, v)!;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: _toggle,
      child: AnimatedScale(
        scale: _down ? 0.92 : 1,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            border: Border.all(color: kOrange, width: 3),
            boxShadow: const [BoxShadow(color: kGlow, blurRadius: 24, spreadRadius: 3)],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: v * math.pi / 2,
                child: Opacity(
                  opacity: 1 - v,
                  child: const Icon(Icons.edit_outlined, color: kOrange, size: 26),
                ),
              ),
              Transform.rotate(
                angle: (v - 1) * math.pi / 2,
                child: Opacity(
                  opacity: v,
                  child: const Icon(Icons.close_rounded, color: Color(0xFF0A0D0E), size: 28),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !open,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: ColoredBox(
                    color: Colors.black.withAlpha((170 * Curves.easeOut.transform(v)).round()),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: widget.bottom,
              child: AnimatedScale(
                scale: widget.visible ? 1 : 0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: IgnorePointer(
                  ignoring: !widget.visible,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var k = _items.length - 1; k >= 0; k--) _dialItem(k, v),
                      _fab(v),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
