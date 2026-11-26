import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'db.dart';
import 'lock.dart';
import 'ui.dart';

class _ReceiptItem {
  final String name;
  final int price;
  final int qty;
  const _ReceiptItem(this.name, this.price, this.qty);
  int get subtotal => price * qty;
}

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});
  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _customer = TextEditingController();
  final List<_ReceiptItem> _items = [];
  List<Account> _accounts = [];
  int? _accountId;
  bool _saving = false;
  bool _saleCommitted = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _customer.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    final a = await Db.i.accounts();
    if (!mounted) return;
    setState(() {
      _accounts = a;
      _accountId ??= a.isEmpty ? null : a.first.id;
    });
  }

  int get _total => _items.fold(0, (sum, item) => sum + item.subtotal);

  void _addItem() {
    final name = _name.text.trim();
    final price = parseMoney(_price.text);
    if (name.isEmpty || price == null || price <= 0) {
      toast(context, 'Isi nama barang dan harga dengan benar');
      return;
    }
    setState(() {
      _items.add(_ReceiptItem(name, price, 1));
      _name.clear();
      _price.clear();
    });
  }

  Future<Uint8List> _receiptPng() async {
    const width = 720.0;
    final height = 330.0 + (_items.length * 66.0);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    final bg = Paint()..color = const Color(0xFFF8F7F3);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bg);
    final ink = const Color(0xFF172020);
    void draw(String text, double x, double y, double size, {bool bold = false, Color color = const Color(0xFF172020)}) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: color)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width - x - 36);
      tp.paint(canvas, Offset(x, y));
    }
    draw('VIEMOS', 36, 28, 34, bold: true, color: const Color(0xFFB66B2D));
    draw(kEnglish ? 'PURCHASE RECEIPT' : 'STRUK PEMBELIAN', 36, 76, 19, bold: true, color: ink);
    draw('${kEnglish ? 'Date' : 'Tanggal'}: ${DateTime.now().toLocal().toString().substring(0, 16)}', 36, 112, 16, color: const Color(0xFF687474));
    if (_customer.text.trim().isNotEmpty) draw('${kEnglish ? 'Customer' : 'Pelanggan'}: ${_customer.text.trim()}', 36, 140, 16, color: const Color(0xFF687474));
    var y = 190.0;
    canvas.drawLine(const Offset(36, 178), Offset(width - 36, 178), Paint()..color = const Color(0xFFCCD1CB)..strokeWidth = 2);
    for (final item in _items) {
      draw('${item.name}  x${item.qty}', 36, y, 19, bold: true);
      draw('${money(item.subtotal)}', 470, y, 19, bold: true);
      draw('${money(item.price)} / ${kEnglish ? 'item' : 'pcs'}', 36, y + 28, 14, color: const Color(0xFF687474));
      y += 66;
    }
    canvas.drawLine(Offset(36, y), Offset(width - 36, y), Paint()..color = const Color(0xFFCCD1CB)..strokeWidth = 2);
    draw(kEnglish ? 'TOTAL' : 'TOTAL', 36, y + 22, 21, bold: true);
    draw(money(_total), 430, y + 18, 28, bold: true, color: const Color(0xFFB66B2D));
    draw(kEnglish ? 'Thank you for shopping!' : 'Terima kasih telah berbelanja!', 36, y + 82, 17, color: const Color(0xFF687474));
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  Future<void> _finishSale({bool shareReceipt = true}) async {
    if (_saving) return;
    if (_items.isEmpty || _total <= 0) {
      toast(context, kEnglish ? 'Add at least one item' : 'Tambahkan minimal satu barang');
      return;
    }
    if (_accountId == null) {
      toast(context, kEnglish ? 'Add an account first' : 'Tambahkan rekening terlebih dahulu');
      return;
    }
    setState(() => _saving = true);
    try {
      final details = [
        kEnglish ? 'VIEMOS — PURCHASE RECEIPT' : 'VIEMOS — STRUK PEMBELIAN',
        '${kEnglish ? 'Date' : 'Tanggal'}: ${DateTime.now().toLocal()}',
        if (_customer.text.trim().isNotEmpty) '${kEnglish ? 'Customer' : 'Pelanggan'}: ${_customer.text.trim()}',
        '',
        for (final item in _items) '${item.name} x${item.qty} — ${money(item.subtotal)}',
        '',
        'TOTAL: ${money(_total)}',
        kEnglish ? 'Thank you for shopping!' : 'Terima kasih telah berbelanja!',
      ].join('\n');
      if (!_saleCommitted) {
        final itemSummary = _items.map((item) => '${item.name} x${item.qty}: ${money(item.subtotal)}').join('; ');
        final saleNote = '${kEnglish ? 'Cashier sale' : 'Penjualan kasir'}${_customer.text.trim().isEmpty ? '' : ' · ${_customer.text.trim()}'} · $itemSummary';
        await Db.i.addTxn(type: 'in', accountId: _accountId!, amount: _total, ts: DateTime.now(), note: saleNote);
        _saleCommitted = true;
      }
      if (shareReceipt) {
        final bytes = await _receiptPng();
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/viemos-receipt-${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(bytes, flush: true);
        if (!mounted) return;
        Lock.skipNext();
        await Share.shareXFiles([XFile(file.path, mimeType: 'image/png')], text: details, subject: kEnglish ? 'Viemos purchase receipt' : 'Struk pembelian Viemos');
      }
      if (!mounted) return;
      setState(() {
        _items.clear();
        _customer.clear();
        _saleCommitted = false;
      });
      toast(context, shareReceipt ? (kEnglish ? 'Sale saved' : 'Penjualan tersimpan') : (kEnglish ? 'Sale saved without sharing the receipt' : 'Penjualan tersimpan tanpa membagikan struk'));
    } catch (e) {
      if (mounted) {
        if (_saleCommitted) {
          setState(() {
            _items.clear();
            _customer.clear();
            _saleCommitted = false;
          });
          toast(context, kEnglish ? 'Sale was recorded, but the receipt could not be shared.' : 'Penjualan sudah tercatat, tetapi struk gagal dibagikan.');
        } else {
          toast(context, '${kEnglish ? 'Could not save sale' : 'Gagal menyimpan penjualan'}: $e');
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 180),
      children: [
        Text(tr('Mode kasir'), style: kTitle),
        const SizedBox(height: 4),
        Text(tr('Buat transaksi penjualan dan bagikan struk ke pelanggan.'), style: TextStyle(color: kMuted)),
        const SizedBox(height: 16),
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Detail penjualan'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(controller: _customer, decoration: InputDecoration(labelText: tr('Nama pelanggan (opsional)'), hintText: kEnglish ? 'Customer name' : 'Nama pelanggan')),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _accountId,
            decoration: InputDecoration(labelText: tr('Masukkan hasil penjualan ke rekening')),
            items: [for (final a in _accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
            onChanged: (v) => setState(() => _accountId = v),
          ),
        ])),
        const SizedBox(height: 14),
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Tambah barang'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: InputDecoration(labelText: tr('Nama barang / jasa'))),
          const SizedBox(height: 10),
          TextField(controller: _price, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('Harga'), prefixText: 'Rp ')),
          const SizedBox(height: 12),
          AppButton(tr('Tambah ke struk'), onTap: _addItem, icon: Icons.add_rounded),
        ])),
        const SizedBox(height: 14),
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(tr('Item struk'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))), Text('${_items.length} item', style: TextStyle(color: kMuted))]),
          if (_items.isEmpty) Padding(padding: EdgeInsets.symmetric(vertical: 22), child: Center(child: Text(tr('Belum ada barang ditambahkan'), style: TextStyle(color: kMuted)))),
          for (var i = 0; i < _items.length; i++) ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_items[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${money(_items[i].price)} × ${_items[i].qty}'),
            trailing: SizedBox(
              width: 160,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    final item = _items[i];
                    if (item.qty > 1) _items[i] = _ReceiptItem(item.name, item.price, item.qty - 1);
                  }),
                  icon: Icon(Icons.remove_circle_outline_rounded, color: kMuted),
                ),
                Text('${_items[i].qty}', style: TextStyle(fontWeight: FontWeight.w700)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    final item = _items[i];
                    _items[i] = _ReceiptItem(item.name, item.price, item.qty + 1);
                  }),
                  icon: Icon(Icons.add_circle_outline_rounded, color: kOrange),
                ),
                IconButton(onPressed: () => setState(() => _items.removeAt(i)), icon: Icon(Icons.close_rounded, color: kOut)),
              ]),
            ),
          ),
          Divider(color: kBorder),
          Row(children: [Expanded(child: Text(tr('Total'), style: TextStyle(fontWeight: FontWeight.w700))), Text(money(_total), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kOrange))]),
          const SizedBox(height: 14),
          AppButton(_saving ? 'Menyimpan...' : tr('Simpan penjualan'), onTap: _saving ? () {} : () => _finishSale(shareReceipt: false), icon: Icons.check_rounded),
          const SizedBox(height: 8),
          AppButton(_saving ? 'Menyiapkan struk...' : tr('Simpan & bagikan struk'), onTap: _saving ? () {} : () => _finishSale(shareReceipt: true), icon: Icons.share_rounded),
          const SizedBox(height: 6),
          Text(tr('Pilih WhatsApp dari menu berbagi Android untuk mengirim gambar dan detail struk.'), style: TextStyle(color: kMuted, fontSize: 12)),
        ])),
      ],
    );
  }
}
