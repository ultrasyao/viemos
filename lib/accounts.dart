import 'package:flutter/material.dart';
import 'app_dialog.dart';
import 'db.dart';
import 'money_input.dart';
import 'sfx.dart';
import 'ui.dart';

class _Preset {
  final String name, kind;
  final int color;
  const _Preset(this.name, this.kind, this.color);
}

const _presets = [
  _Preset('Tunai', 'cash', 0xFF7BE0A8),
  _Preset('BCA', 'bank', 0xFF5AA9FF),
  _Preset('BRI', 'bank', 0xFF6CB6FF),
  _Preset('BNI', 'bank', 0xFFFFB066),
  _Preset('Mandiri', 'bank', 0xFFFFD36B),
  _Preset('BSI', 'bank', 0xFF7BE0C8),
  _Preset('Jago', 'bank', 0xFFFFC857),
  _Preset('SeaBank', 'bank', 0xFFFF9B7A),
  _Preset('DANA', 'ewallet', 0xFF5AA9FF),
  _Preset('OVO', 'ewallet', 0xFFB48CFF),
  _Preset('GoPay', 'ewallet', 0xFF6EE7A8),
  _Preset('ShopeePay', 'ewallet', 0xFFFF8F85),
  _Preset('LinkAja', 'ewallet', 0xFFFF7A7A),
];

IconData _kindIcon(String k) => k == 'cash'
    ? Icons.payments_outlined
    : k == 'bank'
        ? Icons.account_balance_outlined
        : Icons.account_balance_wallet_outlined;

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});
  @override
  State<AccountsScreen> createState() => _AccountsState();
}

class _AccountsState extends State<AccountsScreen> {
  List<Account> accs = [];

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
    final a = await Db.i.accounts();
    if (mounted) setState(() => accs = a);
  }

  Future<void> _confirmDelete(Account a) async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus ${a.name}?',
      message: 'Semua transaksi di rekening ini ikut terhapus.',
      confirmText: 'Hapus',
      danger: true,
    );
    if (ok) await Db.i.deleteAccount(a.id);
  }

  void _add() => showAppDialog<void>(context, builder: (_) => const _AddAccount());

  @override
  Widget build(BuildContext context) {
    final total = accs.fold<int>(0, (s, a) => s + a.balance);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 190),
      children: [
        const Text('Rekening', style: kTitle),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total saldo', style: TextStyle(color: kMuted)),
              const SizedBox(height: 6),
              Text(money(total), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final a in accs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Color(a.color).withAlpha(40),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_kindIcon(a.kind), color: Color(a.color)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(a.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                  Text(money(a.balance), style: const TextStyle(fontWeight: FontWeight.w600)),
                  Bounce(
                    onTap: () => _confirmDelete(a),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.delete_outline, color: kMuted, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (accs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Belum ada rekening', style: TextStyle(color: kMuted))),
          ),
        const SizedBox(height: 6),
        AppButton('Tambah rekening', icon: Icons.add, outlined: true, onTap: _add),
      ],
    );
  }
}


class _AddAccount extends StatefulWidget {
  const _AddAccount();
  @override
  State<_AddAccount> createState() => _AddAccountState();
}

class _AddAccountState extends State<_AddAccount> {
  final nameC = TextEditingController();
  final balC = TextEditingController();
  var kind = 'cash';
  var color = _presets.first.color;

  @override
  void dispose() {
    nameC.dispose();
    balC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = nameC.text.trim();
    if (n.isEmpty) return;
    await Db.i.addAccount(n, kind, parseMoney(balC.text) ?? 0, color);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Tambah rekening',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              Bounce(
                onTap: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.close_rounded, color: kMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in _presets)
              ActionChip(
                label: Text(p.name),
                onPressed: () {
                  Sfx.click();
                  setState(() {
                    nameC.text = p.name;
                    kind = p.kind;
                    color = p.color;
                  });
                },
              ),
          ]),
          const SizedBox(height: 14),
          TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama rekening')),
          const SizedBox(height: 10),
          TextField(
            controller: balC,
            inputFormatters: [MoneyFormatter()],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Saldo awal (opsional)', prefixText: 'Rp '),
          ),
          const SizedBox(height: 18),
          AppButton('Simpan', onTap: _save),
        ],
      ),
    );
  }
}
