import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../network/cpanel_api_service.dart';
import '../navigation/app_navigator.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase may already be initialized.
  }
  debugPrint('[Push] Background message: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'smart_rack_alerts',
    'Smart Rack Alerts',
    description: 'Critical Smart Rack alerts and alarm notifications',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _lastSyncedToken;
  int? _lastSyncedSiteId;

  Future<void> init() async {
    if (_initialized) return;

    debugPrint('[Push] Init start');

    // Web push requires extra setup (service worker, VAPID key, permissions).
    // Until configured, skip to avoid noisy runtime exceptions on Flutter Web.
    if (kIsWeb) {
      debugPrint('[Push] Web: push init skipped');
      _initialized = true;
      return;
    }

    await Firebase.initializeApp();
    debugPrint('[Push] Firebase initialized');
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _initLocalNotifications();
    debugPrint('[Push] Local notifications initialized');
    await _requestPermission();
    await _configureHandlers();
    await _logCurrentToken();

    _initialized = true;
    debugPrint('[Push] Init complete');
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationTap(response.payload);
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
  }

  Future<void> _requestPermission() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
      '[Push] Permission status: ${settings.authorizationStatus.name}',
    );
  }

  Future<void> _configureHandlers() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) async {
      debugPrint('[Push] Foreground message: ${message.data}');
      await _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[Push] Opened from background push: ${message.data}');
      _handleRemoteMessage(message);
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[Push] Opened from terminated push: ${initialMessage.data}');
      _handleRemoteMessage(initialMessage);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      debugPrint('[Push] Token refreshed: $token');
      syncTokenWithBackendIfPossible(token: token);
    });
  }

  Future<void> _logCurrentToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    debugPrint('[Push] FCM token: $token');
    if (token == null || token.isEmpty) {
      debugPrint('[Push] FCM token is empty or null');
      return;
    }
    await syncTokenWithBackendIfPossible(token: token);
  }

  Future<void> syncTokenWithBackendIfPossible({String? token}) async {
    if (kIsWeb) return;
    try {
      final site = CpanelApiService.instance.currentSite;
      final authToken = CpanelApiService.instance.getAuthTokenInMemory();
      final siteId = int.tryParse(
        (site?['site_id'] ?? site?['id'] ?? '').toString(),
      );

      if (siteId == null || siteId <= 0) {
        debugPrint('[Push] Token sync skipped: current site is not ready yet');
        return;
      }
      if (authToken == null || authToken.isEmpty) {
        debugPrint('[Push] Token sync skipped: portal auth token missing');
        return;
      }

      final resolvedToken = token ?? await FirebaseMessaging.instance.getToken();
      if (resolvedToken == null || resolvedToken.isEmpty) {
        debugPrint('[Push] Token sync skipped: device token missing');
        return;
      }

      debugPrint('[Push] Attempting to sync token for site $siteId with backend...');
      debugPrint('[Push] Token: ${resolvedToken.substring(0, 10)}...');

      if (_lastSyncedToken == resolvedToken && _lastSyncedSiteId == siteId) {
        debugPrint('[Push] Token sync skipped: already registered');
        return;
      }

      final res = await CpanelApiService.instance.registerPushToken(
        siteId: siteId,
        deviceToken: resolvedToken,
      );
      if (res?['status'] == 'success') {
        _lastSyncedToken = resolvedToken;
        _lastSyncedSiteId = siteId;
        debugPrint('[Push] SUCCESS: Token registered to backend for site $siteId');
      } else {
        debugPrint('[Push] ERROR: Token register failed: ${res?['message']}');
        debugPrint('[Push] Response payload: $res');
      }
    } catch (e) {
      debugPrint('[Push] Token sync error: $e');
    }
  }

  Future<void> deactivateCurrentTokenIfPossible() async {
    if (kIsWeb) return;
    try {
      final site = CpanelApiService.instance.currentSite;
      final authToken = CpanelApiService.instance.getAuthTokenInMemory();
      final siteId = int.tryParse(
        (site?['site_id'] ?? site?['id'] ?? '').toString(),
      );

      if (siteId == null || siteId <= 0) {
        debugPrint('[Push] Token removal skipped: current site is not ready');
        return;
      }
      if (authToken == null || authToken.isEmpty) {
        debugPrint('[Push] Token removal skipped: portal auth token missing');
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[Push] Token removal skipped: device token missing');
        return;
      }

      final res = await CpanelApiService.instance.removePushToken(
        siteId: siteId,
        deviceToken: token,
      );
      if (res?['status'] == 'success') {
        debugPrint('[Push] Token deactivated on backend for site $siteId');
        if (_lastSyncedToken == token && _lastSyncedSiteId == siteId) {
          _lastSyncedToken = null;
          _lastSyncedSiteId = null;
        }
      } else {
        debugPrint('[Push] Token removal failed: ${res?['message']}');
      }
    } catch (e) {
      debugPrint('[Push] Token removal error: $e');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'Smart Rack Alert',
      notification.body ?? 'A new rack alert has been received.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: 'home',
    );
  }

  void _handleRemoteMessage(RemoteMessage message) {
    final destination = message.data['screen']?.toString() ?? 'home';
    _handleNotificationTap(destination);
  }

  void _handleNotificationTap(String? payload) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    switch (payload) {
      case 'home':
      default:
        navigator.pushNamedAndRemoveUntil('/home', (route) => false);
    }
  }
}
