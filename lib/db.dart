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
}
