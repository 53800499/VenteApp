import 'dart:io' show File, Platform, Process;
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../network/api_client.dart';
import 'app_update_info.dart';

class AppUpdateService {
  AppUpdateService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  // Version locale de l'application (correspondant à pubspec.yaml 1.0.1+2)
  static const currentVersion = '1.0.1';
  static const currentBuild = 2;

  String get currentPlatform {
    if (kIsWeb) return 'WEB';
    if (Platform.isAndroid) return 'ANDROID';
    if (Platform.isWindows) return 'WINDOWS';
    return 'OTHER';
  }

  Future<AppUpdateInfo?> checkForUpdate() async {
    final platform = currentPlatform;
    if (platform != 'ANDROID' && platform != 'WINDOWS') return null;

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/app-updates/$platform',
        queryParameters: {'currentBuild': currentBuild},
      );

      final data = response.data;
      if (data == null) return null;

      final update = AppUpdateInfo.fromJson(data);
      if (update.latestBuild > currentBuild) {
        return update;
      }
      return null;
    } catch (_) {
      // Si hors-ligne ou serveur indisponible, ne bloque pas l'utilisateur
      return null;
    }
  }

  Future<bool> verifyFileSha256(String filePath, String expectedSha256) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;
    final cleanExpected = expectedSha256.trim().toLowerCase();
    if (cleanExpected.isEmpty) return true;

    final stream = file.openRead();
    final digest = await sha256.bind(stream).first;
    final actualHash = digest.toString().toLowerCase();

    return actualHash == cleanExpected;
  }

  Future<void> downloadAndInstallUpdate({
    required AppUpdateInfo update,
    required void Function(double progress) onProgress,
  }) async {
    final platform = currentPlatform;

    if (platform == 'WINDOWS') {
      try {
        final tempDir = await getTemporaryDirectory();
        final savePath = '${tempDir.path}\\arike-setup-v${update.latestVersion}.exe';

        final dio = Dio();
        await dio.download(
          update.downloadUrl,
          savePath,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              onProgress(received / total);
            }
          },
        );

        onProgress(1.0);

        // Contrôle d'intégrité cryptographique SHA-256
        if (update.checksumSha256 != null && update.checksumSha256!.trim().isNotEmpty) {
          final isValid = await verifyFileSha256(savePath, update.checksumSha256!);
          if (!isValid) {
            try {
              await File(savePath).delete();
            } catch (_) {}
            throw StateError(
              'Échec du contrôle d\'intégrité SHA-256 : l\'exécutable Windows est altéré ou non authentique.',
            );
          }
        }

        // Exécuter l'installateur Windows téléchargé
        await Process.start(savePath, [], runInShell: true);
        return;
      } catch (e) {
        if (e is StateError) rethrow;
        await launchUrl(Uri.parse(update.downloadUrl), mode: LaunchMode.externalApplication);
      }
    } else if (platform == 'ANDROID') {
      try {
        final tempDir = await getTemporaryDirectory();
        final savePath = '${tempDir.path}/arike-v${update.latestVersion}.apk';

        final dio = Dio();
        await dio.download(
          update.downloadUrl,
          savePath,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              onProgress(received / total);
            }
          },
        );

        onProgress(1.0);

        // Contrôle d'intégrité cryptographique SHA-256
        if (update.checksumSha256 != null && update.checksumSha256!.trim().isNotEmpty) {
          final isValid = await verifyFileSha256(savePath, update.checksumSha256!);
          if (!isValid) {
            try {
              await File(savePath).delete();
            } catch (_) {}
            throw StateError(
              'Échec du contrôle d\'intégrité SHA-256 : le paquet APK est altéré ou non conforme.',
            );
          }
        }

        // Tenter d'ouvrir l'APK téléchargé via le système Android
        final apkUri = Uri.file(savePath);
        if (await canLaunchUrl(apkUri)) {
          await launchUrl(apkUri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (e) {
        if (e is StateError) rethrow;
      }

      // Fallback universel Android : Téléchargement et installation directe par le navigateur du téléphone
      await launchUrl(
        Uri.parse(update.downloadUrl),
        mode: LaunchMode.externalApplication,
      );
    } else {
      await launchUrl(
        Uri.parse(update.downloadUrl),
        mode: LaunchMode.externalApplication,
      );
    }
  }
}

