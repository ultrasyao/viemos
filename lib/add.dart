import 'package:flutter/material.dart';
import 'db.dart';
import 'txn_row.dart';
import 'ui.dart';

const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

class AddTxnScreen extends StatefulWidget {
  const AddTxnScreen({super.key});
  @override
  State<AddTxnScreen> createState() => _AddTxnState();
}

class _AddTxnState extends State<AddTxnScreen> {
  List<Txn> today = [];
  int total = 0;

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
    final all = await Db.i.txns();
    final accs = await Db.i.accounts();
    final n = DateTime.now();
    final a = DateTime(n.year, n.month, n.day);
    final b = DateTime(n.year, n.month, n.day + 1);
    final t = all.where((x) => !x.ts.isBefore(a) && x.ts.isBefore(b)).toList();
    if (!mounted) return;
    setState(() {
      today = t;
      total = accs.fold<int>(0, (s, x) => s + x.balance);
    });
  }

  Widget _stat(String label, int v, Color c, IconData ic) => Expanded(
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: c.withAlpha(40), borderRadius: BorderRadius.circular(11)),
              child: Icon(ic, color: c, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: kMuted, fontSize: 12)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(money(v), style: TextStyle(fontWeight: FontWeight.w700, color: c)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final n = DateTime.now();
    var inc = 0, out = 0;
    for (final t in today) {
      if (t.type == 'in') inc += t.amount;
      if (t.type == 'out') out += t.amount;
    }
    final net = inc - out;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 190),
      children: [
        Text(tr('Catat transaksi'), style: kTitle),
        const SizedBox(height: 4),
        Text('${_hari[n.weekday - 1]}, ${n.day} ${_bulan[n.month - 1]} ${n.year}',
            style: TextStyle(color: kMuted)),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('Hari ini'), style: TextStyle(color: kMuted, fontSize: 13)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('${net > 0 ? '+' : ''}${money(net)}',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: net > 0 ? kIn : (net < 0 ? kOut : kText))),
              ),
              const SizedBox(height: 14),
              Row(children: [
                _stat(tr('Masuk'), inc, kIn, Icons.south_west_rounded),
                const SizedBox(width: 12),
                _stat(tr('Keluar'), out, kOut, Icons.north_east_rounded),
              ]),
              const SizedBox(height: 14),
              Divider(height: 1, color: kBorder),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(tr('Total saldo'), style: TextStyle(color: kMuted)),
                  const Spacer(),
                  Text(money(total), style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
        label(today.isEmpty ? 'Transaksi hari ini' : 'Transaksi hari ini · ${today.length} (ketuk untuk ubah)'),
        if (today.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kOrange.withAlpha(28),
                    border: Border.all(color: kOrange.withAlpha(120), width: 2),
                  ),
                  child: Icon(Icons.edit_outlined, color: kOrange, size: 28),
                ),
                const SizedBox(height: 14),
                Text(tr('Belum ada transaksi hari ini'), style: TextStyle(color: kMuted)),
                const SizedBox(height: 2),
                Text(tr('Ketuk tombol pensil di kanan bawah'), style: TextStyle(color: kMuted)),
              ],
            ),
          ),
        for (final t in today)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TxnSwipe(t, onRemoved: () {
              setState(() => today.removeWhere((x) => x.id == t.id));
              Db.i.deleteTxn(t.id);
            }),
          ),
      ],
    );
  }
}
