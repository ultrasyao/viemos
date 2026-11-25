import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class Account {
  final int id;
  final String name;
  final String kind;
  final int initial;
  final int color;
  final int balance;
  const Account(this.id, this.name, this.kind, this.initial, this.color, this.balance);
}

class Txn {
  final int id;
  final String type;
  final int accountId;
  final int? toAccountId;
  final int amount;
  final DateTime ts;
  final String note;
  final String accName;
  final String? toName;
  const Txn(this.id, this.type, this.accountId, this.toAccountId, this.amount,
      this.ts, this.note, this.accName, this.toName);
}

class Db {
  Db._();
  static final Db i = Db._();
  final ValueNotifier<int> rev = ValueNotifier<int>(0);
  Database? _db;

  Future<Database> get _d async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'viemos.db');
    return openDatabase(path, version: 1, onCreate: (d, v) async {
      await d.execute(
          'CREATE TABLE accounts(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, kind TEXT NOT NULL, initial INTEGER NOT NULL DEFAULT 0, color INTEGER NOT NULL DEFAULT 0)');
      await d.execute(
          'CREATE TABLE txns(id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, account_id INTEGER NOT NULL, to_account_id INTEGER, amount INTEGER NOT NULL, ts INTEGER NOT NULL, note TEXT)');
      await d.execute('CREATE INDEX idx_txns_ts ON txns(ts)');
    });
  }

  void _bump() => rev.value = rev.value + 1;

  Future<List<Account>> accounts() async {
    final d = await _d;
    final rows = await d.rawQuery('''
SELECT a.*, a.initial
 + COALESCE((SELECT SUM(amount) FROM txns WHERE account_id=a.id AND type='in'),0)
 - COALESCE((SELECT SUM(amount) FROM txns WHERE account_id=a.id AND type IN ('out','transfer')),0)
 + COALESCE((SELECT SUM(amount) FROM txns WHERE to_account_id=a.id AND type='transfer'),0) AS bal
FROM accounts a ORDER BY a.id''');
    return [
      for (final r in rows)
        Account(r['id'] as int, r['name'] as String, r['kind'] as String,
            r['initial'] as int, r['color'] as int, (r['bal'] as num).toInt())
    ];
  }

  Future<void> addAccount(String name, String kind, int initial, int color) async {
    final d = await _d;
    await d.insert('accounts', {'name': name, 'kind': kind, 'initial': initial, 'color': color});
    _bump();
  }

  Future<void> deleteAccount(int id) async {
    final d = await _d;
    await d.transaction((t) async {
      await t.delete('txns', where: 'account_id=? OR to_account_id=?', whereArgs: [id, id]);
      await t.delete('accounts', where: 'id=?', whereArgs: [id]);
    });
    _bump();
  }

  Future<void> addTxn({
    required String type,
    required int accountId,
    int? toAccountId,
    required int amount,
    required DateTime ts,
    String note = '',
  }) async {
    final d = await _d;
    await d.insert('txns', {
      'type': type,
      'account_id': accountId,
      'to_account_id': toAccountId,
      'amount': amount,
      'ts': ts.millisecondsSinceEpoch,
      'note': note,
    });
    _bump();
  }

  /// Ubah transaksi yang sudah ada (jenis, rekening, jumlah, waktu, catatan).
  Future<void> updateTxn({
    required int id,
    required String type,
    required int accountId,
    int? toAccountId,
    required int amount,
    required DateTime ts,
    String note = '',
  }) async {
    final d = await _d;
    await d.update(
      'txns',
      {
        'type': type,
        'account_id': accountId,
        'to_account_id': toAccountId,
        'amount': amount,
        'ts': ts.millisecondsSinceEpoch,
        'note': note,
      },
      where: 'id=?',
      whereArgs: [id],
    );
    _bump();
  }

  Future<void> deleteTxn(int id) async {
    final d = await _d;
    await d.delete('txns', where: 'id=?', whereArgs: [id]);
    _bump();
  }

  Future<List<Txn>> txns() async {
    final d = await _d;
    final rows = await d.rawQuery(
        'SELECT t.*, a.name AS an, b.name AS bn FROM txns t JOIN accounts a ON a.id=t.account_id LEFT JOIN accounts b ON b.id=t.to_account_id ORDER BY t.ts DESC, t.id DESC');
    return [
      for (final r in rows)
        Txn(
          r['id'] as int,
          r['type'] as String,
          r['account_id'] as int,
          r['to_account_id'] as int?,
          r['amount'] as int,
          DateTime.fromMillisecondsSinceEpoch(r['ts'] as int),
          (r['note'] as String?) ?? '',
          r['an'] as String,
          r['bn'] as String?,
        )
    ];
  }

  /// Paksa semua layar memuat ulang (mis. setelah ganti format uang).
  void refresh() => _bump();

  Future<Map<String, dynamic>> exportAll() async {
    final d = await _d;
    return {
      'app': 'viemos',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'accounts': await d.query('accounts', orderBy: 'id'),
      'txns': await d.query('txns', orderBy: 'id'),
    };
  }

  /// Ganti SEMUA data dengan isi backup. Gagal = tidak ada yang berubah.
  Future<void> importAll(Map<String, dynamic> data) async {
    final accs = data['accounts'];
    final txs = data['txns'];
    if (data['app'] != 'viemos' || accs is! List || txs is! List) {
      throw const FormatException('Format backup tidak dikenali');
    }
    final d = await _d;
    await d.transaction((t) async {
      await t.delete('txns');
      await t.delete('accounts');
      for (final raw in accs) {
        final a = raw as Map;
        await t.insert('accounts', {
          'id': (a['id'] as num).toInt(),
          'name': a['name'] as String,
          'kind': a['kind'] as String,
          'initial': (a['initial'] as num).toInt(),
          'color': (a['color'] as num).toInt(),
        });
      }
      for (final raw in txs) {
        final x = raw as Map;
        await t.insert('txns', {
          'id': (x['id'] as num).toInt(),
          'type': x['type'] as String,
          'account_id': (x['account_id'] as num).toInt(),
          'to_account_id': (x['to_account_id'] as num?)?.toInt(),
          'amount': (x['amount'] as num).toInt(),
          'ts': (x['ts'] as num).toInt(),
          'note': (x['note'] as String?) ?? '',
        });
      }
    });
    _bump();
  }

  Future<void> clearAll() async {
    final d = await _d;
    await d.transaction((t) async {
      await t.delete('txns');
      await t.delete('accounts');
    });
    _bump();
  }
}
