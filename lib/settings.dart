import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'app_dialog.dart';
import 'db.dart';
import 'island.dart';
import 'lock.dart';
import 'notif.dart';
import 'prefs.dart';
import 'sfx.dart';
import 'ui.dart';

const kVersion = '0.6.0';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsScreen> {
  int txnCount = 0;

  @override
  void initState() {
    super.initState();
    _count();
    Db.i.rev.addListener(_count);
  }

  @override
  void dispose() {
    Db.i.rev.removeListener(_count);
    super.dispose();
  }

  Future<void> _count() async {
    final t = await Db.i.txns();
    if (mounted) setState(() => txnCount = t.length);
  }

  // ------------------------------------------------------------ UI helpers
  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8, left: 4),
        child: Text(t.toUpperCase(),
            style: const TextStyle(
                color: kMuted, fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.w600)),
      );

  Widget _group(List<Widget> rows) {
    final kids = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) kids.add(const Divider(height: 1, color: kBorder, indent: 66));
      kids.add(rows[i]);
    }
    return Material(
      color: kCard,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: kBorder),
      ),
      child: Column(children: kids),
    );
  }

  Widget _row({
    required IconData icon,
    required String title,
    String? sub,
    Widget? trailing,
    VoidCallback? onTap,
    Color? color,
  }) {
    final c = color ?? kOrange;
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              Sfx.click();
              onTap();
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: c.withAlpha(36), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: c),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(fontWeight: FontWeight.w600, color: color ?? kText)),
                  if (sub != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(sub, style: const TextStyle(color: kMuted, fontSize: 12.5)),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _toggle({
    required IconData icon,
    required String title,
    String? sub,
    required bool value,
    required Future<void> Function(bool) on,
  }) =>
      _row(
        icon: icon,
        title: title,
        sub: sub,
        onTap: () => on(!value),
        trailing: IgnorePointer(child: Switch(value: value, onChanged: (_) {})),
      );

  Widget _chev() => const Icon(Icons.chevron_right_rounded, color: kMuted);

  void _ok(String title, {String? sub, IconData icon = Icons.check_rounded}) {
    if (!mounted) return;
    showIsland(context, title: title, subtitle: sub, icon: icon, color: kIn, sound: 'in');
  }

  void _bad(String title, {String? sub}) {
    if (!mounted) return;
    showIsland(context,
        title: title,
        subtitle: sub,
        icon: Icons.error_outline_rounded,
        color: kOut,
        sound: 'out');
  }

  // ------------------------------------------------------------------- PIN
  Future<bool> _guard() async {
    if (!Prefs.hasPin) return true;
    return verifyPin(context);
  }

  Future<void> _newPin() async {
    final ok = await setupPin(context);
    if (!mounted) return;
    setState(() {});
    if (ok) _ok('PIN aktif', sub: 'Aplikasi terkunci saat ditutup', icon: Icons.lock_rounded);
  }

  Future<void> _changePin() async {
    if (!await _guard()) return;
    if (!mounted) return;
    await _newPin();
  }

  Future<void> _offPin() async {
    if (!await _guard()) return;
    await Prefs.clearPin();
    if (!mounted) return;
    setState(() {});
    _ok('PIN dimatikan', icon: Icons.lock_open_rounded);
  }

  String _lockLabel() {
    final s = Prefs.lockAfter;
    if (s == 0) return 'Langsung saat keluar app';
    if (s < 60) return 'Setelah $s detik';
    return 'Setelah ${s ~/ 60} menit';
  }

  Future<void> _pickLockAfter() async {
    final v = await choiceDialog<int>(
      context,
      title: 'Kunci otomatis',
      selected: Prefs.lockAfter,
      options: const [
        (0, 'Langsung'),
        (30, 'Setelah 30 detik'),
        (60, 'Setelah 1 menit'),
        (300, 'Setelah 5 menit'),
      ],
    );
    if (v == null) return;
    await Prefs.setLockAfter(v);
    if (mounted) setState(() {});
  }

  // -------------------------------------------------------------- pengingat
  String _timeLabel() {
    final m = Prefs.reminderMin;
    return '${two(m ~/ 60)}.${two(m % 60)}';
  }

  Future<void> _toggleReminder(bool on) async {
    if (on) {
      final ok = await Notifs.ask();
      if (!ok) {
        _bad('Izin notifikasi ditolak', sub: 'Aktifkan lewat Info aplikasi → Notifikasi');
        return;
      }
      await Prefs.setReminderOn(true);
      await Notifs.scheduleDaily(Prefs.reminderMin);
      _ok('Pengingat aktif', sub: 'Setiap hari jam ${_timeLabel()}', icon: Icons.notifications_active_outlined);
    } else {
      await Prefs.setReminderOn(false);
      await Notifs.cancel();
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickTime() async {
    final m = Prefs.reminderMin;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      initialEntryMode: TimePickerEntryMode.dialOnly,
    );
    if (t == null) return;
    await Prefs.setReminderMin(t.hour * 60 + t.minute);
    if (Prefs.reminderOn) await Notifs.scheduleDaily(Prefs.reminderMin);
    if (mounted) setState(() {});
  }

  Future<void> _testNotif() async {
    final ok = await Notifs.ask();
    if (!ok) {
      _bad('Izin notifikasi ditolak');
      return;
    }
    await Notifs.test();
  }

  // ------------------------------------------------------------------- data
  String _stamp() {
    final n = DateTime.now();
    return '${n.year}${two(n.month)}${two(n.day)}-${two(n.hour)}${two(n.minute)}';
  }

  Future<void> _shareText(String name, String content, String mime) async {
    Lock.skipNext();
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/$name');
      await f.writeAsString(content);
      await Share.shareXFiles([XFile(f.path, mimeType: mime)]);
      try {
        await f.delete(); // jangan tinggalkan data keuangan di cache
      } catch (_) {}
    } catch (e) {
      _bad('Gagal membagikan file', sub: '$e');
    }
  }

  Future<String> _backupJson() async => jsonEncode(await Db.i.exportAll());

  Future<void> _backupShare() async {
    final j = await _backupJson();
    await _shareText('viemos-backup-${_stamp()}.json', j, 'application/json');
  }

  /// Download: muncul layar "Simpan sebagai" bawaan Android, pilih Download / folder lain.
  Future<void> _backupDownload() async {
    final j = await _backupJson();
    Lock.skipNext();
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan backup',
        fileName: 'viemos-backup-${_stamp()}.json',
        bytes: Uint8List.fromList(utf8.encode(j)),
      );
      if (path == null) return;
      final name = path.split('/').last;
      _ok('Backup tersimpan', sub: name.isEmpty ? path : name, icon: Icons.download_done_rounded);
    } catch (e) {
      _bad('Gagal menyimpan backup', sub: '$e');
    }
  }

  String _csvCell(String s) => '"${s.replaceAll('"', '""')}"';

  Future<void> _exportCsv() async {
    final list = await Db.i.txns();
    final b = StringBuffer('\uFEFFTanggal,Jam,Jenis,Rekening,Rekening tujuan,Jumlah,Catatan\n');
    for (final t in list.reversed) {
      final jenis = t.type == 'in' ? 'Pemasukan' : (t.type == 'out' ? 'Pengeluaran' : 'Pindah saldo');
      final d = '${t.ts.year}-${two(t.ts.month)}-${two(t.ts.day)}';
      final jam = '${two(t.ts.hour)}:${two(t.ts.minute)}';
      b.writeln([
        d,
        jam,
        jenis,
        _csvCell(t.accName),
        _csvCell(t.toName ?? ''),
        (t.amount / 100).toStringAsFixed(2),
        _csvCell(t.note),
      ].join(','));
    }
    await _shareText('viemos-transaksi-${_stamp()}.csv', b.toString(), 'text/csv');
  }

  Map<String, dynamic>? _parse(String raw) {
    try {
      final d = jsonDecode(raw);
      if (d is Map<String, dynamic> && d['app'] == 'viemos') return d;
    } catch (_) {}
    return null;
  }

  Future<void> _restoreText(String raw) async {
    final data = _parse(raw);
    if (data == null) {
      _bad('File bukan backup Viemos');
      return;
    }
    final a = (data['accounts'] as List?)?.length ?? 0;
    final t = (data['txns'] as List?)?.length ?? 0;
    if (!mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'Pulihkan data?',
      message: 'Semua data sekarang akan DIGANTI dengan isi backup: $a rekening, $t transaksi.',
      confirmText: 'Pulihkan',
    );
    if (!ok) return;
    try {
      await Db.i.importAll(data);
      _ok('Data dipulihkan', sub: '$a rekening · $t transaksi', icon: Icons.restore_rounded);
    } catch (e) {
      _bad('Gagal memulihkan', sub: 'Data lama tidak berubah');
    }
  }

  Future<void> _restoreFile() async {
    if (!await _guard()) return;
    Lock.skipNext();
    try {
      final r = await FilePicker.platform.pickFiles(withData: true);
      if (r == null || r.files.isEmpty) return;
      final bytes = r.files.first.bytes;
      if (bytes == null || bytes.length > 20 * 1024 * 1024) {
        _bad('File tidak bisa dibaca', sub: 'Kosong atau terlalu besar');
        return;
      }
      await _restoreText(utf8.decode(bytes));
    } catch (_) {
      _bad('File tidak bisa dibaca');
    }
  }

  Future<void> _wipe() async {
    if (!await _guard()) return;
    if (!mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'Hapus semua data?',
      message: 'Semua rekening dan transaksi dihapus permanen. Buat backup dulu kalau masih perlu.',
      confirmText: 'Hapus',
      danger: true,
    );
    if (!ok) return;
    await Db.i.clearAll();
    _ok('Semua data dihapus', icon: Icons.delete_outline_rounded);
  }

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final pin = Prefs.hasPin;
    return ListView(
      key: const PageStorageKey('page_settings'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
      children: [
        const Text('Setting', style: kTitle),
        _section('Keamanan'),
        _group([
          _toggle(
            icon: Icons.screenshot_monitor_rounded,
            title: 'Blokir screenshot',
            sub: 'Sembunyikan isi app dari tangkapan layar & daftar app terbaru',
            value: Prefs.secureScreen,
            on: (v) async {
              await Prefs.setSecureScreen(v);
              if (mounted) setState(() {});
            },
          ),
          _row(
            icon: pin ? Icons.lock_rounded : Icons.lock_open_rounded,
            title: 'Kunci PIN',
            sub: pin ? 'Aktif · $kPinLen digit' : 'Belum aktif',
            onTap: pin ? _offPin : _newPin,
            trailing: IgnorePointer(child: Switch(value: pin, onChanged: (_) {})),
          ),
          if (pin) ...[
            _row(icon: Icons.password_rounded, title: 'Ubah PIN', onTap: _changePin, trailing: _chev()),
            _row(
                icon: Icons.timer_outlined,
                title: 'Kunci otomatis',
                sub: _lockLabel(),
                onTap: _pickLockAfter,
                trailing: _chev()),
            _row(icon: Icons.lock_clock_outlined, title: 'Kunci sekarang', onTap: Lock.lockNow),
          ],
        ]),
        _section('Pengingat'),
        _group([
          _toggle(
            icon: Icons.notifications_active_outlined,
            title: 'Pengingat harian',
            sub: 'Ingatkan catat transaksi',
            value: Prefs.reminderOn,
            on: _toggleReminder,
          ),
          if (Prefs.reminderOn)
            _row(
              icon: Icons.schedule_rounded,
              title: 'Jam pengingat',
              sub: _timeLabel(),
              onTap: _pickTime,
              trailing: _chev(),
            ),
          _row(icon: Icons.notifications_none_rounded, title: 'Tes notifikasi', onTap: _testNotif),
        ]),
        _section('Backup & pulihkan'),
        _group([
          _row(
            icon: Icons.download_rounded,
            title: 'Download backup',
            sub: 'Simpan file .json ke HP (tidak terenkripsi — simpan di tempat aman)',
            onTap: _backupDownload,
            trailing: _chev(),
          ),
          _row(
              icon: Icons.ios_share_rounded,
              title: 'Bagikan backup',
              sub: 'Kirim file .json lewat WhatsApp, Drive, dll',
              onTap: _backupShare),
          _row(
              icon: Icons.restore_rounded,
              title: 'Pulihkan dari file',
              sub: 'Mengganti semua data sekarang',
              onTap: _restoreFile),
        ]),
        _section('Data'),
        _group([
          _row(
              icon: Icons.table_chart_outlined,
              title: 'Ekspor CSV',
              sub: 'Untuk dibuka di Excel / Sheets',
              onTap: _exportCsv),
          _row(
              icon: Icons.delete_forever_outlined,
              title: 'Hapus semua data',
              color: kOut,
              onTap: _wipe),
        ]),
        _section('Tampilan & suara'),
        _group([
          _toggle(
            icon: Icons.volume_up_outlined,
            title: 'Suara',
            sub: 'Klik & notifikasi transaksi',
            value: Prefs.sound,
            on: (v) async {
              await Prefs.setSound(v);
              if (mounted) setState(() {});
            },
          ),
          _toggle(
            icon: Icons.vibration_rounded,
            title: 'Getar',
            sub: 'Saat transaksi tersimpan',
            value: Prefs.haptic,
            on: (v) async {
              await Prefs.setHaptic(v);
              if (mounted) setState(() {});
            },
          ),
          _toggle(
            icon: Icons.looks_one_outlined,
            title: 'Tampilkan desimal',
            sub: 'Rp 12.500,50 bukan Rp 12.501',
            value: Prefs.decimals,
            on: (v) async {
              await Prefs.setDecimals(v);
              Db.i.refresh();
              if (mounted) setState(() {});
            },
          ),
        ]),
        _section('Tentang'),
        _group([
          _row(
            icon: Icons.info_outline_rounded,
            title: 'Viemos v$kVersion',
            sub: '$txnCount transaksi tersimpan · data hanya ada di HP ini',
          ),
        ]),
      ],
    );
  }
}
