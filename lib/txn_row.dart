import 'package:flutter/material.dart';
import 'app_dialog.dart';
import 'db.dart';
import 'txn_dialog.dart';
import 'ui.dart';

Future<bool> confirmDeleteTxn(BuildContext context) => confirmDialog(
      context,
      title: 'Hapus transaksi?',
      message: 'Transaksi ini dihapus permanen dan saldo rekening ikut berubah.',
      confirmText: 'Hapus',
      danger: true,
    );

/// Baris transaksi: ketuk untuk ubah, geser ke kiri untuk menghapus.
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
        child: Icon(Icons.delete_outline, color: kOut),
      ),
      child: TxnTile(t, onTap: () => showTxnDialog(context, t.type, edit: t)),
    );
  }
}

class TxnTile extends StatelessWidget {
  final Txn t;
  final bool timeOnly;
  final VoidCallback? onTap;
  const TxnTile(this.t, {super.key, this.timeOnly = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isIn = t.type == 'in', isOut = t.type == 'out';
    final c = isIn ? kIn : (isOut ? kOut : kOrange);
    final ic = isIn ? Icons.arrow_downward : (isOut ? Icons.arrow_upward : Icons.swap_horiz);
    final name = isIn ? 'Pemasukan' : (isOut ? 'Pengeluaran' : 'Pindah saldo');
    final where = t.type == 'transfer' ? '${t.accName} → ${t.toName ?? '?'}' : t.accName;
    final when = timeOnly ? '${two(t.ts.hour)}:${two(t.ts.minute)}' : fmtDate(t.ts);
    return GlassCard(
      onTap: onTap,
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
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('$where · $when',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: kMuted, fontSize: 12)),
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
