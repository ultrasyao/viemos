import 'theme.dart';

/// Terjemahan teks UI. Teks sumber = bahasa Indonesia, jadi bahasa Indonesia
/// tidak butuh entri; teks yang tidak ada di kamus tampil apa adanya.
String tr(String id) => Lang.en ? (_en[id] ?? id) : id;

/// Seperti [tr] tapi dengan isian: trf('Hapus {n}?', {'n': nama}).
String trf(String id, Map<String, Object?> args) {
  var s = tr(id);
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

const _en = <String, String>{
  // rekening
  'Hapus {n}?': 'Delete {n}?',
  'Semua transaksi di rekening ini ikut terhapus, termasuk pindah saldo yang melibatkannya.':
      'All transactions in this account will be deleted too, including transfers involving it.',
  'Hapus': 'Delete',
  'Rekening': 'Accounts',
  'Total saldo': 'Total balance',
  'Belum ada rekening': 'No accounts yet',
  'Tambah rekening': 'Add account',
  'Nama rekening': 'Account name',
  'Mis. BCA, Dompet': 'e.g. Bank, Wallet',
  'Saldo awal (opsional)': 'Opening balance (optional)',
  'Simpan': 'Save',
  // hari & bulan
  'Senin': 'Monday', 'Selasa': 'Tuesday', 'Rabu': 'Wednesday', 'Kamis': 'Thursday',
  'Jumat': 'Friday', 'Sabtu': 'Saturday', 'Minggu': 'Sunday',
  'Mei': 'May', 'Agu': 'Aug', 'Okt': 'Oct', 'Des': 'Dec',
  'Januari': 'January', 'Februari': 'February', 'Maret': 'March', 'April': 'April',
  'Juni': 'June', 'Juli': 'July', 'Agustus': 'August', 'Oktober': 'October',
  'Desember': 'December',
  // beranda
  'Catat transaksi': 'Add transaction',
  'Hari ini': 'Today',
  'Masuk': 'In',
  'Keluar': 'Out',
  'Transaksi hari ini': "Today's transactions",
  'Transaksi hari ini · {n} (ketuk untuk ubah / hapus)':
      "Today's transactions · {n} (tap to edit / delete)",
  'Belum ada transaksi hari ini': 'No transactions today',
  'Ketuk tombol pensil di kanan bawah': 'Tap the pencil button at the bottom right',
  'Tutup': 'Close',
  'Batal': 'Cancel',
  // backup
  'Format backup tidak dikenali': 'Unrecognized backup format',
  'Data rekening tidak valid': 'Invalid account data',
  'Data transaksi tidak valid': 'Invalid transaction data',
  // riwayat
  'Riwayat': 'History',
  'Ketuk untuk ubah / hapus · geser ke kiri atau tahan lama untuk hapus cepat':
      'Tap to edit / delete · swipe left or long-press to delete quickly',
  'Belum ada transaksi': 'No transactions yet',
  'Catat. Pantau. Tenang.': 'Record. Track. Relax.',
  // keyboard
  'Selesai': 'Done',
  'spasi': 'space',
  // kunci
  'Coba lagi dalam {n} detik': 'Try again in {n} seconds',
  'Terlalu banyak salah. Tunggu {n} detik': 'Too many wrong tries. Wait {n} seconds',
  'PIN salah ({n} percobaan lagi)': 'Wrong PIN ({n} tries left)',
  'Aplikasi terkunci': 'App locked',
  'Masukkan PIN': 'Enter PIN',
  'Buat PIN baru': 'Create new PIN',
  'Ulangi PIN': 'Repeat PIN',
  'PIN {n} digit. Jangan sampai lupa — tidak ada fitur reset.':
      "{n}-digit PIN. Don't forget it — there is no reset.",
  'PIN tidak sama, ulangi dari awal': "PINs don't match, start over",
  // notifikasi
  'Pengingat harian': 'Daily reminder',
  'Pengingat untuk mencatat transaksi': 'Reminder to record transactions',
  'Waktunya catat keuangan': 'Time to record your finances',
  'Sudah catat transaksi hari ini? Ketuk untuk buka Viemos.':
      "Recorded today's transactions yet? Tap to open Viemos.",
  'Tes pengingat': 'Reminder test',
  'Notifikasi Viemos berfungsi 👍': 'Viemos notifications work 👍',
  // tambah cepat
  'Pemasukan': 'Income',
  'Pengeluaran': 'Expense',
  'Pindah saldo': 'Transfer',
  // rekap
  'Pilih rentang tanggal': 'Select date range',
  '{n} transaksi': '{n} transactions',
  'Belum ada data': 'No data yet',
  'Rekap': 'Summary',
  'Semua': 'All',
  'Bulanan': 'Monthly',
  'Selisih': 'Net',
  'Per rekening': 'Per account',
  'Belum ada pemasukan atau pengeluaran di periode ini':
      'No income or expenses in this period',
  // pengaturan
  'Setting': 'Settings',
  'Tema & bahasa': 'Theme & language',
  'Mode tampilan': 'Display mode',
  'Sistem': 'System',
  'Terang': 'Light',
  'Gelap': 'Dark',
  'Warna tema': 'Theme color',
  'Bahasa': 'Language',
  'Oranye': 'Orange', 'Hijau': 'Green', 'Biru': 'Blue', 'Ungu': 'Purple',
  'Pink': 'Pink', 'Tosca': 'Teal',
  'Keamanan': 'Security',
  'PIN aktif': 'PIN enabled',
  'Aplikasi terkunci saat ditutup': 'App locks when closed',
  'PIN dimatikan': 'PIN disabled',
  'Langsung saat keluar app': 'Right when leaving the app',
  'Setelah {n} detik': 'After {n} seconds',
  'Setelah {n} menit': 'After {n} minutes',
  'Kunci otomatis': 'Auto-lock',
  'Langsung': 'Immediately',
  'Setelah 30 detik': 'After 30 seconds',
  'Setelah 1 menit': 'After 1 minute',
  'Setelah 5 menit': 'After 5 minutes',
  'Izin notifikasi ditolak': 'Notification permission denied',
  'Aktifkan lewat Info aplikasi → Notifikasi': 'Enable it in App info → Notifications',
  'Pengingat aktif': 'Reminder enabled',
  'Setiap hari jam {n}': 'Every day at {n}',
  'Gagal membagikan file': 'Failed to share file',
  'Simpan backup': 'Save backup',
  'Backup tersimpan': 'Backup saved',
  'Gagal menyimpan backup': 'Failed to save backup',
  'File bukan backup Viemos': 'Not a Viemos backup file',
  'Pulihkan data?': 'Restore data?',
  'Semua data sekarang akan DIGANTI dengan isi backup: {a} rekening, {t} transaksi.':
      'All current data will be REPLACED by the backup: {a} accounts, {t} transactions.',
  'Pulihkan': 'Restore',
  'Data dipulihkan': 'Data restored',
  '{a} rekening · {t} transaksi': '{a} accounts · {t} transactions',
  'Gagal memulihkan': 'Restore failed',
  'Data lama tidak berubah': 'Existing data is unchanged',
  'File tidak bisa dibaca': 'File could not be read',
  'Kosong atau terlalu besar': 'Empty or too large',
  'Hapus semua data?': 'Delete all data?',
  'Semua rekening dan transaksi dihapus permanen. Buat backup dulu kalau masih perlu.':
      'All accounts and transactions will be permanently deleted. Make a backup first if you still need it.',
  'Semua data dihapus': 'All data deleted',
  'Blokir screenshot': 'Block screenshots',
  'Sembunyikan isi app dari tangkapan layar & daftar app terbaru':
      'Hide app content from screenshots and the recent apps list',
  'Kunci PIN': 'PIN lock',
  'Aktif · {n} digit': 'Enabled · {n} digits',
  'Belum aktif': 'Not enabled',
  'Ubah PIN': 'Change PIN',
  'Kunci sekarang': 'Lock now',
  'Pengingat': 'Reminder',
  'Ingatkan catat transaksi': 'Remind me to record transactions',
  'Jam pengingat': 'Reminder time',
  'Tes notifikasi': 'Test notification',
  'Backup & pulihkan': 'Backup & restore',
  'Download backup': 'Download backup',
  'Simpan file .json ke HP (tidak terenkripsi — simpan di tempat aman)':
      'Save a .json file to your phone (not encrypted — keep it somewhere safe)',
  'Bagikan backup': 'Share backup',
  'Kirim file .json lewat WhatsApp, Drive, dll': 'Send the .json file via WhatsApp, Drive, etc.',
  'Pulihkan dari file': 'Restore from file',
  'Mengganti semua data sekarang': 'Replaces all current data',
  'Data': 'Data',
  'Ekspor CSV': 'Export CSV',
  'Untuk dibuka di Excel / Sheets': 'To open in Excel / Sheets',
  'Hapus semua data': 'Delete all data',
  'Tampilan & suara': 'Display & sound',
  'Suara': 'Sound',
  'Klik & notifikasi transaksi': 'Clicks & transaction notifications',
  'Getar': 'Vibration',
  'Saat transaksi tersimpan': 'When a transaction is saved',
  'Tampilkan desimal': 'Show decimals',
  'Rp 12.500,50 bukan Rp 12.501': 'Rp 12,500.50 instead of Rp 12,501',
  'Tentang': 'About',
  '{n} transaksi tersimpan · data hanya ada di HP ini':
      '{n} transactions saved · data only lives on this phone',
  // dialog transaksi
  'Tambah rekening dulu di tab Rekening': 'Add an account first in the Accounts tab',
  'Transaksi dihapus': 'Transaction deleted',
  'Perubahan tersimpan': 'Changes saved',
  '{n} tersimpan': '{n} saved',
  'Isi jumlah dengan benar': 'Enter a valid amount',
  'Pilih rekening tujuan yang berbeda': 'Choose a different destination account',
  'Hapus transaksi?': 'Delete transaction?',
  'Transaksi ini dihapus permanen dan saldo rekening ikut berubah.':
      'This transaction will be permanently deleted and the account balance will change.',
  'Ubah transaksi': 'Edit transaction',
  'Koma untuk desimal': 'Use a comma for decimals',
  'Dari rekening': 'From account',
  'Ke rekening': 'To account',
  'Waktu': 'Time',
  'Catatan (opsional)': 'Note (optional)',
  'Mis. makan siang': 'e.g. lunch',
};
