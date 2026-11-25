import 'package:flutter/material.dart';
import 'db.dart';
import 'ui.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends State<HistoryScreen> {
  List<Txn> list = [];

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
    final l = await Db.i.txns();
    if (mounted) setState(() => list = l);
  }

  Future<bool> _ask() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 190),
      children: [
        const Text('Riwayat', style: kTitle),
        const SizedBox(height: 16),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('Belum ada transaksi', style: TextStyle(color: kMuted))),
          ),
        for (final t in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Dismissible(
              key: ValueKey(t.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => _ask(),
              onDismissed: (_) {
                setState(() => list.removeWhere((x) => x.id == t.id));
                Db.i.deleteTxn(t.id);
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 22),
                decoration: BoxDecoration(
                    color: const Color(0x33FF8F85), borderRadius: BorderRadius.circular(22)),
                child: const Icon(Icons.delete_outline, color: kOut),
              ),
              child: _row(t),
            ),
          ),
      ],
    );
  }

  Widget _row(Txn t) {
    final isIn = t.type == 'in', isOut = t.type == 'out';
    final c = isIn ? kIn : (isOut ? kOut : kOrange);
    final ic = isIn ? Icons.arrow_downward : (isOut ? Icons.arrow_upward : Icons.swap_horiz);
    final name = isIn ? 'Pemasukan' : (isOut ? 'Pengeluaran' : 'Pindah saldo');
    final where = t.type == 'transfer' ? '${t.accName} → ${t.toName ?? '?'}' : t.accName;
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: c.withAlpha(40), borderRadius: BorderRadius.circular(14)),
            child: Icon(ic, color: c),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.note.isEmpty ? name : t.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('$where · ${fmtDate(t.ts)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kMuted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${isIn ? '+' : (isOut ? '-' : '')}${money(t.amount)}',
              style: TextStyle(fontWeight: FontWeight.w700, color: t.type == 'transfer' ? kText : c)),
        ],
      ),
    );
  }
}
