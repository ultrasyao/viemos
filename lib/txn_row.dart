import 'strings.dart';
import 'package:flutter/material.dart';
import 'app_dialog.dart';
import 'db.dart';
import 'island.dart';
import 'txn_dialog.dart';
import 'ui.dart';

Future<bool> confirmDeleteTxn(BuildContext context) => confirmDialog(
      context,
      title: tr('Hapus transaksi?'),
      message: tr('Transaksi ini dihapus permanen dan saldo rekening ikut berubah.'),
      confirmText: tr('Hapus'),
      danger: true,
    );

void _deletedToast(BuildContext context, Txn t) {
  final isTf = t.type == 'transfer';
  final where = isTf ? '${t.accName} → ${t.toName ?? '?'}' : t.accName;
  final sign = t.type == 'in' ? '+' : (t.type == 'out' ? '-' : '');
  showIsland(
    context,
    title: tr('Transaksi dihapus'),
    subtitle: t.note.isEmpty ? where : '$where · ${t.note}',
    amount: '$sign${money(t.amount)}',
    icon: Icons.delete_outline_rounded,
    color: kOut,
    sound: 'out',
  );
}

/// Baris transaksi: ketuk untuk ubah (di dalam ada tombol Hapus),
/// geser ke kiri ATAU tahan lama untuk menghapus.
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
      onDismissed: (_) {
        _deletedToast(context, t);
        onRemoved();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
            color: kOut.withAlpha(0x33), borderRadius: BorderRadius.circular(22)),
        child: Icon(Icons.delete_outline, color: kOut),
      ),
      child: TxnTile(
        t,
        onTap: () => showTxnDialog(context, t.type, edit: t),
        onLongPress: () async {
          if (await confirmDeleteTxn(context) && context.mounted) {
            _deletedToast(context, t);
            onRemoved();
          }
        },
      ),
    );
  }
}

class TxnTile extends StatelessWidget {
  final Txn t;
  final bool timeOnly;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const TxnTile(this.t, {super.key, this.timeOnly = false, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final isIn = t.type == 'in', isOut = t.type == 'out';
    final c = isIn ? kIn : (isOut ? kOut : kOrange);
    final ic = isIn ? Icons.arrow_downward : (isOut ? Icons.arrow_upward : Icons.swap_horiz);
    final name = isIn ? tr('Pemasukan') : (isOut ? tr('Pengeluaran') : tr('Pindah saldo'));
    final where = t.type == 'transfer' ? '${t.accName} → ${t.toName ?? '?'}' : t.accName;
    final when = timeOnly ? '${two(t.ts.hour)}:${two(t.ts.minute)}' : fmtDate(t.ts);
    return GlassCard(
      onTap: onTap,
      onLongPress: onLongPress,
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
