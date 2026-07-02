import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'shop_backup_service.dart';

/// Partage un fichier `.venteapp` via un chemin temporaire (évite les assertions
/// Android avec [XFile.fromData]).
class BackupFileSharer {
  BackupFileSharer._();

  static Future<void> share(
    ShopBackupFile file, {
    String? subject,
    String? text,
  }) =>
      shareBytes(
        bytes: file.bytes,
        filename: file.filename,
        mimeType: 'application/octet-stream',
        subject: subject,
        text: text,
      );

  static Future<void> shareBytes({
    required List<int> bytes,
    required String filename,
    String? mimeType,
    String? subject,
    String? text,
  }) async {
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, filename);
    await File(path).writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(path, mimeType: mimeType)],
      subject: subject,
      text: text,
    );
  }
}
