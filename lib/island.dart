import 'dart:async';
import 'package:flutter/material.dart';
import 'sfx.dart';
import 'ui.dart';

OverlayEntry? _islandEntry;

/// Notifikasi "pulau" di atas layar: langsung melebar penuh, ada suara + getar,
/// hilang sendiri, bisa digeser ke atas / diketuk untuk menutup.
void showIsland(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? amount,
  IconData icon = Icons.check_rounded,
  Color? color,
  String sound = 'info',
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final old = _islandEntry;
  if (old != null && old.mounted) old.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Island(
      title: title,
      subtitle: subtitle,
      amount: amount,
      icon: icon,
      color: color ?? kOrange,
      sound: sound,
      onDone: () {
        if (entry.mounted) entry.remove();
        if (identical(_islandEntry, entry)) _islandEntry = null;
      },
    ),
  );
  _islandEntry = entry;
  overlay.insert(entry);
}

class _Island extends StatefulWidget {
  final String title;
  final String? subtitle, amount;
  final IconData icon;
  final Color color;
  final String sound;
  final VoidCallback onDone;
  const _Island({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.icon,
    required this.color,
    required this.sound,
    required this.onDone,
  });

  @override
  State<_Island> createState() => _IslandState();
}

class _IslandState extends State<_Island> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    reverseDuration: const Duration(milliseconds: 320),
  );
  Timer? _t;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    Sfx.notify(widget.sound);
    _c.forward();
    _t = Timer(const Duration(milliseconds: 3800), _close);
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    _t?.cancel();
    _c.reverse().whenComplete(widget.onDone);
  }

  Widget _content() {
    final sub = widget.subtitle;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withAlpha(40)),
            child: Icon(widget.icon, color: widget.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: kText)),
                if (sub != null && sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: kMuted)),
                ],
              ],
            ),
          ),
          if (widget.amount != null) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(widget.amount!,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: widget.color)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final full = mq.size.width - 32;
    final hasSub = widget.subtitle != null && widget.subtitle!.isNotEmpty;
    final h = hasSub ? 84.0 : 64.0;
    return Positioned(
      top: mq.padding.top + 10,
      left: 16,
      right: 16,
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final v = _c.value;
            final drop = Curves.easeOutBack.transform(const Interval(0, 0.45).transform(v));
            final grow = Curves.easeOutCubic.transform(const Interval(0.12, 1).transform(v));
            final w = 150 + (full - 150) * grow;
            final r = 32 - 8 * grow;
            return Opacity(
              opacity: const Interval(0, 0.25).transform(v).clamp(0.0, 1.0).toDouble(),
              child: Transform.translate(
                offset: Offset(0, -(1 - drop) * 90),
                child: Center(
                  child: GestureDetector(
                    onTap: _close,
                    onVerticalDragEnd: (d) {
                      if ((d.primaryVelocity ?? 0) < -80) _close();
                    },
                    child: Container(
                      width: w,
                      height: h,
                      decoration: BoxDecoration(
                        color: kPanel,
                        borderRadius: BorderRadius.circular(r),
                        border: Border.all(color: widget.color.withAlpha(140), width: 1.5),
                        boxShadow: [BoxShadow(color: widget.color.withAlpha(60), blurRadius: 26)],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(r),
                        child: OverflowBox(
                          alignment: Alignment.center,
                          minWidth: full,
                          maxWidth: full,
                          minHeight: h,
                          maxHeight: h,
                          child: _content(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
