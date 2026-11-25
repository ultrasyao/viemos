import 'package:flutter/material.dart';
import 'db.dart';
import 'money_input.dart';
import 'sfx.dart';
import 'ui.dart';

const _names = {'in': 'Pemasukan', 'out': 'Pengeluaran', 'transfer': 'Pindah saldo'};

Color _accent(String t) => t == 'in' ? kIn : (t == 'out' ? kOut : kOrange);
IconData _icon(String t) => t == 'in'
    ? Icons.south_west_rounded
    : (t == 'out' ? Icons.north_east_rounded : Icons.swap_horiz_rounded);

Future<void> showTxnDialog(BuildContext context, String type) async {
  final accs = await Db.i.accounts();
  if (!context.mounted) return;
  if (accs.isEmpty) {
    toast(context, 'Tambah rekening dulu di tab Rekening');
    return;
  }
  final saved = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup',
    barrierColor: Colors.black.withAlpha(150),
    transitionDuration: const Duration(milliseconds: 700),
    pageBuilder: (_, __, ___) => TxnDialog(type: type, accounts: accs),
    transitionBuilder: (ctx, a, __, child) {
      final mq = MediaQuery.of(ctx);
      final v = a.value;
      final dropC = Curves.easeOutBack.transform(const Interval(0.0, 0.4).transform(v));
      final grow =
          Curves.easeInOutCubic.transform(const Interval(0.36, 1.0).transform(v));
      final pillOp = const Interval(0.0, 0.15).transform(v) *
          (1 - const Interval(0.0, 0.5).transform(grow));
      final pillTop = mq.padding.top + 14;
      return Stack(
        children: [
          Positioned(
            top: -70 + (pillTop + 70) * dropC,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Opacity(
                  opacity: pillOp.clamp(0.0, 1.0).toDouble(),
                  child: Transform.scale(
                    scale: 1 + 0.12 * grow,
                    child: _Pill(type: type),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
              child: SafeArea(
                child: Align(
                  alignment: Alignment(0, -0.9 + 0.9 * grow),
                  child: Opacity(
                    opacity: const Interval(0.15, 0.7).transform(grow),
                    child: Transform.scale(
                      scale: 0.45 + 0.55 * Curves.easeOutCubic.transform(grow),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
  if (saved == true && context.mounted) {
    toast(context, '${_names[type]} tersimpan');
  }
}

class _Pill extends StatelessWidget {
  final String type;
  const _Pill({required this.type});

  @override
  Widget build(BuildContext context) {
    final c = _accent(type);
    return Material(
      color: const Color(0xFF111718),
      elevation: 10,
      shadowColor: c,
      shape: StadiumBorder(side: BorderSide(color: c.withAlpha(140), width: 1.5)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 22, 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon(type), color: c, size: 22),
            const SizedBox(width: 10),
            Text(_names[type]!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class TxnDialog extends StatefulWidget {
  final String type;
  final List<Account> accounts;
  const TxnDialog({super.key, required this.type, required this.accounts});

  @override
  State<TxnDialog> createState() => _TxnDialogState();
}

class _TxnDialogState extends State<TxnDialog> {
  late int from = widget.accounts.first.id;
  int? to;
  final amountC = TextEditingController();
  final noteC = TextEditingController();
  final amountF = FocusNode();
  DateTime when = DateTime.now();
  String? err;
  bool _busy = false;

  Color get _c => _accent(widget.type);

  @override
  void initState() {
    super.initState();
    _fixTo();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) amountF.requestFocus();
    });
  }

  @override
  void dispose() {
    amountC.dispose();
    noteC.dispose();
    amountF.dispose();
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
                  Sfx.click();
                  on(a.id);
                },
              ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final isTf = widget.type == 'transfer';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SizedBox(
          width: double.infinity,
          child: Material(
            color: const Color(0xFF111718),
            elevation: 12,
            shadowColor: _c,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: _c.withAlpha(90)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: _c.withAlpha(40)),
                        child: Icon(_icon(widget.type), color: _c),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_names[widget.type]!,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        onPressed: () {
                          Sfx.click();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close_rounded, color: kMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountC,
                    focusNode: amountF,
                    inputFormatters: [MoneyFormatter()],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: '0',
                      prefixText: 'Rp ',
                      prefixStyle: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: _c),
                      helperText: 'Koma untuk desimal',
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
                    onTap: () {
                      Sfx.click();
                      _pick();
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      const Icon(Icons.schedule, color: kMuted, size: 20),
                      const SizedBox(width: 10),
                      Text(fmtDate(when)),
                    ]),
                  ),
                  _lbl('Catatan (opsional)'),
                  TextField(
                    controller: noteC,
                    decoration: const InputDecoration(hintText: 'Mis. makan siang'),
                  ),
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
                      onPressed: () {
                        Sfx.click();
                        _save();
                      },
                      child: const Text('Simpan',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
