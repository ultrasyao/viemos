import 'package:flutter/material.dart';
import 'island.dart';

const kOrange = Color(0xFFFFB066);
const kGlow = Color(0x38FFB066);
const kCard = Color(0xFF151C1D);
const kBorder = Color(0xFF2A3335);
const kIn = Color(0xFF7BE0A8);
const kOut = Color(0xFFFF8F85);
const kText = Color(0xFFE6EEEE);
const kMuted = Color(0xFF8A9A9C);
const kTitle = TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: kText);

bool kDecimals = false;

String money(int cents, {bool? dec}) {
  final showDec = dec ?? kDecimals;
  final neg = cents < 0;
  final a = cents.abs();
  var whole = a ~/ 100;
  final frac = a % 100;
  if (!showDec && frac >= 50) whole += 1;
  final s = whole
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  final d = showDec ? ',${frac.toString().padLeft(2, '0')}' : '';
  return '${neg ? '-' : ''}Rp $s$d';
}

int? parseMoney(String s) {
  final t = s.trim().replaceAll(' ', '').replaceAll('.', '').replaceAll(',', '.');
  final d = double.tryParse(t);
  if (d == null) return null;
  return (d * 100).round();
}

String two(int n) => n.toString().padLeft(2, '0');
const _bln = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
String fmtDate(DateTime d) =>
    '${d.day} ${_bln[d.month - 1]} ${d.year}, ${two(d.hour)}:${two(d.minute)}';

Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(t, style: const TextStyle(color: kMuted, fontSize: 13)),
    );

void toast(BuildContext c, String m) =>
    showIsland(c, title: m, icon: Icons.info_outline_rounded, color: kOrange, sound: 'info');

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: kBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
