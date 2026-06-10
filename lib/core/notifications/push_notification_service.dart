import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../network/cpanel_api_service.dart';
import '../network/adapter_api_service.dart';
import '../navigation/app_navigator.dart';
import '../utils/app_log.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase may already be initialized.
  }
  AppLog.d('Background message received', tag: 'Push', fields: {
    'messageId': message.messageId,
  });
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

    AppLog.d('Init start', tag: 'Push');

    // Web push requires extra setup (service worker, VAPID key, permissions).
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyAnoPlaPA9kUOX5YIChT5M0_odKJQoD2us",
          authDomain: "smartrack-f737a.firebaseapp.com",
          projectId: "smartrack-f737a",
          storageBucket: "smartrack-f737a.firebasestorage.app",
          messagingSenderId: "1042621674847",
          appId: "1:1042621674847:web:94c69b851c89a26f25f2ea",
          measurementId: "G-XS3Z60L630",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
    AppLog.d('Firebase initialized', tag: 'Push');
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _initLocalNotifications();
    AppLog.d('Local notifications initialized', tag: 'Push');
    await _requestPermission();
    await _configureHandlers();
    await _logCurrentToken();

    _initialized = true;
    AppLog.d('Init complete', tag: 'Push');
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
    AppLog.d(
      'Permission status',
      tag: 'Push',
      fields: {'status': settings.authorizationStatus.name},
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
      AppLog.d('Foreground message', tag: 'Push', fields: {
        'keys': message.data.keys.toList(),
      });
      await _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      AppLog.d('Opened from background push', tag: 'Push', fields: {
        'keys': message.data.keys.toList(),
      });
      _handleRemoteMessage(message);
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      AppLog.d('Opened from terminated push', tag: 'Push', fields: {
        'keys': initialMessage.data.keys.toList(),
      });
      _handleRemoteMessage(initialMessage);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      AppLog.d('Token refreshed', tag: 'Push');
      syncTokenWithBackendIfPossible(token: token);
    });
  }

  Future<void> _logCurrentToken() async {
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: kIsWeb ? 'BGTU7jNSIgdc7NbBwemHlRvs6D-3HnytuCaoNYkjO917LboOG0yuQ3VL5G6x_AGhRoA6UcUuhsomLpo2-upTpXA' : null,
    );
    AppLog.d('FCM token resolved', tag: 'Push');
    if (token == null || token.isEmpty) {
      AppLog.w('FCM token is empty', tag: 'Push');
      return;
    }
    await syncTokenWithBackendIfPossible(token: token);
  }

  Future<void> syncTokenWithBackendIfPossible({String? token}) async {
    try {
      final site = CpanelApiService.instance.currentSite;
      final authToken = CpanelApiService.instance.getAuthTokenInMemory();
      final siteId = int.tryParse(
        (site?['site_id'] ?? site?['id'] ?? '').toString(),
      );

      if (siteId == null || siteId <= 0) {
        AppLog.d('Token sync skipped: site not ready', tag: 'Push');
        return;
      }
      if (authToken == null || authToken.isEmpty) {
        AppLog.d('Token sync skipped: portal auth token missing', tag: 'Push');
        return;
      }

      final resolvedToken = token ?? await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb ? 'BGTU7jNSIgdc7NbBwemHlRvs6D-3HnytuCaoNYkjO917LboOG0yuQ3VL5G6x_AGhRoA6UcUuhsomLpo2-upTpXA' : null,
      );
      if (resolvedToken == null || resolvedToken.isEmpty) {
        AppLog.d('Token sync skipped: device token missing', tag: 'Push');
        return;
      }

      AppLog.d('Attempting to sync token', tag: 'Push', fields: {
        'siteId': siteId,
        'tokenPrefix': resolvedToken.substring(0, 10),
      });

      if (_lastSyncedToken == resolvedToken && _lastSyncedSiteId == siteId) {
        AppLog.d('Token sync skipped: already registered', tag: 'Push');
        return;
      }

      final success = await AdapterApiService.instance.registerPushToken(
        siteId: siteId,
        deviceToken: resolvedToken,
        platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      );
      if (success) {
        _lastSyncedToken = resolvedToken;
        _lastSyncedSiteId = siteId;
        AppLog.i('Token registered to adapter', tag: 'Push', fields: {'siteId': siteId});
      } else {
        AppLog.w('Token register to adapter failed', tag: 'Push', fields: {
          'siteId': siteId,
        });
      }
    } catch (e) {
      AppLog.w('Token sync error', tag: 'Push', error: e);
    }
  }

  Future<void> deactivateCurrentTokenIfPossible() async {
    try {
      final site = CpanelApiService.instance.currentSite;
      final authToken = CpanelApiService.instance.getAuthTokenInMemory();
      final siteId = int.tryParse(
        (site?['site_id'] ?? site?['id'] ?? '').toString(),
      );

      if (siteId == null || siteId <= 0) {
        AppLog.d('Token removal skipped: site not ready', tag: 'Push');
        return;
      }
      if (authToken == null || authToken.isEmpty) {
        AppLog.d('Token removal skipped: portal auth token missing', tag: 'Push');
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        AppLog.d('Token removal skipped: device token missing', tag: 'Push');
        return;
      }

      final res = await CpanelApiService.instance.removePushToken(
        siteId: siteId,
        deviceToken: token,
      );
      if (res?['status'] == 'success') {
        AppLog.i('Token deactivated', tag: 'Push', fields: {'siteId': siteId});
        if (_lastSyncedToken == token && _lastSyncedSiteId == siteId) {
          _lastSyncedToken = null;
          _lastSyncedSiteId = null;
        }
      } else {
        AppLog.w('Token removal failed', tag: 'Push', fields: {
          'siteId': siteId,
          'message': (res?['message'] ?? '').toString(),
        });
      }
    } catch (e) {
      AppLog.w('Token removal error', tag: 'Push', error: e);
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? message.data['title']?.toString() ?? 'Smart Rack Alert';
    final body = message.notification?.body ?? message.data['body']?.toString() ?? 'A new alert has arrived.';

    try {
      await _localNotifications.show(
        message.hashCode,
        title,
        body,
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
        payload: message.data['screen']?.toString() ?? 'home',
      );
    } catch (e) {
      AppLog.w('Local notification failed', tag: 'Push', error: e);
    }
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
