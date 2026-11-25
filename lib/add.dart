import 'package:flutter/material.dart';
import 'db.dart';
import 'sfx.dart';
import 'ui.dart';

class AddTxnScreen extends StatelessWidget {
  const AddTxnScreen({super.key});

  static const _names = {
    'in': 'Pemasukan',
    'out': 'Pengeluaran',
    'transfer': 'Pindah saldo',
  };

  Future<void> _open(BuildContext context, String type) async {
    final accs = await Db.i.accounts();
    if (!context.mounted) return;
    if (accs.isEmpty) {
      toast(context, 'Tambah rekening dulu di tab Rekening');
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF111718),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => TxnSheet(type: type, accounts: accs),
    );
    if (saved == true && context.mounted) {
      toast(context, '${_names[type]} tersimpan');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Catat transaksi', style: kTitle),
          const SizedBox(height: 6),
          const Text('Pilih jenis transaksi', style: TextStyle(color: kMuted)),
          Expanded(
            child: Align(
              alignment: const Alignment(0, 0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAction(
                    icon: Icons.south_west_rounded,
                    label: 'Pemasukan',
                    color: kIn,
                    onTap: () => _open(context, 'in'),
                  ),
                  CircleAction(
                    icon: Icons.north_east_rounded,
                    label: 'Pengeluaran',
                    color: kOut,
                    onTap: () => _open(context, 'out'),
                  ),
                  CircleAction(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Pindah saldo',
                    color: kOrange,
                    onTap: () => _open(context, 'transfer'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CircleAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const CircleAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<CircleAction> createState() => _CircleActionState();
}

class _CircleActionState extends State<CircleAction> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  bool _down = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _fire() async {
    Sfx.pop();
    _c.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 140));
    if (mounted) widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final col = widget.color;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: _fire,
      child: SizedBox(
        width: 100,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  AnimatedBuilder(
                    animation: _c,
                    builder: (_, __) {
                      final t = Curves.easeOut.transform(_c.value);
                      return Opacity(
                        opacity: _c.value == 0 ? 0 : (1 - t),
                        child: Container(
                          width: 80 + 28 * t,
                          height: 80 + 28 * t,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: col, width: 2),
                          ),
                        ),
                      );
                    },
                  ),
                  AnimatedScale(
                    scale: _down ? 0.9 : 1,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: col.withAlpha(36),
                        border: Border.all(color: col, width: 2.5),
                        boxShadow: [BoxShadow(color: col.withAlpha(60), blurRadius: 24, spreadRadius: 1)],
                      ),
                      child: Icon(widget.icon, color: col, size: 34),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText),
            ),
          ],
        ),
      ),
    );
  }
}

class TxnSheet extends StatefulWidget {
  final String type;
  final List<Account> accounts;
  const TxnSheet({super.key, required this.type, required this.accounts});

  @override
  State<TxnSheet> createState() => _TxnSheetState();
}

class _TxnSheetState extends State<TxnSheet> {
  late int from = widget.accounts.first.id;
  int? to;
  final amountC = TextEditingController();
  final noteC = TextEditingController();
  DateTime when = DateTime.now();
  String? err;
  bool _busy = false;

  Color get _c => widget.type == 'in' ? kIn : (widget.type == 'out' ? kOut : kOrange);
  IconData get _ic => widget.type == 'in'
      ? Icons.south_west_rounded
      : (widget.type == 'out' ? Icons.north_east_rounded : Icons.swap_horiz_rounded);
  String get _title => widget.type == 'in'
      ? 'Pemasukan'
      : (widget.type == 'out' ? 'Pengeluaran' : 'Pindah saldo');

  @override
  void initState() {
    super.initState();
    _fixTo();
  }

  @override
  void dispose() {
    amountC.dispose();
    noteC.dispose();
    super.dispose();
  }

  void _fixTo() {
    final o = widget.accounts.where((a) => a.id != from);
    if (to == null || to == from) to = o.isEmpty ? null : o.first.id;
  }

  Future<void> _pick() async {
    final d = await showDatePicker(
      context: context,
      initialDate: when,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(when));
    if (t == null) return;
    setState(() => when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (_busy) return;
    final amt = parseMoney(amountC.text);
    if (amt == null || amt <= 0) {
      setState(() => err = 'Isi jumlah dengan benar');
      return;
    }
    if (widget.type == 'transfer' && (to == null || to == from)) {
      setState(() => err = 'Pilih rekening tujuan yang berbeda');
      return;
    }
    _busy = true;
    await Db.i.addTxn(
      type: widget.type,
      accountId: from,
      toAccountId: widget.type == 'transfer' ? to : null,
      amount: amt,
      ts: when,
      note: noteC.text.trim(),
    );
    Sfx.ok();
    if (mounted) Navigator.pop(context, true);
  }

  Widget _lbl(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(t, style: const TextStyle(color: kMuted, fontSize: 13)),
      );

  Widget _chips(int? sel, ValueChanged<int> on, {int? exclude}) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final a in widget.accounts)
            if (a.id != exclude)
              ChoiceChip(
                label: Text(a.name),
                selected: a.id == sel,
                selectedColor: _c.withAlpha(70),
                onSelected: (_) {
                  Sfx.tap();
                  on(a.id);
                },
              ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final isTf = widget.type == 'transfer';
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _c.withAlpha(40)),
                child: Icon(_ic, color: _c),
              ),
              const SizedBox(width: 12),
              Text(_title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: amountC,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: '0',
                prefixText: 'Rp ',
                prefixStyle: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: _c),
                helperText: 'Pakai koma untuk desimal',
              ),
            ),
            _lbl(isTf ? 'Dari rekening' : 'Rekening'),
            _chips(from, (id) => setState(() {
                  from = id;
                  _fixTo();
                })),
            if (isTf) ...[
              _lbl('Ke rekening'),
              _chips(to, (id) => setState(() => to = id), exclude: from),
            ],
            _lbl('Waktu'),
            GlassCard(
              onTap: _pick,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                const Icon(Icons.schedule, color: kMuted, size: 20),
                const SizedBox(width: 10),
                Text(fmtDate(when)),
              ]),
            ),
            _lbl('Catatan (opsional)'),
            TextField(controller: noteC, decoration: const InputDecoration(hintText: 'Mis. makan siang')),
            if (err != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(err!, style: const TextStyle(color: kOut)),
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _c, foregroundColor: Colors.black),
                onPressed: _save,
                child: const Text('Simpan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
