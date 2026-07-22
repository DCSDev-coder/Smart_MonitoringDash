import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../controllers/global_status_poller.dart';
import '../network/cpanel_api_service.dart';
import '../network/adapter_api_service.dart';
import '../navigation/app_navigator.dart';
import '../config/app_config.dart';
import '../utils/app_log.dart';
import '../../firebase_options.dart';

const AndroidNotificationChannel _smartRackAlertsChannel =
    AndroidNotificationChannel(
  'smart_rack_alerts',
  'Smart Rack Alerts',
  description: 'Critical Smart Rack alerts and alarm notifications',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin _backgroundLocalNotifications =
    FlutterLocalNotificationsPlugin();

bool _backgroundLocalNotificationsInitialized = false;

bool _isLocalWebDevHost() {
  if (!kIsWeb) return false;
  final host = Uri.base.host.trim().toLowerCase();
  return host.isEmpty || host == 'localhost' || host == '127.0.0.1';
}

Future<void> _ensureBackgroundLocalNotificationsInitialized() async {
  if (_backgroundLocalNotificationsInitialized) return;

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwinSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: darwinSettings,
  );

  await _backgroundLocalNotifications.initialize(initSettings);

  final androidPlugin =
      _backgroundLocalNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(_smartRackAlertsChannel);
  _backgroundLocalNotificationsInitialized = true;
}

String _messageTitle(RemoteMessage message) {
  return message.notification?.title ??
      message.data['title']?.toString() ??
      'Smart Rack Alert';
}

String _messageBody(RemoteMessage message) {
  return message.notification?.body ??
      message.data['body']?.toString() ??
      'A new alert has arrived.';
}

String _messagePayload(RemoteMessage message) {
  return message.data['screen']?.toString() ?? 'home';
}

Future<void> _showNotificationWithPlugin(
  FlutterLocalNotificationsPlugin plugin, {
  required int id,
  required String title,
  required String body,
  String payload = 'home',
}) async {
  await plugin.show(
    id,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _smartRackAlertsChannel.id,
        _smartRackAlertsChannel.name,
        channelDescription: _smartRackAlertsChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: payload,
  );
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (AppConfig.isRackConsoleBuild) {
    return;
  }
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase may already be initialized.
  }
  AppLog.d('Background message received', tag: 'Push', fields: {
    'messageId': message.messageId,
  });

  // Android can receive data-only FCM messages in the background. Convert
  // them into a visible notification so alerts are not silently dropped.
  if (defaultTargetPlatform == TargetPlatform.android &&
      message.notification == null) {
    final dataTitle = message.data['title']?.toString();
    final dataBody = message.data['body']?.toString();
    if ((dataTitle == null || dataTitle.isEmpty) &&
        (dataBody == null || dataBody.isEmpty)) {
      return;
    }

    try {
      await _ensureBackgroundLocalNotificationsInitialized();
      await _showNotificationWithPlugin(
        _backgroundLocalNotifications,
        id: message.messageId.hashCode ^ message.data.hashCode,
        title: _messageTitle(message),
        body: _messageBody(message),
        payload: _messagePayload(message),
      );
    } catch (e) {
      AppLog.w('Background local notification failed', tag: 'Push', error: e);
    }
  }
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const Duration _pollerNotificationFreshnessWindow =
      Duration(minutes: 2);

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _pollerBound = false;
  bool _pollerBaselineCaptured = false;
  DateTime? _pollerBaselineCapturedAt;
  String? _lastSyncedToken;
  int? _lastSyncedSiteId;
  String? _lastAlarmSignature;
  String? _lastDoorLogSignature;
  bool _lastHadIssue = false;
  Future<void>? _initFuture;

  Future<void> init() {
    if (_initialized) return Future.value();
    return _initFuture ??= _initInternal();
  }

  Future<void> _initInternal() async {
    try {
      if (AppConfig.isRackConsoleBuild) {
        AppLog.d('Push init skipped for rack console build', tag: 'Push');
        _initialized = true;
        return;
      }
      if (_isLocalWebDevHost()) {
        AppLog.d('Push init skipped on local web dev host',
            tag: 'Push', fields: {'host': Uri.base.host});
        _initialized = true;
        return;
      }

      AppLog.d('Init start', tag: 'Push');

      // Web push requires extra setup (service worker, VAPID key,
      // permissions).
      if (kIsWeb) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      AppLog.d('Firebase initialized', tag: 'Push');
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _initLocalNotifications();
      AppLog.d('Local notifications initialized', tag: 'Push');
      await _requestPermission();
      await _configureHandlers();
      await _logCurrentToken();

      _initialized = true;
      _bindPoller();
      AppLog.d('Init complete', tag: 'Push');
    } finally {
      _initFuture = null;
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationTap(response.payload);
      },
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_smartRackAlertsChannel);
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

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }
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

  void _bindPoller() {
    if (_pollerBound) return;
    GlobalStatusPoller.instance.addListener(_handlePollerUpdate);
    _pollerBound = true;
  }

  void _handlePollerUpdate() {
    _syncPollerDrivenNotifications().catchError((error) {
      AppLog.w(
        'Poller notification sync failed',
        tag: 'Push',
        error: error,
      );
    });
  }

  Future<void> _logCurrentToken() async {
    if (_isLocalWebDevHost()) {
      AppLog.d('FCM token sync skipped on local web dev host',
          tag: 'Push',
          fields: {
            'host': Uri.base.host,
          });
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        AppLog.d(
          'APNs token state',
          tag: 'Push',
          fields: {
            'hasApnsToken': apnsToken != null && apnsToken.isNotEmpty,
          },
        );
      } catch (e) {
        AppLog.w('APNs token check failed', tag: 'Push', error: e);
      }
    }

    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: kIsWeb
          ? 'BGTU7jNSIgdc7NbBwemHlRvs6D-3HnytuCaoNYkjO917LboOG0yuQ3VL5G6x_AGhRoA6UcUuhsomLpo2-upTpXA'
          : null,
    );
    AppLog.d('FCM token resolved', tag: 'Push');
    if (token == null || token.isEmpty) {
      AppLog.w('FCM token is empty', tag: 'Push');
      return;
    }
    await syncTokenWithBackendIfPossible(token: token);
  }

  Future<String?> _resolveDeviceToken({
    String? token,
    Duration timeout = const Duration(seconds: 8),
    Duration retryInterval = const Duration(milliseconds: 500),
  }) async {
    if (token != null && token.isNotEmpty) return token;
    if (kIsWeb) {
      return FirebaseMessaging.instance.getToken(
        vapidKey:
            'BGTU7jNSIgdc7NbBwemHlRvs6D-3HnytuCaoNYkjO917LboOG0yuQ3VL5G6x_AGhRoA6UcUuhsomLpo2-upTpXA',
      );
    }

    final deadline = DateTime.now().add(timeout);
    String? resolved;
    while (DateTime.now().isBefore(deadline)) {
      try {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          AppLog.d(
            'Resolve token attempt',
            tag: 'Push',
            fields: {
              'platform': 'ios',
              'hasApnsToken': apnsToken != null && apnsToken.isNotEmpty,
            },
          );
        }
        resolved = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        AppLog.w('Device token resolve attempt failed', tag: 'Push', error: e);
      }
      if (resolved != null && resolved.isNotEmpty) return resolved;
      await Future.delayed(retryInterval);
    }
    return null;
  }

  Future<bool> syncTokenWithBackendIfPossible({String? token}) async {
    if (AppConfig.isRackConsoleBuild) {
      return true;
    }
    if (_isLocalWebDevHost()) {
      AppLog.d('Token sync skipped on local web dev host',
          tag: 'Push',
          fields: {
            'host': Uri.base.host,
          });
      return true;
    }
    try {
      final site = CpanelApiService.instance.currentSite;
      final authToken = CpanelApiService.instance.getAuthTokenInMemory();
      final siteId = int.tryParse(
        (site?['site_id'] ?? site?['id'] ?? '').toString(),
      );

      if (siteId == null || siteId <= 0) {
        AppLog.d('Token sync skipped: site not ready', tag: 'Push');
        return false;
      }
      if (authToken == null || authToken.isEmpty) {
        AppLog.d('Token sync skipped: portal auth token missing', tag: 'Push');
        return false;
      }

      final resolvedToken = await _resolveDeviceToken(token: token);
      if (resolvedToken == null || resolvedToken.isEmpty) {
        AppLog.d('Token sync skipped: device token missing', tag: 'Push');
        return false;
      }

      AppLog.d('Attempting to sync token', tag: 'Push', fields: {
        'siteId': siteId,
        'tokenPrefix': resolvedToken.substring(0, 10),
      });

      if (_lastSyncedToken == resolvedToken && _lastSyncedSiteId == siteId) {
        AppLog.d('Token sync skipped: already registered', tag: 'Push');
        return true;
      }

      final success = await AdapterApiService.instance.registerPushToken(
        siteId: siteId,
        deviceToken: resolvedToken,
        platform:
            defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      );
      if (success) {
        _lastSyncedToken = resolvedToken;
        _lastSyncedSiteId = siteId;
        AppLog.i('Token registered to adapter',
            tag: 'Push', fields: {'siteId': siteId});
        return true;
      } else {
        AppLog.w('Token register to adapter failed', tag: 'Push', fields: {
          'siteId': siteId,
        });
        return false;
      }
    } catch (e) {
      AppLog.w('Token sync error', tag: 'Push', error: e);
      return false;
    }
  }

  Future<bool> ensureTokenRegistered({
    Duration timeout = const Duration(seconds: 30),
    Duration retryInterval = const Duration(seconds: 1),
  }) async {
    if (AppConfig.isRackConsoleBuild) {
      return true;
    }
    if (_isLocalWebDevHost()) {
      AppLog.d('Token registration skipped on local web dev host',
          tag: 'Push',
          fields: {
            'host': Uri.base.host,
          });
      return true;
    }

    try {
      await init();
    } catch (e) {
      AppLog.w(
        'Token registration skipped: push init failed',
        tag: 'Push',
        error: e,
      );
      return false;
    }

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await syncTokenWithBackendIfPossible()) {
        return true;
      }
      await Future.delayed(retryInterval);
    }

    AppLog.w(
      'Token sync wait timed out',
      tag: 'Push',
      fields: {
        'timeoutMs': timeout.inMilliseconds,
        'siteReady': CpanelApiService.instance.currentSite != null,
      },
    );
    return false;
  }

  Future<void> _syncPollerDrivenNotifications() async {
    if (!_initialized || AppConfig.isRackConsoleBuild) {
      return;
    }

    final poller = GlobalStatusPoller.instance;
    final latestAlarm = _latestMap(poller.recentAlarms);
    final latestDoorLog = poller.recentDoorLogs.isEmpty
        ? null
        : Map<String, dynamic>.from(poller.recentDoorLogs.first);
    final hadIssue = poller.hasAnyIssue;
    final alarmSignature = _alarmSignature(latestAlarm);
    final doorSignature = _doorLogSignature(latestDoorLog);
    final freshAlarm = _isAlarmFresh(latestAlarm);
    final freshDoorLog = _isDoorLogFresh(latestDoorLog);

    if (!_pollerBaselineCaptured) {
      _pollerBaselineCaptured = true;
      _pollerBaselineCapturedAt = DateTime.now();
      _lastHadIssue = hadIssue;
      _lastAlarmSignature = alarmSignature;
      _lastDoorLogSignature = doorSignature;
      return;
    }

    final alarmTimestamp = _parseEventTime(
      latestAlarm?['alarmRecordTime'] ??
          latestAlarm?['alarmTime'] ??
          latestAlarm?['createdAt'],
    );
    final doorTimestamp = _parseEventTime(
      latestDoorLog?['opTime'] ??
          latestDoorLog?['time'] ??
          latestDoorLog?['recordTime'],
    );

    final hasNewAlarm =
        latestAlarm != null &&
        alarmSignature != _lastAlarmSignature &&
        freshAlarm &&
        _isEventAfterPollerBaseline(alarmTimestamp);
    final hasNewDoorLog =
        latestDoorLog != null &&
        doorSignature != _lastDoorLogSignature &&
        freshDoorLog &&
        _isEventAfterPollerBaseline(doorTimestamp);
    final newlyEnteredIssueState = hadIssue && !_lastHadIssue;

    if (hasNewAlarm) {
      await _showLocalNotification(
        id: alarmSignature.hashCode,
        title: _alarmNotificationTitle(latestAlarm),
        body: _alarmNotificationBody(latestAlarm),
      );
    } else if (newlyEnteredIssueState) {
      await _showLocalNotification(
        id: _issueNotificationId(poller),
        title: _issueNotificationTitle(poller),
        body: _issueNotificationBody(poller),
      );
    }

    if (hasNewDoorLog) {
      await _showLocalNotification(
        id: doorSignature.hashCode,
        title: 'Door Access Activity',
        body: _doorLogNotificationBody(latestDoorLog),
      );
    }

    _lastHadIssue = hadIssue;
    _lastAlarmSignature = alarmSignature;
    _lastDoorLogSignature = doorSignature;
  }

  Future<void> deactivateCurrentTokenIfPossible() async {
    if (AppConfig.isRackConsoleBuild) {
      return;
    }
    if (_isLocalWebDevHost()) {
      AppLog.d('Token removal skipped on local web dev host',
          tag: 'Push',
          fields: {
            'host': Uri.base.host,
          });
      return;
    }
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
        AppLog.d('Token removal skipped: portal auth token missing',
            tag: 'Push');
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
    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'Smart Rack Alert';
    final body = message.notification?.body ??
        message.data['body']?.toString() ??
        'A new alert has arrived.';

    await _showLocalNotification(
      id: message.hashCode,
      title: title,
      body: body,
      payload: _messagePayload(message),
    );
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String payload = 'home',
  }) async {
    try {
      await _showNotificationWithPlugin(
        _localNotifications,
        id: id,
        title: title,
        body: body,
        payload: payload,
      );
    } catch (e) {
      AppLog.w('Local notification failed', tag: 'Push', error: e);
    }
  }

  Map<String, dynamic>? _latestMap(List<dynamic> items) {
    if (items.isEmpty) return null;
    final first = items.first;
    if (first is! Map) return null;
    return Map<String, dynamic>.from(first);
  }

  String? _alarmSignature(Map<String, dynamic>? alarm) {
    if (alarm == null) return null;
    return [
      alarm['alarmRecordTime'],
      alarm['alarmTime'],
      alarm['createdAt'],
      alarm['alarmItem'],
      alarm['content'],
      alarm['collectControlNodeName'],
      alarm['deviceCabinetName'],
      alarm['deviceCabinetItemName'],
    ].map((part) => part?.toString() ?? '').join('|');
  }

  DateTime? _parseEventTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is num) {
      final millis = raw > 1000000000000 ? raw.toInt() : raw.toInt() * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }

    var text = raw.toString().trim();
    if (text.isEmpty) return null;
    if (text == '--') return null;

    if (!text.contains('T') && text.contains(' ')) {
      text = text.replaceFirst(' ', 'T');
    }

    return DateTime.tryParse(text);
  }

  bool _isEventFresh(DateTime? timestamp) {
    if (timestamp == null) return false;
    final now = DateTime.now();
    final age = now.difference(timestamp);
    if (age.isNegative) return false;
    return age <= _pollerNotificationFreshnessWindow;
  }

  bool _isEventAfterPollerBaseline(DateTime? timestamp) {
    if (timestamp == null) return false;
    final baseline = _pollerBaselineCapturedAt;
    if (baseline == null) return false;

    // Allow a small tolerance for server/device clock skew.
    return !timestamp.isBefore(baseline.subtract(const Duration(seconds: 5)));
  }

  bool _isAlarmFresh(Map<String, dynamic>? alarm) {
    final timestamp = _parseEventTime(
      alarm?['alarmRecordTime'] ?? alarm?['alarmTime'] ?? alarm?['createdAt'],
    );
    return _isEventFresh(timestamp);
  }

  String _alarmNotificationTitle(Map<String, dynamic> alarm) {
    final raw = (alarm['alarmItem'] ??
            alarm['collectControlNodeName'] ??
            alarm['content'] ??
            'Smart Rack Alert')
        .toString()
        .trim();
    if (raw.isEmpty) return 'Smart Rack Alert';
    return raw.length > 48 ? '${raw.substring(0, 48)}...' : raw;
  }

  String _alarmNotificationBody(Map<String, dynamic> alarm) {
    final content = (alarm['content'] ?? '').toString().trim();
    if (content.isNotEmpty) return content;

    final cabinet = (alarm['deviceCabinetName'] ?? alarm['locationName'] ?? '')
        .toString()
        .trim();
    final item = (alarm['deviceCabinetItemName'] ?? alarm['name'] ?? '')
        .toString()
        .trim();
    if (cabinet.isNotEmpty && item.isNotEmpty) {
      return '$cabinet / $item';
    }
    if (cabinet.isNotEmpty) return cabinet;
    if (item.isNotEmpty) return item;
    return 'A new alert has arrived.';
  }

  int _issueNotificationId(GlobalStatusPoller poller) {
    return [
      poller.hasSmokeAlert,
      poller.hasFloodAlert,
      poller.devices.length,
      poller.recentAlarms.length,
    ].join('|').hashCode;
  }

  String _issueNotificationTitle(GlobalStatusPoller poller) {
    if (poller.hasSmokeAlert) return 'Smoke Alert';
    if (poller.hasFloodAlert) return 'Flood Alert';
    if (poller.devices.any(_deviceHasIssue)) return 'Equipment Issue Detected';
    return 'Smart Rack Alert';
  }

  String _issueNotificationBody(GlobalStatusPoller poller) {
    if (poller.hasSmokeAlert && poller.hasFloodAlert) {
      return 'Smoke and flood sensors both reported an active issue.';
    }
    if (poller.hasSmokeAlert) {
      return 'Smoke sensor reported an active issue. Please inspect the rack.';
    }
    if (poller.hasFloodAlert) {
      return 'Flood sensor reported an active issue. Please inspect the rack.';
    }

    final affectedDevices = poller.devices.where(_deviceHasIssue).length;
    if (affectedDevices > 0) {
      return affectedDevices == 1
          ? '1 device group is reporting abnormal status.'
          : '$affectedDevices device groups are reporting abnormal status.';
    }
    return 'A new issue has been detected in Smart Monitoring.';
  }

  bool _deviceHasIssue(Map<String, dynamic> device) {
    final normalRaw = device['normalCount'];
    final totalRaw = device['totalCount'];
    final normal =
        normalRaw is num ? normalRaw.toInt() : int.tryParse('$normalRaw') ?? 0;
    final total =
        totalRaw is num ? totalRaw.toInt() : int.tryParse('$totalRaw') ?? 0;
    return total > 0 && normal != total;
  }

  String? _doorLogSignature(Map<String, dynamic>? log) {
    if (log == null) return null;
    return [
      log['opTime'],
      log['time'],
      log['opUser'],
      log['openUser'],
      log['userName'],
      log['username'],
      log['accessName'],
      log['doorName'],
      log['channel'],
      log['opType'],
    ].map((part) => part?.toString() ?? '').join('|');
  }

  String _doorLogNotificationBody(Map<String, dynamic> log) {
    final user = (log['opUser'] ??
            log['openUser'] ??
            log['userName'] ??
            log['username'] ??
            log['user'] ??
            'A user')
        .toString()
        .trim();
    final door =
        (log['accessName'] ?? log['doorName'] ?? 'a door').toString().trim();
    final action = (log['opType'] ?? '').toString().trim();
    if (action.isNotEmpty) {
      return '$user triggered $action on $door.';
    }
    return '$user accessed $door.';
  }

  bool _isDoorLogFresh(Map<String, dynamic>? log) {
    final timestamp = _parseEventTime(
      log?['opTime'] ?? log?['time'] ?? log?['recordTime'],
    );
    return _isEventFresh(timestamp);
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
