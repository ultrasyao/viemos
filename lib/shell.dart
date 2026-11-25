import 'package:flutter/material.dart';
import 'accounts.dart';
import 'add.dart';
import 'history.dart';
import 'quick_add.dart';
import 'recap.dart';
import 'sfx.dart';
import 'txn_dialog.dart';
import 'ui.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;

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
        return const _Soon(key: ValueKey(4), title: 'Setting');
    }
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
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: NavPill(index: i, onTap: (v) => setState(() => i = v)),
              ),
            ),
            Positioned.fill(
              child: QuickAdd(
                visible: i != 4,
                bottom: safeBottom + 14 + 76 + 8,
                onPick: (t) => showTxnDialog(context, t),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Soon extends StatelessWidget {
  final String title;
  const _Soon({super.key, required this.title});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: kTitle),
            const SizedBox(height: 40),
            const Center(child: Text('Segera hadir', style: TextStyle(color: kMuted))),
          ],
        ),
      );
}

class NavPill extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const NavPill({super.key, required this.index, required this.onTap});

  static const icons = [
    Icons.add,
    Icons.remove_circle_outline,
    Icons.description_outlined,
    Icons.bar_chart_rounded,
    Icons.tune,
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: SizedBox(
        height: 76,
        child: LayoutBuilder(builder: (ctx, bc) {
          final slot = bc.maxWidth / icons.length;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: double.infinity,
                height: 64,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF171E1F),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: kBorder),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                left: index * slot + slot / 2 - 36,
                top: 2,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: kOrange, width: 3),
                    boxShadow: const [BoxShadow(color: kGlow, blurRadius: 26, spreadRadius: 4)],
                  ),
                ),
              ),
              Row(
                children: [
                  for (var k = 0; k < icons.length; k++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (k != index) Sfx.click();
                          onTap(k);
                        },
                        child: SizedBox(
                          height: 76,
                          child: Center(
                            child: TweenAnimationBuilder<Color?>(
                              tween: ColorTween(end: k == index ? kOrange : kText),
                              duration: const Duration(milliseconds: 250),
                              builder: (_, c, __) => Icon(icons[k], color: c, size: 28),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }
}
