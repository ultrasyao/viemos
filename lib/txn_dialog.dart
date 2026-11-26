import 'package:flutter/material.dart';
import 'app_dialog.dart';
import 'db.dart';
import 'island.dart';
import 'money_input.dart';
import 'sfx.dart';
import 'ui.dart';

const _names = {'in': 'Pemasukan', 'out': 'Pengeluaran', 'transfer': 'Pindah saldo'};

Color _accent(String t) => t == 'in' ? kIn : (t == 'out' ? kOut : kOrange);
IconData _icon(String t) => t == 'in'
    ? Icons.south_west_rounded
    : (t == 'out' ? Icons.north_east_rounded : Icons.swap_horiz_rounded);

/// Buka popup catat transaksi. Kalau [edit] diisi, popup jadi mode ubah
/// untuk transaksi itu (jenis, rekening, jumlah, waktu & catatan bisa diganti).
Future<void> showTxnDialog(BuildContext context, String type, {Txn? edit}) async {
  final accs = await Db.i.accounts();
  if (!context.mounted) return;
  if (accs.isEmpty) {
    toast(context, 'Tambah rekening dulu di tab Rekening');
    return;
  }
  final saved = await showAppDialog<SavedTxn>(
    context,
    accent: _accent(type),
    builder: (_) => TxnDialog(type: type, accounts: accs, edit: edit),
  );
  if (saved != null && context.mounted) {
    if (saved.deleted) {
      showIsland(
        context,
        title: 'Transaksi dihapus',
        subtitle: 'Riwayat dan saldo rekening telah diperbarui',
        amount: money(saved.amount),
        icon: Icons.delete_outline_rounded,
        color: kOut,
        sound: 'out',
      );
      return;
    }
    final isTf = saved.type == 'transfer';
    final where = isTf ? '${saved.from} → ${saved.to ?? '?'}' : saved.from;
    final sub = saved.note.isEmpty ? where : '$where · ${saved.note}';
    final sign = saved.type == 'in' ? '+' : (saved.type == 'out' ? '-' : '');
    showIsland(
      context,
      title: saved.edited ? 'Perubahan tersimpan' : '${_names[saved.type]} tersimpan',
      subtitle: sub,
      amount: '$sign${money(saved.amount)}',
      icon: saved.edited ? Icons.edit_rounded : _icon(saved.type),
      color: _accent(saved.type),
      sound: saved.type,
    );
  }
}

class SavedTxn {
  final String type, from, note;
  final String? to;
  final int amount;
  final bool edited, deleted;
  const SavedTxn(this.type, this.from, this.to, this.amount, this.note,
      {this.edited = false, this.deleted = false});
}

class TxnDialog extends StatefulWidget {
  final String type;
  final List<Account> accounts;
  final Txn? edit;
  const TxnDialog({super.key, required this.type, required this.accounts, this.edit});

  @override
  State<TxnDialog> createState() => _TxnDialogState();
}

class _TxnDialogState extends State<TxnDialog> {
  late String type = widget.edit?.type ?? widget.type;
  late int from = _initialFrom();
  int? to;
  late final amountC = TextEditingController(
      text: widget.edit == null ? '' : moneyInput(widget.edit!.amount));
  late final noteC = TextEditingController(text: widget.edit?.note ?? '');
  bool _keypadOpen = false;
  late DateTime when = widget.edit?.ts ?? DateTime.now();
  String? err;
  bool _busy = false;

  bool get _isEdit => widget.edit != null;
  Color get _c => _accent(type);

  int _initialFrom() {
    final e = widget.edit;
    if (e != null && widget.accounts.any((a) => a.id == e.accountId)) return e.accountId;
    return widget.accounts.first.id;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null && e.toAccountId != null && widget.accounts.any((a) => a.id == e.toAccountId)) {
      to = e.toAccountId;
    }
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

  void _setAmountKey(String key) {
    final current = amountC.text;
    var raw = current.replaceAll('.', '');
    if (key == '⌫') {
      if (raw.isNotEmpty) raw = raw.substring(0, raw.length - 1);
    } else if (key == 'C') {
      raw = '';
    } else if (key == ',') {
      if (raw.contains(',')) return;
      raw = raw.isEmpty ? '0,' : '$raw,';
    } else {
      final comma = raw.indexOf(',');
      if (comma >= 0 && raw.length - comma - 1 >= 2) return;
      if (raw == '0') {
        raw = key;
      } else {
        raw += key;
      }
    }
    final formatted = MoneyFormatter().formatEditUpdate(
      TextEditingValue(text: current, selection: TextSelection.collapsed(offset: current.length)),
      TextEditingValue(text: raw, selection: TextSelection.collapsed(offset: raw.length)),
    );
    setState(() {
      amountC.value = formatted;
      _keypadOpen = true;
      err = null;
    });
  }

  Future<void> _openAmountKeyboard() async {
    if (_keypadOpen) return;
    _keypadOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (sheetContext) {
        const rows = [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          [',', '0', '⌫'],
        ];
        Widget key(String value) {
          final special = value == '⌫' || value == ',';
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Material(
                color: special ? _c.withAlpha(28) : kCard,
                borderRadius: BorderRadius.circular(13),
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: () {
                    Sfx.click();
                    _setAmountKey(value);
                  },
                  child: SizedBox(
                    height: 48,
                    child: Center(
                      child: value == '⌫'
                          ? Icon(Icons.backspace_outlined, color: _c, size: 20)
                          : Text(value, style: TextStyle(color: special ? _c : kText, fontSize: 19, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _c.withAlpha(100)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(child: Text(tr('Keypad Viemos'), style: TextStyle(fontWeight: FontWeight.w700, color: kText))),
                  IconButton(onPressed: () => Navigator.pop(sheetContext), icon: Icon(Icons.keyboard_hide_rounded, color: kMuted)),
                ]),
                for (final row in rows) Row(children: [for (final value in row) key(value)]),
                Row(children: [
                  Expanded(child: TextButton.icon(onPressed: () => _setAmountKey('C'), icon: Icon(Icons.clear_rounded, size: 17), label: Text(tr('Bersihkan')), style: TextButton.styleFrom(foregroundColor: kMuted))),
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(sheetContext), child: Text(tr('Selesai'), style: TextStyle(color: _c)))),
                ]),
              ],
            ),
          ),
        );
      },
    );
    _keypadOpen = false;
  }

  Future<void> _delete() async {
    if (_busy || widget.edit == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Hapus transaksi?',
      message: 'Transaksi ini akan dihapus permanen dan saldo rekening akan dihitung ulang.',
      confirmText: 'Hapus',
      danger: true,
    );
    if (!ok || !mounted) return;
    _busy = true;
    await Db.i.deleteTxn(widget.edit!.id);
    if (!mounted) return;
    Navigator.pop(
      context,
      SavedTxn(type, '', null, widget.edit!.amount, '', deleted: true),
    );
  }

  Future<void> _save() async {
    if (_busy) return;
    final amt = parseMoney(amountC.text);
    if (amt == null || amt <= 0) {
      setState(() => err = 'Isi jumlah dengan benar');
      return;
    }
    final isTf = type == 'transfer';
    if (isTf && (to == null || to == from)) {
      setState(() => err = 'Pilih rekening tujuan yang berbeda');
      return;
    }
    _busy = true;
    final note = noteC.text.trim();
    if (_isEdit) {
      await Db.i.updateTxn(
        id: widget.edit!.id,
        type: type,
        accountId: from,
        toAccountId: isTf ? to : null,
        amount: amt,
        ts: when,
        note: note,
      );
    } else {
      await Db.i.addTxn(
        type: type,
        accountId: from,
        toAccountId: isTf ? to : null,
        amount: amt,
        ts: when,
        note: note,
      );
    }
    if (!mounted) return;
    String nameOf(int id) => widget.accounts.firstWhere((a) => a.id == id).name;
    Navigator.pop(
      context,
      SavedTxn(type, nameOf(from), isTf && to != null ? nameOf(to!) : null, amt, note,
          edited: _isEdit),
    );
  }

  Widget _lbl(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(tr(t), style: TextStyle(color: kMuted, fontSize: 13)),
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

  Widget _typeTabs() => Row(
        children: [
          for (final t in const ['in', 'out', 'transfer'])
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: t == 'transfer' ? 0 : 8),
                child: Bounce(
                  onTap: () => setState(() {
                    type = t;
                    err = null;
                    _fixTo();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: type == t ? _accent(t).withAlpha(46) : kCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: type == t ? _accent(t) : kBorder),
                    ),
                    child: Column(
                      children: [
                        Icon(_icon(t), size: 18, color: type == t ? _accent(t) : kMuted),
                        const SizedBox(height: 3),
                        Text(tr(_names[t]!),
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: type == t ? _accent(t) : kMuted)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final isTf = type == 'transfer';
    return AppPanel(
      accent: _c,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 40,
                height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _c.withAlpha(40)),
                child: Icon(_icon(type), color: _c),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_isEdit ? tr('Ubah transaksi') : tr(_names[type]!),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              if (_isEdit)
                Bounce(
                  onTap: _delete,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.delete_outline_rounded, color: kOut),
                  ),
                ),
              Bounce(
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.close_rounded, color: kMuted),
                ),
              ),
            ],
          ),
          if (_isEdit) ...[
            const SizedBox(height: 14),
            _typeTabs(),
          ],
          const SizedBox(height: 14),
          // Prefix dipisah dari TextField agar "Rp" selalu terlihat,
          // termasuk saat jumlah masih kosong dan field belum disentuh.
          Material(
            color: kCard,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _openAmountKeyboard,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorder),
                ),
                child: Row(
                  children: [
                    Text('Rp', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700, color: _c)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: IgnorePointer(
                        child: TextField(
                          controller: amountC,
                          readOnly: true,
                          showCursor: false,
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: kText),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: TextStyle(color: kMuted.withAlpha(150)),
                            border: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    Icon(Icons.dialpad_rounded, color: kMuted, size: 20),
                  ],
                ),
              ),
            ),
          ),
          _lbl(isTf ? 'Dari rekening' : tr('Rekening')),
          _chips(from, (id) => setState(() {
                from = id;
                _fixTo();
              })),
          if (isTf) ...[
            _lbl('Ke rekening'),
            _chips(to, (id) => setState(() => to = id), exclude: from),
          ],
          _lbl(tr('Waktu')),
          GlassCard(
            onTap: _pick,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Icon(Icons.schedule, color: kMuted, size: 20),
              const SizedBox(width: 10),
              Text(fmtDate(when)),
            ]),
          ),
          _lbl(tr('Catatan (opsional)')),
          TextField(
            controller: noteC,
            decoration: InputDecoration(hintText: kEnglish ? 'E.g. lunch, transport, groceries' : 'Contoh: Makan siang, transportasi, belanja',
              hintStyle: TextStyle(color: kMuted.withAlpha(190))),
          ),
          if (err != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(err!, style: TextStyle(color: kOut)),
            ),
          const SizedBox(height: 18),
          AppButton(_isEdit ? tr('Simpan perubahan') : tr('Simpan'), color: _c, onTap: _save),
        ],
      ),
    );
  }
}
