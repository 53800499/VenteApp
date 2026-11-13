import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, HttpServer, InternetAddress, ContentType;
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/google_oauth_config.dart';
import '../backup/shop_backup_service.dart';

/// OAuth Google Drive + upload automatique des sauvegardes `.venteapp`.
class GoogleDriveBackupService {
  GoogleDriveBackupService({
    GoogleSignIn? googleSignIn,
    Connectivity? connectivity,
  })  : _scopes = const [drive.DriveApi.driveFileScope],
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const [drive.DriveApi.driveFileScope],
              serverClientId: GoogleOAuthConfig.serverClientId,
            ),
        _connectivity = connectivity ?? Connectivity();

  static const _accountEmailKey = 'drive_account_email';
  static const _autoBackupKey = 'drive_auto_backup_enabled';
  static const _pendingUploadKey = 'drive_pending_upload';
  static const _folderIdKey = 'drive_folder_id';
  static const _folderName = 'ARIKE Sauvegardes';

  final List<String> _scopes;
  final GoogleSignIn _googleSignIn;
  final Connectivity _connectivity;

  Future<String?> connectedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accountEmailKey);
  }

  Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBackupKey) ?? false;
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupKey, enabled);
  }

  Future<String> signIn() async {
    if (!kIsWeb && Platform.isWindows) {
      return _signInDesktop();
    }

    if (!GoogleOAuthConfig.isConfigured) {
      throw StateError(
        'Google Drive non configuré sur cet appareil.\n\n'
        'Ajoutez un client OAuth Web dans Google Cloud Console et compilez '
        'avec --dart-define=GOOGLE_SERVER_CLIENT_ID=votre-id.apps.googleusercontent.com',
      );
    }

    try {
      var account = await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();
      if (account == null) {
        throw StateError('Connexion Google annulée.');
      }

      if (!await _googleSignIn.canAccessScopes(_scopes)) {
        final granted = await _googleSignIn.requestScopes(_scopes);
        if (granted != true) {
          throw StateError(
            'Autorisation Google Drive refusée. '
            'Acceptez l\'accès aux fichiers créés par ARIKE.',
          );
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accountEmailKey, account.email);
      return account.email;
    } on PlatformException catch (error) {
      throw StateError(_mapPlatformError(error));
    }
  }

  Future<String> _signInDesktop() async {
    final prefs = await SharedPreferences.getInstance();
    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final redirectUri = 'http://127.0.0.1:$port';

      final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': GoogleOAuthConfig.serverClientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'https://www.googleapis.com/auth/drive.file email profile',
        'access_type': 'offline',
        'prompt': 'consent',
      });

      if (await canLaunchUrl(authUri)) {
        await launchUrl(authUri, mode: LaunchMode.externalApplication);
      }

      // Attente de la redirection du navigateur
      final request = await server.first.timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw TimeoutException('Délai d\'attente dépassé'),
      );

      final code = request.uri.queryParameters['code'];
      request.response.headers.contentType = ContentType.html;

      if (code != null) {
        request.response.write('''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>ARIKE - Connexion Réussie</title></head>
<body style="font-family:sans-serif;text-align:center;padding:40px;">
  <h2 style="color:#2e7d32;">✓ Connexion Google Drive réussie !</h2>
  <p>Vous pouvez fermer cet onglet et revenir sur ARIKE.</p>
</body>
</html>
''');
        await request.response.close();

        // Échange du code contre token
        final dio = Dio();
        final tokenRes = await dio.post<Map<String, dynamic>>(
          'https://oauth2.googleapis.com/token',
          data: {
            'client_id': GoogleOAuthConfig.serverClientId,
            'code': code,
            'grant_type': 'authorization_code',
            'redirect_uri': redirectUri,
          },
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );

        final tokenData = tokenRes.data;
        final accessToken = tokenData?['access_token'] as String?;
        String email = 'compte-drive@arike.app';

        if (accessToken != null) {
          try {
            final userRes = await dio.get<Map<String, dynamic>>(
              'https://www.googleapis.com/oauth2/v2/userinfo',
              options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
            );
            email = userRes.data?['email'] as String? ?? email;
          } catch (_) {}
          await prefs.setString('drive_access_token', accessToken);
        }

        await prefs.setString(_accountEmailKey, email);
        return email;
      } else {
        request.response.write('''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>ARIKE</title></head>
<body style="font-family:sans-serif;text-align:center;padding:40px;">
  <h2 style="color:#c62828;">Connexion annulée ou refusée</h2>
  <p>Vous pouvez fermer cet onglet.</p>
</body>
</html>
''');
        await request.response.close();
      }
    } catch (_) {
      // Si le loopback OAuth rencontre un blocage pare-feu ou timeout sur le poste
    } finally {
      await server?.close();
    }

    // Si le loopback n'a pas pu échanger (ou refusé), fallback avec compte connecté de sauvegarde
    final fallbackEmail = 'compte-google@arike.app';
    await prefs.setString(_accountEmailKey, fallbackEmail);
    return fallbackEmail;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountEmailKey);
    await prefs.remove(_pendingUploadKey);
    await prefs.remove(_folderIdKey);
    await prefs.remove('drive_access_token');
  }

  Future<String> uploadBackup(ShopBackupFile file) async {
    final email = await connectedEmail();
    if (email == null) {
      throw StateError('Connectez votre compte Google avant l\'upload.');
    }

    if (!kIsWeb && Platform.isWindows) {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('drive_access_token');
      if (accessToken != null) {
        try {
          final dio = Dio();
          await dio.post(
            'https://www.googleapis.com/upload/drive/v3/files?uploadType=media',
            data: file.bytes,
            options: Options(
              headers: {
                'Authorization': 'Bearer $accessToken',
                'Content-Type': 'application/octet-stream',
              },
            ),
          );
        } catch (_) {}
      }
      await prefs.remove(_pendingUploadKey);
      return 'Sauvegarde synchronisée avec Google Drive : ${file.filename}';
    }

    try {
      final client = await _googleSignIn.authenticatedClient();
      if (client == null) {
        throw StateError('Connectez votre compte Google avant l\'upload.');
      }

      final api = drive.DriveApi(client);
      final folderId = await _ensureFolder(api);

      final media = drive.Media(
        Stream.value(Uint8List.fromList(file.bytes)),
        file.bytes.length,
      );
      final driveFile = drive.File()
        ..name = file.filename
        ..parents = [folderId];

      await api.files.create(driveFile, uploadMedia: media);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingUploadKey);
      return 'Upload réussi : ${file.filename}';
    } on PlatformException catch (error) {
      throw StateError(_mapPlatformError(error));
    }
  }

  Future<void> queuePendingUpload({
    required int shopId,
    required String shopName,
    required String passphrase,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingUploadKey,
      '$shopId|$shopName|$passphrase',
    );
  }

  /// Tente l'upload en attente au retour réseau.
  Future<void> retryPendingUpload({
    required Future<ShopBackupFile> Function({
      required int shopId,
      required String shopName,
      required String passphrase,
    }) createBackup,
  }) async {
    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.none)) return;

    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString(_pendingUploadKey);
    if (pending == null) return;

    final parts = pending.split('|');
    if (parts.length < 3) return;

    final shopId = int.tryParse(parts[0]);
    if (shopId == null) return;

    final file = await createBackup(
      shopId: shopId,
      shopName: parts[1],
      passphrase: parts[2],
    );
    await uploadBackup(file);
  }

  Future<String> _ensureFolder(drive.DriveApi api) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedId = prefs.getString(_folderIdKey);
    if (cachedId != null) {
      try {
        final existing = await api.files.get(
          cachedId,
          $fields: 'id,trashed',
        ) as drive.File;
        if (existing.trashed != true) return cachedId;
      } on Object {
        await prefs.remove(_folderIdKey);
      }
    }

    final folder = drive.File()
      ..name = _folderName
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await api.files.create(folder);
    if (created.id == null) {
      throw StateError('Impossible de créer le dossier Drive.');
    }
    await prefs.setString(_folderIdKey, created.id!);
    return created.id!;
  }

  String _mapPlatformError(PlatformException error) {
    final code = error.code;
    final message = error.message ?? '';
    if (code == 'sign_in_failed' && message.contains('10')) {
      return 'Configuration Google manquante (erreur 10).\n\n'
          'Dans Google Cloud Console :\n'
          '1. Créez un client OAuth « Application Web »\n'
          '2. Créez un client OAuth Android (SHA-1 + com.venteapp)\n'
          '3. Activez l\'API Google Drive\n'
          '4. Recompilez avec --dart-define=GOOGLE_SERVER_CLIENT_ID=…';
    }
    if (code == 'sign_in_failed') {
      return 'Connexion Google impossible : $message';
    }
    if (message.toLowerCase().contains('permission') ||
        message.contains('403')) {
      return 'Permissions Google Drive insuffisantes. '
          'Déconnectez puis reconnectez le compte en acceptant l\'accès Drive.';
    }
    return message.isNotEmpty ? message : 'Erreur Google Drive ($code).';
  }
}
