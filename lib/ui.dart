import 'package:flutter/material.dart';
import 'island.dart';
import 'sfx.dart';

const kOrange = Color(0xFFFFB066);
const kGlow = Color(0x38FFB066);
bool kDarkMode = true;
bool kEnglish = false;
Color get kCard => kDarkMode ? const Color(0xFF151C1D) : const Color(0xFFFFFFFF);
Color get kBorder => kDarkMode ? const Color(0xFF2A3335) : const Color(0xFFE1E5E2);
const kIn = Color(0xFF7BE0A8);
const kOut = Color(0xFFFF8F85);
Color get kText => kDarkMode ? const Color(0xFFE6EEEE) : const Color(0xFF172020);
Color get kMuted => kDarkMode ? const Color(0xFF8A9A9C) : const Color(0xFF687474);
TextStyle get kTitle => TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: kText);

String tr(String id) {
  if (!kEnglish) return id;
  const map = <String, String>{
    'Catat transaksi': 'Record transactions', 'Rekening': 'Accounts', 'Riwayat': 'History',
    'Rekap': 'Summary', 'Setting': 'Settings', 'Hari ini': 'Today', 'Total saldo': 'Total balance',
    'Masuk': 'Income', 'Keluar': 'Expense', 'Pindah saldo': 'Transfer',
    'Pemasukan': 'Income', 'Pengeluaran': 'Expense', 'Catatan (opsional)': 'Note (optional)',
    'Waktu': 'Date & time', 'Simpan': 'Save', 'Simpan perubahan': 'Save changes',
    'Ubah transaksi': 'Edit transaction', 'Hapus transaksi?': 'Delete transaction?',
    'Belum ada rekening': 'No accounts yet', 'Belum ada transaksi': 'No transactions yet',
    'Belum ada transaksi hari ini': 'No transactions today', 'Ketuk tombol pensil di kanan bawah': 'Tap the pencil button at the bottom right',
    'Nama barang / jasa': 'Product / service name', 'Harga': 'Price', 'Tambah ke struk': 'Add to receipt',
    'Mode kasir': 'Cashier mode', 'Mode transaksi': 'Transaction mode', 'Detail penjualan': 'Sale details',
    'Nama pelanggan (opsional)': 'Customer name (optional)', 'Item struk': 'Receipt items',
    'Simpan penjualan': 'Save sale', 'Simpan & bagikan struk': 'Save & share receipt',
    'Keypad Viemos': 'Viemos keypad', 'Bersihkan': 'Clear', 'Selesai': 'Done',
    'Tampilan': 'Appearance', 'Mode tampilan': 'Appearance mode', 'Gelap': 'Dark', 'Terang': 'Light',
    'Bahasa aplikasi': 'App language', 'Bahasa / Language': 'Language', 'Tema aplikasi': 'App theme', 'Keamanan': 'Security', 'Backup & data': 'Backup & data',
    'Dari rekening': 'From account', 'Ke rekening': 'To account',
    'Pilih WhatsApp dari menu berbagi Android untuk mengirim gambar dan detail struk.': 'Choose WhatsApp from the Android share menu to send the receipt image and details.',
    'Buat transaksi penjualan dan bagikan struk ke pelanggan.': 'Record a sale and share the receipt with your customer.',
    'Tambah barang': 'Add item', 'Masukkan hasil penjualan ke rekening': 'Deposit sale into account',
    'Belum ada barang ditambahkan': 'No items added yet', 'Total': 'Total',
    'Kunci PIN': 'PIN lock', 'Ubah PIN': 'Change PIN', 'Kunci otomatis': 'Auto lock', 'Kunci sekarang': 'Lock now',
    'Pengingat': 'Reminders', 'Pengingat harian': 'Daily reminder', 'Ingatkan catat transaksi': 'Remind me to record transactions',
    'Jam pengingat': 'Reminder time', 'Tes notifikasi': 'Test notification', 'Backup': 'Backup', 'Download backup': 'Download backup',
    'Simpan file .json ke HP — pilih folder Download': 'Save the .json file to your phone — choose the Downloads folder',
    'Backup otomatis': 'Automatic backup', 'Folder backup': 'Backup folder', 'Backup sekarang': 'Back up now',
    'Bagikan backup': 'Share backup', 'Backup ke clipboard': 'Copy backup to clipboard', 'Pulihkan': 'Restore',
    'Pulihkan dari file': 'Restore from file', 'Mengganti semua data sekarang': 'Replaces all current data',
    'Pulihkan backup otomatis': 'Restore automatic backup', 'Dari folder backup terakhir': 'From the latest backup folder',
    'Pulihkan dari clipboard': 'Restore from clipboard', 'Data': 'Data', 'Ekspor CSV': 'Export CSV',
    'Untuk dibuka di Excel / Sheets': 'For Excel / Sheets', 'Hapus semua data': 'Delete all data',
    'Tampilan & suara': 'Appearance & sound', 'Suara': 'Sound', 'Klik & notifikasi transaksi': 'Clicks & transaction notifications',
    'Getar': 'Haptics', 'Saat transaksi tersimpan': 'When a transaction is saved', 'Tampilkan desimal': 'Show decimals',
    'Tentang': 'About', 'Tambah rekening': 'Add account', 'Nama rekening': 'Account name',
    'Saldo awal (opsional)': 'Opening balance (optional)', 'Ketuk untuk ubah · geser ke kiri untuk hapus': 'Tap to edit · swipe left to delete',
    'Semua': 'All', 'Bulanan': 'Monthly', 'Custom': 'Custom',
    'Selisih': 'Net change', 'Per rekening': 'By account', 'Belum ada pemasukan atau pengeluaran di periode ini': 'No income or expenses in this period',
  };
  return map[id] ?? id;
}

bool kDecimals = false;

String money(int cents, {bool? dec}) {
  final showDec = dec ?? kDecimals;
  final neg = cents < 0;
  final a = cents.abs();
  var whole = a ~/ 100;
  final frac = a % 100;
  if (!showDec && frac >= 50) whole += 1;
  final s = whole
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  final d = showDec ? ',${frac.toString().padLeft(2, '0')}' : '';
  return '${neg ? '-' : ''}Rp $s$d';
}

int? parseMoney(String s) {
  final t = s.trim().replaceAll(' ', '').replaceAll('.', '').replaceAll(',', '.');
  final d = double.tryParse(t);
  if (d == null) return null;
  return (d * 100).round();
}

String two(int n) => n.toString().padLeft(2, '0');
const _blnId = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
const _blnEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String fmtDate(DateTime d) =>
    '${d.day} ${(kEnglish ? _blnEn : _blnId)[d.month - 1]} ${d.year}, ${two(d.hour)}:${two(d.minute)}';

Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(tr(t), style: TextStyle(color: kMuted, fontSize: 13)),
    );

void toast(BuildContext c, String m) =>
    showIsland(c, title: m, icon: Icons.info_outline_rounded, color: kOrange, sound: 'info');

/// Bungkus apa saja supaya ada animasi tekan (mengecil sedikit lalu memantul)
/// + suara klik. Dipakai di semua tombol.
class Bounce extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool sound;
  const Bounce({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.95,
    this.sound = true,
  });

  @override
  State<Bounce> createState() => _BounceState();
}

class _BounceState extends State<Bounce> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.sound) Sfx.click();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 90 : 220),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Tombol standar Viemos (isi penuh atau garis tepi), sudah ada animasi tekan.
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color color;
  final bool outlined;
  final IconData? icon;
  final double height;
  const AppButton(
    this.text, {
    super.key,
    required this.onTap,
    this.color = kOrange,
    this.outlined = false,
    this.icon,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final fg = outlined ? kText : Colors.black;
    return Bounce(
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(18),
          border: outlined ? Border.all(color: kBorder, width: 1.5) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 8)],
            Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg)),
          ],
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: kBorder),
      ),
      child: Padding(padding: padding, child: child),
    );
    return onTap == null ? card : Bounce(onTap: onTap, scale: 0.97, child: card);
  }
}
