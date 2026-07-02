import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/notifications/domain/entities/notification_entities.dart';
import 'android_notification_channels.dart';

typedef NotificationTapCallback = void Function(String deepLink);

/// Wrapper `flutter_local_notifications` — RG-NOTIF-01.
class LocalNotificationService {
  LocalNotificationService();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  NotificationTapCallback? _onTap;

  bool get isAvailable => _initialized;

  Future<void> initialize({NotificationTapCallback? onTap}) async {
    if (_initialized) return;
    _onTap = onTap;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );

    try {
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          final link = response.payload;
          if (link != null && link.isNotEmpty) {
            _onTap?.call(link);
          }
        },
      );

      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        for (final channel in AndroidNotificationChannels.all) {
          await androidPlugin?.createNotificationChannel(channel);
        }
      }

      _initialized = true;
    } catch (error) {
      debugPrint('Notifications locales indisponibles: $error');
    }
  }

  /// Indique si une demande d'autorisation système est encore nécessaire.
  Future<bool> needsPermissionRequest() async {
    if (!_initialized || kIsWeb) return false;

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await android?.areNotificationsEnabled();
      return enabled != true;
    }

    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final permissions = await ios?.checkPermissions();
      return permissions?.isEnabled != true;
    }

    if (Platform.isMacOS) {
      final mac = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      final permissions = await mac?.checkPermissions();
      return permissions?.isEnabled != true;
    }

    return false;
  }

  /// Déclenche la boîte de dialogue système (Android 13+, iOS, macOS).
  Future<void> requestSystemPermission() async {
    if (!_initialized || kIsWeb) return;

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return;
    }

    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return;
    }

    if (Platform.isMacOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<void> showItem(NotificationItem item, {int? notificationId}) async {
    if (!_initialized) return;

    final id = notificationId ?? _stableId(item);
    final channelId = AndroidNotificationChannels.channelIdFor(item.channel);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        _channelLabel(item.channel),
        importance:
            item.alwaysOn ? Importance.high : Importance.defaultImportance,
        priority:
            item.alwaysOn ? Priority.high : Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.show(
      id,
      item.title,
      item.body,
      details,
      payload: item.deepLink,
    );
  }

  Future<void> cancelDailySummary() async {
    if (!_initialized) return;
    await _plugin.cancel(NotificationIds.dailySummary);
  }

  int _stableId(NotificationItem item) {
    return Object.hash(item.code, item.dedupeKey).abs() % 0x7FFFFFFF;
  }

  String _channelLabel(String channel) => switch (channel) {
        'stock' => AndroidNotificationChannels.stock.name,
        'debt' => AndroidNotificationChannels.debt.name,
        'summary' => AndroidNotificationChannels.summary.name,
        'system' => AndroidNotificationChannels.system.name,
        'sync' => AndroidNotificationChannels.sync.name,
        _ => AndroidNotificationChannels.system.name,
      };
}

abstract final class NotificationIds {
  static const dailySummary = 9001;
  static const debtPaidBase = 9100;
}
