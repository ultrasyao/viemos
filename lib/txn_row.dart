import 'package:flutter/material.dart';
import 'db.dart';
import 'ui.dart';

Future<bool> confirmDeleteTxn(BuildContext context) async {
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

/// Baris transaksi yang bisa digeser ke kiri untuk menghapus.
class TxnSwipe extends StatelessWidget {
  final Txn t;
  final VoidCallback onRemoved;
  const TxnSwipe(this.t, {super.key, required this.onRemoved});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('txn_${t.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDeleteTxn(context),
      onDismissed: (_) => onRemoved(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
            color: const Color(0x33FF8F85), borderRadius: BorderRadius.circular(22)),
        child: const Icon(Icons.delete_outline, color: kOut),
      ),
      child: TxnTile(t),
    );
  }
}

class TxnTile extends StatelessWidget {
  final Txn t;
  final bool timeOnly;
  const TxnTile(this.t, {super.key, this.timeOnly = false});

  @override
  Widget build(BuildContext context) {
    final isIn = t.type == 'in', isOut = t.type == 'out';
    final c = isIn ? kIn : (isOut ? kOut : kOrange);
    final ic = isIn ? Icons.arrow_downward : (isOut ? Icons.arrow_upward : Icons.swap_horiz);
    final name = isIn ? 'Pemasukan' : (isOut ? 'Pengeluaran' : 'Pindah saldo');
    final where = t.type == 'transfer' ? '${t.accName} → ${t.toName ?? '?'}' : t.accName;
    final when = timeOnly ? '${two(t.ts.hour)}:${two(t.ts.minute)}' : fmtDate(t.ts);
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
                Text('$where · $when',
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
