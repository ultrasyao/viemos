import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'db.dart';
import 'sfx.dart';
import 'ui.dart';

const _blnFull = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
const _blnShort = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

String _day(DateTime d) => '${d.day} ${_blnShort[d.month - 1]} ${d.year}';

class _Bucket {
  final String label;
  int inc = 0;
  int out = 0;
  _Bucket(this.label);
}

class RecapScreen extends StatefulWidget {
  const RecapScreen({super.key});
  @override
  State<RecapScreen> createState() => _RecapState();
}

class _RecapState extends State<RecapScreen> {
  int mode = 0; // 0 semua, 1 bulanan, 2 custom
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTimeRange? range;
  List<Txn> all = [];

  @override
  void initState() {
    super.initState();
    _load();
    Db.i.rev.addListener(_load);
  }

  @override
  void dispose() {
    Db.i.rev.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final t = await Db.i.txns();
    if (mounted) setState(() => all = t);
  }

  (DateTime, DateTime)? _bounds(List<Txn> list) {
    if (mode == 1) return (month, DateTime(month.year, month.month + 1));
    if (mode == 2) {
      final r = range;
      if (r == null) return null;
      return (
        DateTime(r.start.year, r.start.month, r.start.day),
        DateTime(r.end.year, r.end.month, r.end.day + 1),
      );
    }
    if (list.isEmpty) return null;
    final a = list.last.ts, b = list.first.ts;
    return (DateTime(a.year, a.month, a.day), DateTime(b.year, b.month, b.day + 1));
  }

  List<Txn> get _list {
    if (mode == 0) return all;
    final bd = _bounds(all);
    if (bd == null) return [];
    return all.where((x) => !x.ts.isBefore(bd.$1) && x.ts.isBefore(bd.$2)).toList();
  }

  List<_Bucket> _buckets(List<Txn> list) {
    final bd = _bounds(list);
    if (bd == null) return [];
    final f = bd.$1, t = bd.$2;
    final days = t.difference(f).inDays;
    final daily = days <= 31;
    final bs = <_Bucket>[];
    if (daily) {
      for (var i = 0; i < days; i++) {
        bs.add(_Bucket('${DateTime(f.year, f.month, f.day + i).day}'));
      }
    } else {
      var m = DateTime(f.year, f.month);
      while (m.isBefore(t)) {
        bs.add(_Bucket(_blnShort[m.month - 1]));
        m = DateTime(m.year, m.month + 1);
      }
    }
    for (final x in list) {
      if (x.type == 'transfer') continue;
      final idx = daily
          ? DateTime(x.ts.year, x.ts.month, x.ts.day).difference(f).inDays
          : (x.ts.year - f.year) * 12 + x.ts.month - f.month;
      if (idx < 0 || idx >= bs.length) continue;
      if (x.type == 'in') {
        bs[idx].inc += x.amount;
      } else {
        bs[idx].out += x.amount;
      }
    }
    return bs;
  }

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: range,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (r != null && mounted) setState(() => range = r);
  }

  Widget _monthBar() => GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            IconButton(
              onPressed: () {
                Sfx.click();
                setState(() => month = DateTime(month.year, month.month - 1));
              },
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Center(
                child: Text('${_blnFull[month.month - 1]} ${month.year}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
            IconButton(
              onPressed: () {
                Sfx.click();
                setState(() => month = DateTime(month.year, month.month + 1));
              },
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      );

  Widget _rangeCard() => GlassCard(
        onTap: () {
          Sfx.click();
          _pickRange();
        },
        child: Row(
          children: [
            const Icon(Icons.date_range_rounded, color: kMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(range == null
                  ? 'Pilih rentang tanggal'
                  : '${_day(range!.start)} – ${_day(range!.end)}'),
            ),
          ],
        ),
      );

  Widget _stat(String t, int v, Color c, IconData ic) => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(ic, color: c, size: 18),
              const SizedBox(width: 6),
              Text(t, style: const TextStyle(color: kMuted, fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(money(v),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c)),
            ),
          ],
        ),
      );

  Widget _dot(Color c) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  Widget _chart(List<_Bucket> bs) {
    final maxV = bs.fold<int>(0, (m, b) => math.max(m, math.max(b.inc, b.out)));
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _dot(kIn),
            const SizedBox(width: 6),
            const Text('Masuk', style: TextStyle(color: kMuted, fontSize: 12)),
            const SizedBox(width: 14),
            _dot(kOut),
            const SizedBox(width: 6),
            const Text('Keluar', style: TextStyle(color: kMuted, fontSize: 12)),
          ]),
          const SizedBox(height: 12),
          if (bs.isEmpty || maxV == 0)
            const SizedBox(
              height: 110,
              child: Center(child: Text('Belum ada data', style: TextStyle(color: kMuted))),
            )
          else
            SizedBox(
              height: 170,
              child: LayoutBuilder(builder: (ctx, bc) {
                final w = math.max(bc.maxWidth, bs.length * 26.0);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: CustomPaint(size: Size(w, 170), painter: _BarsPainter(bs, maxV)),
                );
              }),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    var inc = 0, out = 0;
    final accIn = <String, int>{};
    final accOut = <String, int>{};
    for (final x in list) {
      if (x.type == 'in') {
        inc += x.amount;
        accIn[x.accName] = (accIn[x.accName] ?? 0) + x.amount;
      } else if (x.type == 'out') {
        out += x.amount;
        accOut[x.accName] = (accOut[x.accName] ?? 0) + x.amount;
      }
    }
    final names = {...accIn.keys, ...accOut.keys}.toList();
    final net = inc - out;
    final bs = _buckets(list);

    return ListView(
      key: const PageStorageKey('page_recap'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 190),
      children: [
        const Text('Rekap', style: kTitle),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Semua')),
            ButtonSegment(value: 1, label: Text('Bulanan')),
            ButtonSegment(value: 2, label: Text('Custom')),
          ],
          selected: {mode},
          onSelectionChanged: (s) {
            Sfx.click();
            setState(() => mode = s.first);
            if (mode == 2 && range == null) _pickRange();
          },
        ),
        const SizedBox(height: 12),
        if (mode == 1) _monthBar(),
        if (mode == 2) _rangeCard(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _stat('Pemasukan', inc, kIn, Icons.south_west_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _stat('Pengeluaran', out, kOut, Icons.north_east_rounded)),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Selisih', style: TextStyle(color: kMuted, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(money(net),
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w700, color: net >= 0 ? kIn : kOut)),
                  ],
                ),
              ),
              Text('${list.length} transaksi', style: const TextStyle(color: kMuted)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _chart(bs),
        label('Per rekening'),
        if (names.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Belum ada pemasukan atau pengeluaran di periode ini',
                style: TextStyle(color: kMuted)),
          ),
        for (final n in names)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(n, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('+${money(accIn[n] ?? 0)}',
                          style: const TextStyle(color: kIn, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('-${money(accOut[n] ?? 0)}',
                          style: const TextStyle(color: kOut, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<_Bucket> b;
  final int maxV;
  _BarsPainter(this.b, this.maxV);

  @override
  void paint(Canvas canvas, Size size) {
    final baseY = size.height - 22;
    final h = baseY - 8;
    final slot = size.width / b.length;
    final bw = math.min(10.0, slot * 0.32);
    canvas.drawLine(
      Offset(0, baseY),
      Offset(size.width, baseY),
      Paint()
        ..color = kBorder
        ..strokeWidth = 1,
    );
    final pIn = Paint()..color = kIn;
    final pOut = Paint()..color = kOut;
    final step = math.max(1, (b.length / (size.width / 28)).ceil());
    for (var i = 0; i < b.length; i++) {
      final cx = slot * (i + 0.5);
      final ih = b[i].inc == 0 ? 0.0 : math.max(2.0, b[i].inc / maxV * h);
      final oh = b[i].out == 0 ? 0.0 : math.max(2.0, b[i].out / maxV * h);
      if (ih > 0) {
        canvas.drawRRect(
          RRect.fromLTRBR(cx - bw - 1, baseY - ih, cx - 1, baseY, const Radius.circular(3)),
          pIn,
        );
      }
      if (oh > 0) {
        canvas.drawRRect(
          RRect.fromLTRBR(cx + 1, baseY - oh, cx + bw + 1, baseY, const Radius.circular(3)),
          pOut,
        );
      }
      if (i % step == 0) {
        final tp = TextPainter(
          text: TextSpan(text: b[i].label, style: const TextStyle(color: kMuted, fontSize: 10)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, baseY + 6));
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter o) => true;
}
