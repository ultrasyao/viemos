import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'db.dart';
import 'prefs.dart';
import 'ui.dart';

/// Backup otomatis ke folder pilihan user (harus dinyalakan sendiri di Setting).
///
/// Cara kerja:
///  - tiap ada perubahan data, ~4 detik kemudian ditulis ulang `viemos-auto.json`
///  - sekali per hari juga dibuat salinan `viemos-auto-YYYYMMDD.json`
///    (7 hari terakhir disimpan) — jadi kalau data terhapus tidak sengaja,
///    masih ada salinan hari-hari sebelumnya
///  - data kosong TIDAK pernah ditulis, supaya backup bagus tidak tertimpa kosong
class AutoBackup {
  AutoBackup._();

  static const mainName = 'viemos-auto.json';
  static Timer? _t;
  static bool _running = false;

  static void init() {
    Db.i.rev.addListener(_onChange);
    if (Prefs.autoBackup) {
      // sekali saat app dibuka kalau hari ini belum ada backup
      Future.delayed(const Duration(seconds: 6), () {
        final last = DateTime.fromMillisecondsSinceEpoch(Prefs.lastBackup);
        final n = DateTime.now();
        if (last.year != n.year || last.month != n.month || last.day != n.day) run();
      });
    }
  }

  static void _onChange() {
    if (!Prefs.autoBackup || Prefs.backupDir == null) return;
    _t?.cancel();
    _t = Timer(const Duration(seconds: 4), run);
  }

  /// true kalau app boleh menulis ke folder pilihan.
  /// Android 11+ butuh izin "Akses semua file"; Android 10 ke bawah izin penyimpanan biasa.
  static Future<bool> ensureAccess({bool ask = true}) async {
    if (!Platform.isAndroid) return true;
    try {
      if (await Permission.manageExternalStorage.isGranted) return true;
      if (await Permission.storage.isGranted) return true;
      if (!ask) return false;
      final s = await Permission.manageExternalStorage.request();
      if (s.isGranted) return true;
      final s2 = await Permission.storage.request();
      return s2.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Tulis backup sekarang. Return null kalau sukses, atau pesan error.
  static Future<String?> run() async {
    if (_running) return null;
    final dir = Prefs.backupDir;
    if (dir == null) return 'Folder backup belum dipilih';
    _running = true;
    try {
      if (!await ensureAccess(ask: false)) {
        return 'Izin akses penyimpanan belum diberikan';
      }
      final data = await Db.i.exportAll();
      final empty = (data['accounts'] as List).isEmpty && (data['txns'] as List).isEmpty;
      if (empty) return 'Data masih kosong, backup dilewati';
      final d = Directory(dir);
      await d.create(recursive: true);
      final json = jsonEncode(data);
      await File('${d.path}/$mainName').writeAsString(json, flush: true);
      final n = DateTime.now();
      final day = '${n.year}${two(n.month)}${two(n.day)}';
      await File('${d.path}/viemos-auto-$day.json').writeAsString(json, flush: true);
      await _prune(d);
      await Prefs.setLastBackup(n.millisecondsSinceEpoch);
      return null;
    } catch (_) {
      return 'Gagal menulis ke folder itu. Coba pilih folder lain';
    } finally {
      _running = false;
    }
  }

  static Future<void> _prune(Directory d) async {
    try {
      final re = RegExp(r'viemos-auto-\d{8}\.json$');
      final files = d.listSync().whereType<File>().where((f) => re.hasMatch(f.path)).toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      while (files.length > 7) {
        try {
          await files.removeAt(0).delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Isi backup otomatis terakhir (null kalau belum ada / tidak terbaca).
  static Future<String?> readLatest() async {
    final dir = Prefs.backupDir;
    if (dir == null) return null;
    try {
      if (!await ensureAccess(ask: false)) return null;
      final f = File('$dir/$mainName');
      if (!await f.exists()) return null;
      return await f.readAsString();
    } catch (_) {
      return null;
    }
  }

  /// Nama folder yang enak dibaca.
  static String pretty(String path) =>
      path.replaceFirst(RegExp(r'^/storage/emulated/0/?'), 'Memori internal/');
}
