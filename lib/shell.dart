import 'dart:async';
import 'package:flutter/material.dart';
import 'accounts.dart';
import 'add.dart';
import 'history.dart';
import 'quick_add.dart';
import 'recap.dart';
import 'settings.dart';
import 'sfx.dart';
import 'txn_dialog.dart';
import 'ui.dart';

const double _pillFull = 76;
const double _pillSmall = 54;

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  bool compact = false;
  Timer? _idle;

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  Widget _page(int k) {
    switch (k) {
      case 0:
        return const AddTxnScreen(key: ValueKey(0));
      case 1:
        return const AccountsScreen(key: ValueKey(1));
      case 2:
        return const HistoryScreen(key: ValueKey(2));
      case 3:
        return const RecapScreen(key: ValueKey(3));
      default:
        return const SettingsScreen(key: ValueKey(4));
    }
  }

  void _setCompact(bool v) {
    if (compact == v || !mounted) return;
    setState(() => compact = v);
  }

  /// Bar bawah mengecil begitu konten mulai digulir dan DIPERTAHANKAN kecil
  /// selama masih bergulir (termasuk saat jari berhenti sebentar / meluncur).
  /// Baru membesar lagi setelah gulir benar-benar berhenti, atau saat sampai
  /// di paling atas.
  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is ScrollStartNotification) {
      _idle?.cancel();
    } else if (n is ScrollUpdateNotification) {
      final d = n.scrollDelta ?? 0;
      if (n.metrics.pixels <= 4) {
        _idle?.cancel();
        _setCompact(false);
      } else if (d.abs() > 0.5 || n.dragDetails != null) {
        _idle?.cancel();
        _setCompact(true);
      }
    } else if (n is ScrollEndNotification) {
      _idle?.cancel();
      if (n.metrics.pixels <= 4) {
        _setCompact(false);
      } else {
        _idle = Timer(const Duration(milliseconds: 1500), () => _setCompact(false));
      }
    }
    return false;
  }

  void _go(int k) {
    _idle?.cancel();
    setState(() {
      i = k;
      compact = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0D0E), Color(0xFF0A0D0E), Color(0xFF2B1B21)],
            stops: [0, 0.6, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 460),
                    switchInCurve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
                    switchOutCurve: const Interval(0.6, 1.0),
                    transitionBuilder: (child, a) => AnimatedBuilder(
                      animation: a,
                      child: child,
                      builder: (_, c) {
                        final out = a.status == AnimationStatus.reverse;
                        return Opacity(
                          opacity: a.value.clamp(0.0, 1.0).toDouble(),
                          child: FractionalTranslation(
                            translation: Offset(0, out ? 0 : 0.02 * (1 - a.value)),
                            child: c,
                          ),
                        );
                      },
                    ),
                    child: _page(i),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: NavPill(
                  index: i,
                  compact: compact,
                  onSelect: _go,
                  onTouch: () => _setCompact(false),
                ),
              ),
            ),
            Positioned.fill(
              child: QuickAdd(
                visible: i != 4,
                bottom: safeBottom + 14 + (compact ? _pillSmall : _pillFull) + 8,
                onPick: (t) => showTxnDialog(context, t),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bar navigasi bawah. Bisa diketuk ATAU digeser langsung dengan jari
/// (lingkaran oranye ikut jari, halaman berganti saat dilewati).
/// Saat [compact] bar mengecil.
class NavPill extends StatefulWidget {
  final int index;
  final bool compact;
  final ValueChanged<int> onSelect;
  final VoidCallback onTouch;
  const NavPill({
    super.key,
    required this.index,
    required this.compact,
    required this.onSelect,
    required this.onTouch,
  });

  static const icons = [
    Icons.add,
    Icons.remove_circle_outline,
    Icons.description_outlined,
    Icons.bar_chart_rounded,
    Icons.tune,
  ];

  @override
  State<NavPill> createState() => _NavPillState();
}

class _NavPillState extends State<NavPill> {
  bool _drag = false;
  double _dx = 0;
  double _w = 1;

  int get _n => NavPill.icons.length;

  int _idx(double dx) => (dx / (_w / _n)).floor().clamp(0, _n - 1).toInt();

  void _select(int k) {
    if (k == widget.index) return;
    Sfx.click();
    Sfx.buzz();
    widget.onSelect(k);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: widget.compact ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) {
          final h = _pillFull - (_pillFull - _pillSmall) * t;
          final barH = 64 - 20 * t;
          final circ = 72 - 26 * t;
          final ico = 28 - 6 * t;
          return LayoutBuilder(builder: (ctx, bc) {
            final w = bc.maxWidth * (1 - 0.34 * t);
            _w = w;
            final slot = w / _n;
            final target = _drag
                ? ((_dx / slot) - 0.5).clamp(0.0, (_n - 1).toDouble()).toDouble()
                : widget.index.toDouble();
            return Center(
              child: SizedBox(
                width: w,
                height: h,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) {
                    _select(_idx(d.localPosition.dx));
                    widget.onTouch();
                  },
                  onHorizontalDragStart: (d) {
                    setState(() {
                      _drag = true;
                      _dx = d.localPosition.dx;
                    });
                    _select(_idx(_dx));
                  },
                  onHorizontalDragUpdate: (d) {
                    setState(() => _dx = d.localPosition.dx);
                    _select(_idx(_dx));
                  },
                  onHorizontalDragEnd: (_) {
                    setState(() => _drag = false);
                    widget.onTouch();
                  },
                  onHorizontalDragCancel: () => setState(() => _drag = false),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: w,
                        height: barH,
                        decoration: BoxDecoration(
                          color: const Color(0xFF171E1F),
                          borderRadius: BorderRadius.circular(barH / 2),
                          border: Border.all(color: kBorder),
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: target),
                        duration: _drag ? Duration.zero : const Duration(milliseconds: 380),
                        curve: Curves.easeOutBack,
                        builder: (_, pos, __) => Positioned(
                          left: pos * slot + slot / 2 - circ / 2,
                          top: (h - circ) / 2,
                          child: Container(
                            width: circ,
                            height: circ,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: kOrange, width: 3 - t),
                              boxShadow: const [
                                BoxShadow(color: kGlow, blurRadius: 26, spreadRadius: 4)
                              ],
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var k = 0; k < _n; k++)
                            Expanded(
                              child: Center(
                                child: AnimatedScale(
                                  scale: k == widget.index ? 1.12 : 1,
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutBack,
                                  child: TweenAnimationBuilder<Color?>(
                                    tween: ColorTween(end: k == widget.index ? kOrange : kText),
                                    duration: const Duration(milliseconds: 250),
                                    builder: (_, c, __) => Icon(NavPill.icons[k], color: c, size: ico),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          });
        },
      ),
    );
  }
}
