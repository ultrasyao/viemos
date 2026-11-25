import 'package:flutter/material.dart';
import 'db.dart';
import 'ui.dart';

class AddTxnScreen extends StatefulWidget {
  const AddTxnScreen({super.key});
  @override
  State<AddTxnScreen> createState() => _AddTxnState();
}

class _AddTxnState extends State<AddTxnScreen> {
  String type = 'out';
  List<Account> accs = [];
  int? from, to;
  final amountC = TextEditingController();
  final noteC = TextEditingController();
  DateTime when = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
    Db.i.rev.addListener(_load);
  }

  @override
  void dispose() {
    Db.i.rev.removeListener(_load);
    amountC.dispose();
    noteC.dispose();
    super.dispose();
  }

  void _fixTo() {
    if (!accs.any((x) => x.id == to) || to == from) {
      final o = accs.where((x) => x.id != from);
      to = o.isEmpty ? null : o.first.id;
    }
  }

  Future<void> _load() async {
    final a = await Db.i.accounts();
    if (!mounted) return;
    setState(() {
      accs = a;
      if (!a.any((x) => x.id == from)) from = a.isEmpty ? null : a.first.id;
      _fixTo();
    });
  }

  Future<void> _pick() async {
    final d = await showDatePicker(
        context: context, initialDate: when, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(when));
    if (t == null) return;
    setState(() => when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    final amt = parseMoney(amountC.text);
    if (from == null) return toast(context, 'Tambah rekening dulu di tab Rekening');
    if (amt == null || amt <= 0) return toast(context, 'Isi jumlah dengan benar');
    if (type == 'transfer' && (to == null || to == from)) {
      return toast(context, 'Pilih rekening tujuan yang berbeda');
    }
    await Db.i.addTxn(
      type: type,
      accountId: from!,
      toAccountId: type == 'transfer' ? to : null,
      amount: amt,
      ts: when,
      note: noteC.text.trim(),
    );
    amountC.clear();
    noteC.clear();
    if (!mounted) return;
    setState(() => when = DateTime.now());
    toast(context, 'Transaksi tersimpan');
  }

  Widget _chips(int? sel, ValueChanged<int> on, {int? exclude}) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final a in accs)
            if (a.id != exclude)
              ChoiceChip(
                label: Text(a.name),
                selected: a.id == sel,
                selectedColor: const Color(0x44FFB066),
                onSelected: (_) => on(a.id),
              ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final isTf = type == 'transfer';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
      children: [
        const Text('Catat transaksi', style: kTitle),
        const SizedBox(height: 18),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'in', label: Text('Masuk')),
            ButtonSegment(value: 'out', label: Text('Keluar')),
            ButtonSegment(value: 'transfer', label: Text('Pindah')),
          ],
          selected: {type},
          onSelectionChanged: (s) => setState(() => type = s.first),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: amountC,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
              hintText: '0', prefixText: 'Rp ', helperText: 'Pakai koma untuk desimal'),
        ),
        if (accs.isEmpty) ...[
          const SizedBox(height: 18),
          const GlassCard(child: Text('Belum ada rekening. Tambah dulu di tab Rekening.')),
        ] else ...[
          label(isTf ? 'Dari rekening' : 'Rekening'),
          _chips(from, (id) => setState(() {
                from = id;
                _fixTo();
              })),
          if (isTf) ...[
            label('Ke rekening'),
            _chips(to, (id) => setState(() => to = id), exclude: from),
          ],
        ],
        label('Waktu'),
        GlassCard(
          onTap: _pick,
          child: Row(children: [
            const Icon(Icons.schedule, color: kMuted),
            const SizedBox(width: 10),
            Text(fmtDate(when)),
          ]),
        ),
        label('Catatan (opsional)'),
        TextField(controller: noteC, maxLines: 2, decoration: const InputDecoration(hintText: 'Mis. makan siang')),
        const SizedBox(height: 22),
        SizedBox(
          height: 52,
          child: FilledButton(onPressed: _save, child: const Text('Simpan', style: TextStyle(fontSize: 16))),
        ),
      ],
    );
  }
}

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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
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
