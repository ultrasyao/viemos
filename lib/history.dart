import 'package:flutter/material.dart';
import 'db.dart';
import 'txn_row.dart';
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
            child: TxnSwipe(t, onRemoved: () {
              setState(() => list.removeWhere((x) => x.id == t.id));
              Db.i.deleteTxn(t.id);
            }),
          ),
      ],
    );
  }
}
