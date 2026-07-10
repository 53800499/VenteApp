import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:drift/native.dart';

import '../storage/database_key_storage.dart';

const databaseFileName = 'venteapp.sqlite';

String escapeSqlString(String source) => source.replaceAll("'", "''");

bool debugCheckHasCipher(sqlite.Database database) {
  return database.select('PRAGMA cipher;').isNotEmpty;
}

bool isPlaintextSqliteFile(File file) {
  if (!file.existsSync()) return false;

  final handle = file.openSync(mode: FileMode.read);
  try {
    final header = handle.readSync(15);
    return utf8.decode(header, allowMalformed: true) == 'SQLite format 3';
  } finally {
    handle.closeSync();
  }
}

void migratePlaintextDatabaseToEncrypted({
  required File dbFile,
  required String passphrase,
}) {
  if (!isPlaintextSqliteFile(dbFile)) return;

  final tmp = File('${dbFile.path}.encrypting.tmp');
  if (tmp.existsSync()) {
    tmp.deleteSync();
  }

  final plaintextDb = sqlite.sqlite3.open(dbFile.path);
  try {
    plaintextDb.execute("VACUUM INTO '${escapeSqlString(tmp.path)}';");
  } finally {
    plaintextDb.close();
  }

  final encryptedDb = sqlite.sqlite3.open(tmp.path);
  try {
    encryptedDb.execute("PRAGMA rekey = '${escapeSqlString(passphrase)}';");
  } finally {
    encryptedDb.close();
  }

  if (!tmp.existsSync()) {
    throw StateError('Échec du chiffrement SQLite : fichier temporaire absent.');
  }

  final backup = File('${dbFile.path}.plaintext.bak');
  if (backup.existsSync()) {
    backup.deleteSync();
  }
  dbFile.renameSync(backup.path);
  tmp.renameSync(dbFile.path);
  backup.deleteSync();
}

void applyDatabaseKey(sqlite.Database rawDb, String passphrase) {
  assert(
    debugCheckHasCipher(rawDb),
    'SQLite3MultipleCiphers indisponible : vérifiez les hooks pubspec.',
  );
  rawDb.execute("PRAGMA key = '${escapeSqlString(passphrase)}';");
}

QueryExecutor openEncryptedConnection(DatabaseKeyStorage keyStorage) {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, databaseFileName));
    final passphrase = await keyStorage.getOrCreatePassphrase();

    sqlite.sqlite3.tempDirectory = (await getTemporaryDirectory()).path;

    return NativeDatabase.createInBackground(
      file,
      isolateSetup: () {
        migratePlaintextDatabaseToEncrypted(
          dbFile: file,
          passphrase: passphrase,
        );
      },
      setup: (rawDb) => applyDatabaseKey(rawDb, passphrase),
    );
  });
}

/// Base en mémoire non chiffrée (SQLite3MC ne supporte pas `PRAGMA key` en RAM).
QueryExecutor openEncryptedTestConnection() => NativeDatabase.memory();
