import 'strings.dart';
import 'package:flutter/material.dart';
import 'app_dialog.dart';
import 'db.dart';
import 'island.dart';
import 'kb.dart';
import 'money_input.dart';
import 'sfx.dart';
import 'ui.dart';

Map<String, String> get _names => {'in': tr('Pemasukan'), 'out': tr('Pengeluaran'), 'transfer': tr('Pindah saldo')};

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
    toast(context, tr('Tambah rekening dulu di tab Rekening'));
    return;
  }
  final saved = await showAppDialog<SavedTxn>(
    context,
    accent: _accent(type),
    builder: (_) => TxnDialog(type: type, accounts: accs, edit: edit),
  );
  if (saved != null && context.mounted) {
    final isTf = saved.type == 'transfer';
    final where = isTf ? '${saved.from} → ${saved.to ?? '?'}' : saved.from;
    final sub = saved.note.isEmpty ? where : '$where · ${saved.note}';
    final sign = saved.type == 'in' ? '+' : (saved.type == 'out' ? '-' : '');
    if (saved.deleted) {
      showIsland(
        context,
        title: tr('Transaksi dihapus'),
        subtitle: sub,
        amount: '$sign${money(saved.amount)}',
        icon: Icons.delete_outline_rounded,
        color: kOut,
        sound: 'out',
      );
      return;
    }
    showIsland(
      context,
      title: saved.edited ? tr('Perubahan tersimpan') : trf('{n} tersimpan', {'n': _names[saved.type]}),
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
  final bool edited;
  final bool deleted;
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
  late final amountC = InputCtl(
      money: true, text: widget.edit == null ? '' : moneyInput(widget.edit!.amount));
  late final noteC = InputCtl(maxLen: 60, text: widget.edit?.note ?? '');
  final _amountKey = GlobalKey();
  final _noteKey = GlobalKey();
  InputCtl? _active;
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
    if (!_isEdit) {
      // transaksi baru: langsung siap ketik nominal
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted && _active == null) _focus(amountC, _amountKey);
      });
    }
  }

  /// Pindahkan keyboard Viemos ke kolom [c] dan gulir kolomnya ke tempat terlihat.
  void _focus(InputCtl? c, [GlobalKey? k]) {
    if (c == null) {
      Kb.close();
      return;
    }
    setState(() => _active = c);
    Kb.open(context, c, accent: _c, onClosed: () {
      if (mounted) setState(() => _active = null);
    });
    if (k == null) return;
    Future.delayed(const Duration(milliseconds: 340), () {
      final ctx = k.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.04,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    // tutup keyboard sesudah frame ini (tidak boleh ubah state saat dispose)
    WidgetsBinding.instance.addPostFrameCallback((_) => Kb.close(notify: false));
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
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(when),
      initialEntryMode: TimePickerEntryMode.dialOnly,
    );
    if (t == null) return;
    setState(() => when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (_busy) return;
    final amt = parseMoney(amountC.text);
    if (amt == null || amt <= 0) {
      setState(() => err = tr('Isi jumlah dengan benar'));
      return;
    }
    final isTf = type == 'transfer';
    if (isTf && (to == null || to == from)) {
      setState(() => err = tr('Pilih rekening tujuan yang berbeda'));
      return;
    }
    _busy = true;
    Kb.close(notify: false);
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

  Future<void> _delete() async {
    final e = widget.edit;
    if (_busy || e == null) return;
    Kb.close();
    final ok = await confirmDialog(
      context,
      title: tr('Hapus transaksi?'),
      message: tr('Transaksi ini dihapus permanen dan saldo rekening ikut berubah.'),
      confirmText: tr('Hapus'),
      danger: true,
    );
    if (!ok || !mounted) return;
    _busy = true;
    await Db.i.deleteTxn(e.id);
    if (!mounted) return;
    String nameOf(int id) {
      for (final a in widget.accounts) {
        if (a.id == id) return a.name;
      }
      return e.accName;
    }

    Navigator.pop(
      context,
      SavedTxn(e.type, nameOf(e.accountId), e.toAccountId == null ? null : nameOf(e.toAccountId!),
          e.amount, e.note,
          deleted: true),
    );
  }

  Widget _lbl(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(t, style: TextStyle(color: kMuted, fontSize: 13)),
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
                        Text(_names[t]!,
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
    return PopScope(
      // tombol back: tutup keyboard Viemos dulu, baru popup
      canPop: _active == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _active != null) Kb.close();
      },
      child: AppPanel(
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
                  child: Text(_isEdit ? tr('Ubah transaksi') : _names[type]!,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                Bounce(
                  onTap: () {
                    Kb.close(notify: false);
                    Navigator.pop(context);
                  },
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
            KbField(
              key: _amountKey,
              ctl: amountC,
              active: _active == amountC,
              onTap: () => _focus(amountC, _amountKey),
              hint: '0',
              prefix: 'Rp',
              accent: _c,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              helper: tr('Koma untuk desimal'),
            ),
            _lbl(isTf ? tr('Dari rekening') : tr('Rekening')),
            _chips(from, (id) => setState(() {
                  from = id;
                  _fixTo();
                })),
            if (isTf) ...[
              _lbl(tr('Ke rekening')),
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
            KbField(
              key: _noteKey,
              ctl: noteC,
              active: _active == noteC,
              onTap: () => _focus(noteC, _noteKey),
              hint: tr('Mis. makan siang'),
              accent: _c,
              maxLines: 2,
            ),
            if (err != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(err!, style: TextStyle(color: kOut)),
              ),
            const SizedBox(height: 18),
            if (_isEdit)
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: AppButton(tr('Hapus'),
                        outlined: true,
                        fg: kOut,
                        icon: Icons.delete_outline_rounded,
                        onTap: _delete),
                  ),
                  const SizedBox(width: 10),
                  Expanded(flex: 3, child: AppButton(tr('Simpan'), color: _c, onTap: _save)),
                ],
              )
            else
              AppButton(tr('Simpan'), color: _c, onTap: _save),
          ],
        ),
      ),
    );
  }
}
