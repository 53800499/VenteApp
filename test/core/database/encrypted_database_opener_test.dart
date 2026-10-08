import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:venteapp/core/database/encrypted_database_opener.dart';

void main() {
  test('isPlaintextSqliteFile détecte une base SQLite non chiffrée', () async {
    final dir = await Directory.systemTemp.createTemp('venteapp_sqlite_test_');
    final dbFile = File(p.join(dir.path, 'plain.sqlite'));

    final db = sqlite.sqlite3.open(dbFile.path);
    try {
      db.execute('CREATE TABLE sample (id INTEGER PRIMARY KEY);');
    } finally {
      db.close();
    }

    expect(isPlaintextSqliteFile(dbFile), isTrue);

    migratePlaintextDatabaseToEncrypted(
      dbFile: dbFile,
      passphrase: 'test-passphrase',
    );

    expect(isPlaintextSqliteFile(dbFile), isFalse);

    final encryptedDb = sqlite.sqlite3.open(dbFile.path);
    try {
      applyDatabaseKey(encryptedDb, 'test-passphrase');
      final rows = encryptedDb.select('SELECT name FROM sqlite_master;');
      expect(rows.any((row) => row['name'] == 'sample'), isTrue);
    } finally {
      encryptedDb.close();
    }

    await dir.delete(recursive: true);
  });

  test('ensureDatabaseAccessible sauvegarde et réinitialise en cas de mauvaise clé (SQLITE_NOTADB code 26)', () async {
    final dir = await Directory.systemTemp.createTemp('venteapp_sqlite_corrupt_test_');
    final dbFile = File(p.join(dir.path, 'encrypted.sqlite'));

    // 1. Créer une base chiffrée avec key-original
    final db = sqlite.sqlite3.open(dbFile.path);
    try {
      applyDatabaseKey(db, 'key-original');
      db.execute('CREATE TABLE sample (id INTEGER PRIMARY KEY);');
    } finally {
      db.close();
    }

    // 2. Tenter d'accéder avec une mauvaise clé (suite à un reset du SecureStorage)
    ensureDatabaseAccessible(
      dbFile: dbFile,
      passphrase: 'key-different-lost',
    );

    // 3. Le fichier illisible doit avoir été déplacé en backup corrupted
    expect(dbFile.existsSync(), isFalse);
    final backups = dir.listSync().where((f) => f.path.contains('.corrupted.')).toList();
    expect(backups, isNotEmpty);

    await dir.delete(recursive: true);
  });
}
