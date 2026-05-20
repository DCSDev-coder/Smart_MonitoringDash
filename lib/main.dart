import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

import 'core/theme/app_theme.dart';
import 'core/network/api_service.dart';
import 'core/network/cpanel_api_service.dart';
import 'core/constants/app_constants.dart';
import 'core/controllers/app_theme_controller.dart';
import 'core/controllers/global_status_poller.dart';
import 'core/controllers/smart_polling_settings.dart';
import 'core/navigation/app_navigator.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/utils/app_log.dart';
import 'features/auth/auth_screen.dart';
import 'features/dashboard/dashboard_v2_screen.dart';
import 'features/admin/admin_webview_screen.dart';
import 'features/admin/manage_users_screen.dart';
// import 'features/cctv/cctv_screen.dart';
// import 'features/cctv/cctv_config_manager.dart';
// import 'features/cctv/cctv_settings_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/auth/welcome_screen.dart';
import 'features/auth/register_info_screen.dart';
import 'features/auth/boot_gate.dart';
import 'features/report/report_screen.dart';
import 'features/control/control_screen.dart';
import 'shared/widgets/floating_nav_bar.dart';
import 'shared/widgets/background_layer.dart';
import 'shared/widgets/notifications_overlay.dart';
import 'shared/widgets/sticky_header_bar.dart';
import 'shared/widgets/dashboard_header.dart';
import 'shared/widgets/settings_overlay.dart';
import 'shared/widgets/safe_network_image.dart';
import 'features/dashboard/widgets/critical_alert_banner.dart';
import 'features/rack_view/rack_view_screen.dart';

bool _canManageUsersFromCurrentSite({required int? portalUserId}) {
  final site = CpanelApiService.instance.currentSite;
  if (site == null) return false;

  final ownerId = int.tryParse(site['owner_user_id']?.toString() ?? '');
  if (portalUserId != null && ownerId != null && ownerId == portalUserId) {
    return true;
  }

  final role = site['role']?.toString().toLowerCase();
  if (role == 'admin') return true;

  final v = site['can_manage_users'];
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0;

  final s = v.toString().trim().toLowerCase();
  return s == '1' || s == 'true' || s == 'yes';
}

PageRouteBuilder<T> _slideFromRightRoute<T>(Widget child) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) {
      // Prevent a one-frame "flash" when the destination screen is still
      // building (e.g., video background first frame not ready).
      return ColoredBox(
        color: const Color(0xFF060B11),
        child: child,
      );
    },
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      final slide = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(curved);
      return SlideTransition(position: slide, child: child);
    },
  );
}

class _PermissionDeniedScreen extends StatelessWidget {
  const _PermissionDeniedScreen({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text('ACCESS DENIED',
            style: TextStyle(
                letterSpacing: 1.2, fontSize: 13, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppTheme.surfaceColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _ManageUsersGate extends StatelessWidget {
  const _ManageUsersGate();

  @override
  Widget build(BuildContext context) {
    final uid = CpanelApiService.instance.getUserId();
    return FutureBuilder<int?>(
      future: uid,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF060B11),
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.accentGreen),
            ),
          );
        }
        final allowed = _canManageUsersFromCurrentSite(portalUserId: snap.data);
        if (allowed) return const ManageUsersScreen();
        return const _PermissionDeniedScreen(
          message: 'You do not have permission to manage users for this site.',
        );
      },
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Avoid getting stuck on the Android 12+ splash screen if any plugin/storage
  // init hangs or throws in release. We still try to init, but we don't block
  // the first frame forever.
  Future<void> safeInit(Future<void> Function() fn) async {
    try {
      await fn().timeout(const Duration(seconds: 3));
    } catch (e) {
      AppLog.d('Safe init skipped', tag: 'Boot', fields: {'error': '$e'});
      // Continue boot even if prefs are unavailable for some reason.
    }
  }

  // MediaKit needs native libs (e.g. `libmpv.so`) bundled in the APK on Android.
  // If they're missing, it can throw and prevent app startup.
  await safeInit(() async {
    MediaKit.ensureInitialized();
  });

  // Initialize ApiService to load stored Server IP.
  await safeInit(ApiService.instance.init);
  // Load the saved portal session for user display.
  await safeInit(CpanelApiService.instance.init);
  // Load user preference for polling policy (best-effort).
  await safeInit(SmartPollingSettings.instance.init);
  // Load persisted theme mode (best-effort).
  await safeInit(AppThemeController.instance.init);
  // Android-first Firebase push setup (best-effort; no boot blocking).
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    AppLog.d('Starting Android push init', tag: 'Boot');
    await safeInit(PushNotificationService.instance.init);
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final tm = AppThemeController.instance.themeMode;
  final bool isDark = tm == ThemeMode.dark || tm == ThemeMode.system;
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
  ));
  runApp(const CigApp());
}

class MyScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Disable Android stretch/glow overscroll effects. This prevents the
    // "infinite scroll" feel where content keeps sliding past the end.
    return child;
  }
}

class CigApp extends StatelessWidget {
  const CigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'DCS Dashboard',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: AppThemeController.instance.themeMode,
          scrollBehavior: MyScrollBehavior(),
          initialRoute: '/boot',
          onGenerateRoute: (settings) {
            // CCTV Settings route hidden for compilation
            /*
            if (settings.name == '/cctv_settings') {
               final args = settings.arguments as Map<String, dynamic>;
               return _slideFromRightRoute<Map<String, dynamic>>(
                 CctvSettingsScreen(initialConfig: args),
               );
            }
            */
            if (settings.name == '/manage_users') {
              return _slideFromRightRoute<void>(const _ManageUsersGate());
            }
            return null;
          },
          routes: {
            '/boot': (_) => const BootGate(),
            '/welcome': (_) => const WelcomeScreen(),
            '/register': (_) => const RegisterInfoScreen(),
            '/auth': (_) => const AuthScreen(),
            '/home': (_) => const MainShell(),
            '/profile': (_) => const ProfileScreen(),
            '/admin_panel': (_) {
              final uid = CpanelApiService.instance.getUserId();
              return FutureBuilder<int?>(
                future: uid,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Scaffold(
                      backgroundColor: AppTheme.bgColor,
                      body: Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.accentGreen),
                      ),
                    );
                  }
                  final allowed =
                      _canManageUsersFromCurrentSite(portalUserId: snap.data);
                  if (allowed) return const AdminWebviewScreen();
                  return const _PermissionDeniedScreen(
                    message:
                        'You do not have permission to access the admin portal for this site.',
                  );
                },
              );
            },
          },
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final GlobalStatusPoller _poller = GlobalStatusPoller.instance;

  // final GlobalKey<CctvScreenState> _cctvKey = GlobalKey<CctvScreenState>();
  final GlobalKey _settingsIconKey = GlobalKey();
  late AnimationController _headerController;
  bool _isHeaderVisible = true;
  bool _sidebarExpanded = false;
  bool _sidebarUserToggled = false;

  late final List<_NavTab> _tabs;
  static const ValueKey<String> _dashboardKey =
      ValueKey<String>('dashboard_v2');

  List<String> _getAlertStrings() {
    final alerts = <String>[];
    if (_poller.hasSmokeAlert) alerts.add('Smoke Detected');
    if (_poller.hasFloodAlert) alerts.add('Flood Detected');
    return alerts;
  }

  String? _companyLogoUrl() {
    final site = CpanelApiService.instance.currentSite;
    if (site == null) return null;
    final logo = site['company_logo_path']?.toString() ?? '';
    if (logo.trim().isEmpty) return null;
    return '${CpanelApiService.baseAssetUrl}$logo';
  }

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );

    _tabs = _computeTabs();
    _selectedIndex = _selectedIndex.clamp(0, _tabs.length - 1);
    _poller.start();
  }

  @override
  void dispose() {
    _poller.stop();
    _headerController.dispose();
    super.dispose();
  }

  void _onNavTapped(int index) {
    final safeIndex = index.clamp(0, _tabs.length - 1);
    setState(() => _selectedIndex = safeIndex);
    if (!_isHeaderVisible) {
      _isHeaderVisible = true;
      _headerController.forward();
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // Keep the header always visible (dashboard-style). Hiding on scroll causes
    // jitter on heavy pages and feels inconsistent with the sticky dashboard header.
    if (!_isHeaderVisible) {
      _isHeaderVisible = true;
      _headerController.forward();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Senior Logic: Determine if we are on a Wide Screen (Tablet/Monitor)
    final double width = MediaQuery.of(context).size.width;
    final bool isWide = width >= 600;
    final bool defaultSidebarExpanded = width >= 1100;
    final bool sidebarExpanded =
        _sidebarUserToggled ? _sidebarExpanded : defaultSidebarExpanded;

    return Scaffold(
      backgroundColor: const Color(0xFF060B11),
      extendBody: true,
      body: Row(
        children: [
          // ── NAVIGATION RAIL (Wide Screen Tablet/TV) ───────
          if (isWide)
            AnimatedBuilder(
              animation: _poller,
              builder: (context, _) {
                // Keep "Alerts" consistent across the app:
                // show dot + glow whenever *any* issue exists (alarms/devices/env).
                final totalNotifications = _poller.hasAnyIssue ? 1 : 0;
                final criticalGlow = _poller.hasAnyIssue;
                return _MainSidebar(
                  expanded: sidebarExpanded,
                  selectedIndex: _selectedIndex,
                  tabs: _tabs,
                  logoUrl: _companyLogoUrl(),
                  hasNotifications: totalNotifications > 0,
                  criticalGlow: criticalGlow,
                  onSelectTab: _onNavTapped,
                  onToggleExpanded: () {
                    setState(() {
                      _sidebarExpanded = !sidebarExpanded;
                      _sidebarUserToggled = true;
                    });
                  },
                  onTapNotifications: () => _showNotificationsOverlay(context),
                  onTapSettings: () => SettingsOverlay.show(
                    context,
                    originRect: SettingsOverlay.rectFromKey(_settingsIconKey),
                    // onCctvConfig: _handleCctvSettings,
                    onUploadLogo: _handleLogoUpload,
                    onGoHome: () => _onNavTapped(0),
                  ),
                  settingsKey: _settingsIconKey,
                );
              },
            ),

          // ── MAIN CONTENT AREA ────────────────────────────
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: Stack(
                children: [
                  // Global Video Background Layer
                  const Positioned.fill(
                    child: BackgroundLayer(
                      channel: BackgroundChannel.app,
                      overlayAlpha: 0.70,
                      // Keep auth pages on video, but use a static background
                      // post-login for smoother navigation and lower GPU load.
                      staticForApp: true,
                    ),
                  ),
                  IndexedStack(
                    index: _selectedIndex,
                    children: _tabs.asMap().entries.map((entry) {
                      final i = entry.key;
                      final t = entry.value;
                      final active = _selectedIndex == i;

                      if (t.id == _TabId.dashboard) {
                        // Keep the dashboard's State alive, but pause its polling
                        // when the tab isn't visible. Global emergencies still
                        // update via GlobalStatusPoller.
                        return DashboardV2Screen(
                          key: _dashboardKey,
                          isActive: active,
                          onNotificationTap: () =>
                              _showNotificationsOverlay(context),
                          onMenuTap: null,
                          notificationCount: _poller.hasAnyIssue ? 1 : 0,
                          notificationCriticalGlow: _poller.hasAnyIssue,
                        );
                      }

                      if (t.id == _TabId.rackView) {
                        return RackViewScreen(isActive: active);
                      }

                      if (t.id == _TabId.control) {
                        return const ControlScreen();
                      }

                      if (t.id == _TabId.report) {
                        return const ReportScreen();
                      }

                      return t.screen;
                    }).toList(),
                  ),

                  // Floating Adaptive Header (phones/tablet-narrow only). Wide
                  // screens use the sidebar as the header (logo/alert/settings).
                  if (!isWide) ...[
                    // The Critical Alert Banner (Highest Priority)
                    AnimatedBuilder(
                      animation: _poller,
                      builder: (context, _) {
                        final alerts = _getAlertStrings();
                        final totalNotifications = _poller.hasAnyIssue ? 1 : 0;
                        final criticalGlow = _poller.hasAnyIssue;
                        final top = alerts.isNotEmpty ? 60.0 : 0.0;

                        return Stack(
                          children: [
                            if (alerts.isNotEmpty)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: CriticalAlertBanner(alerts: alerts),
                              ),
                            Positioned(
                              top: top,
                              left: 0,
                              right: 0,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, -1.2),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: _headerController,
                                  curve: Curves.easeInOut,
                                )),
                                child: StickyHeaderBar(
                                  glass: true,
                                  height: AppConstants.headerHeight(context) +
                                      MediaQuery.of(context).padding.top,
                                  topPad: MediaQuery.of(context).padding.top,
                                  contentHeight:
                                      AppConstants.headerContentHeight,
                                  topPadding: 10,
                                  bottomPadding: 10,
                                  child: DashboardHeader(
                                    logoUrl: _companyLogoUrl(),
                                    onNotificationTap: () =>
                                        _showNotificationsOverlay(context),
                                    onLogoTap: () => _onNavTapped(0),
                                    onMenuTap: () => SettingsOverlay.show(
                                      context,
                                      originRect: SettingsOverlay.rectFromKey(
                                          _settingsIconKey),
                                      // onCctvConfig: _handleCctvSettings,
                                      onUploadLogo: _handleLogoUpload,
                                      onGoHome: () => _onNavTapped(0),
                                    ),
                                    settingsIconKey: _settingsIconKey,
                                    notificationCount: totalNotifications,
                                    notificationCriticalGlow: criticalGlow,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                  // Floating bottom navigation (phones).
                  // Keeping this inside the content stack avoids the "cutout" effect where
                  // Scaffold's background shows around the pill on dark pages (Dashboard V2).
                  if (!isWide)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SafeArea(
                        minimum: const EdgeInsets.only(bottom: 18),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal:
                                (MediaQuery.sizeOf(context).width * 0.06)
                                    .clamp(8.0, 24.0),
                          ),
                          child: FloatingNavBar(
                            selectedIndex: _selectedIndex,
                            icons: _tabs.map((t) => t.icon).toList(),
                            labels: _tabs.map((t) => t.label).toList(),
                            onTap: _onNavTapped,
                            activeColor: const Color(0xFF00A3FF),
                            // Use full white for light mode, dark for mission control mode
                            barColor:
                                Theme.of(context).brightness == Brightness.light
                                    ? Colors.white
                                    : Colors.transparent,
                            inactiveIconColor:
                                Theme.of(context).brightness == Brightness.light
                                    ? const Color(0xFF8E8E93)
                                    : Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_NavTab> _computeTabs() {
    final tabs = <_NavTab>[];

    // 1. Dashboard
    if (_hasPerm('can_view_dashboard', defaultValue: true)) {
      tabs.add(
        _NavTab(
          id: _TabId.dashboard,
          label: 'Dashboard',
          icon: Icons.dashboard_rounded,
          // Built in the IndexedStack with `isActive` so we can pause
          // dashboard-specific polling when the tab isn't selected.
          screen: const SizedBox.shrink(),
        ),
      );
    }

    // 2. Power (Formerly Rack)
    if (_hasPerm('can_view_rack', defaultValue: true)) {
      tabs.add(
        _NavTab(
          id: _TabId.rackView,
          label: 'Power',
          icon: Icons.bolt_rounded,
          // Built in the IndexedStack with `isActive` so we can pause
          // rack polling when the tab isn't selected.
          screen: const SizedBox.shrink(),
        ),
      );
    }

    // 3. Control
    if (_hasPerm('can_view_control', defaultValue: false) ||
        _hasPerm('can_manage_users', defaultValue: false)) {
      tabs.add(
        _NavTab(
          id: _TabId.control,
          label: 'Control',
          icon: Icons.tune_rounded,
          screen: const ControlScreen(),
        ),
      );
    }

    // 4. Report
    if (_hasPerm('can_view_report', defaultValue: true)) {
      tabs.add(
        _NavTab(
          id: _TabId.report,
          label: 'Report',
          icon: Icons.assessment_rounded,
          screen: const ReportScreen(),
        ),
      );
    }

    if (tabs.isEmpty) {
      tabs.add(
        _NavTab(
          id: _TabId.noAccess,
          label: 'No Access',
          icon: Icons.block_rounded,
          screen: const _NoAccessScreen(),
        ),
      );
    }

    return tabs;
  }

  bool _hasPerm(String key, {required bool defaultValue}) {
    final site = CpanelApiService.instance.currentSite;
    if (site == null) return defaultValue;

    final value = site[key];
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;

    final s = value.toString().trim().toLowerCase();
    if (s == '1' || s == 'true' || s == 'yes') return true;
    if (s == '0' || s == 'false' || s == 'no') return false;
    return defaultValue;
  }

  Future<void> _handleLogoUpload() async {
    AppLog.d('Tap received - starting logo upload flow', tag: 'LogoUpload');
    final site = CpanelApiService.instance.currentSite;
    if (site == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0B0F14),
          title: const Text('No Site', style: TextStyle(color: Colors.white)),
          content: const Text('No active site selected.',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
          ],
        ),
      );
      return;
    }

    final siteIdStr = site['site_id']?.toString() ?? '';
    final siteId = int.tryParse(siteIdStr);
    if (siteId == null) {
      AppLog.w('siteId is null', tag: 'LogoUpload', fields: {'siteIdStr': siteIdStr});
      return;
    }

    try {
      AppLog.d('Opening gallery picker', tag: 'LogoUpload');
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      if (!mounted) return;

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Uploading logo...'), duration: Duration(seconds: 1)),
      );

      final result = await CpanelApiService.instance.uploadLogo(
        siteId: siteId,
        filePath: image.path,
        fileName: image.name,
      );

      if (!mounted) return;

      if (result != null && result['status'] == 'success') {
        final newUrl = result['url']?.toString();
        if (newUrl != null) {
          setState(() {
            // Update local site info so the UI refreshes
            CpanelApiService.instance.currentSite?['company_logo_path'] =
                newUrl;
          });
        }
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0B0F14),
            title: const Text('Success',
                style: TextStyle(color: AppTheme.accentGreen)),
            content: const Text('Logo uploaded successfully!',
                style: TextStyle(color: Colors.white)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK',
                      style: TextStyle(color: AppTheme.accentGreen))),
            ],
          ),
        );
      } else {
        final msg = result?['message']?.toString() ??
            'Upload failed. The server might have rejected the file.';
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0B0F14),
            title: const Text('Upload Failed',
                style: TextStyle(color: AppTheme.statusError)),
            content: Text(msg, style: const TextStyle(color: Colors.white)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK',
                      style: TextStyle(color: Colors.white70))),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0B0F14),
            title: const Text('Error',
                style: TextStyle(color: AppTheme.statusError)),
            content:
                Text(e.toString(), style: const TextStyle(color: Colors.white)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK',
                      style: TextStyle(color: Colors.white70))),
            ],
          ),
        );
      }
    }
  }

  void _showNotificationsOverlay(BuildContext context) {
    NotificationsOverlay.show(
      context,
      alarms: _poller.recentAlarms,
    );
  }

  // ignore: unused_element
  void _showAlarmHistory(BuildContext context,
      {String? level, String? filter}) {
    // Pre-filter the list to determine if it's empty
    final filtered = _poller.recentAlarms.where((a) {
      if (level != null) {
        final currentLevel =
            (a['alarmLevelLevel'] ?? '').toString().toUpperCase();
        if (currentLevel != level.toUpperCase()) return false;
      }
      if (filter != null) {
        final f = filter.toUpperCase();
        final content = (a['content'] ?? '').toString().toUpperCase();
        if (!content.contains(f)) return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'No ${level ?? ''} alarms ${filter != null ? 'matching "$filter"' : ''}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    NotificationsOverlay.show(
      context,
      alarms: filtered,
    );
  }
}

class _NavTab {
  final _TabId id;
  final String label;
  final IconData icon;
  final Widget screen;

  _NavTab({
    required this.id,
    required this.label,
    required this.icon,
    required this.screen,
  });
}

enum _TabId { dashboard, rackView, control, report, noAccess }

class _NoAccessScreen extends StatelessWidget {
  const _NoAccessScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: Center(
        child: Text(
          'No Access Permissions',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}

class _MainSidebar extends StatelessWidget {
  final bool expanded;
  final int selectedIndex;
  final List<_NavTab> tabs;
  final String? logoUrl;
  final bool hasNotifications;
  final bool criticalGlow;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onToggleExpanded;
  final VoidCallback onTapNotifications;
  final VoidCallback onTapSettings;
  final GlobalKey settingsKey;

  const _MainSidebar({
    required this.expanded,
    required this.selectedIndex,
    required this.tabs,
    this.logoUrl,
    required this.hasNotifications,
    required this.criticalGlow,
    required this.onSelectTab,
    required this.onToggleExpanded,
    required this.onTapNotifications,
    required this.onTapSettings,
    required this.settingsKey,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final sidebarBg =
        isLight ? const Color(0xFFF7FBFF) : const Color(0xFF0E141B);
    final sidebarBorder =
        isLight ? AppTheme.lightStroke : const Color(0x22FFFFFF);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: expanded ? 240 : 80,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: sidebarBorder)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 50),
          _buildLogo(context),
          const SizedBox(height: 40),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: tabs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final t = tabs[i];
                final active = selectedIndex == i;
                return _SidebarItem(
                  icon: t.icon,
                  label: t.label,
                  active: active,
                  expanded: expanded,
                  onTap: () => onSelectTab(i),
                );
              },
            ),
          ),
          _buildBottomActions(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return GestureDetector(
      onTap: onToggleExpanded,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 40,
        child: Row(
          mainAxisAlignment:
              expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            if (logoUrl != null)
              SafeNetworkImage(logoUrl!, width: 32, height: 32)
            else
              const Icon(Icons.blur_on_rounded,
                  color: AppTheme.accentGreen, size: 32),
            if (expanded) ...[
              const SizedBox(width: 12),
              Text(
                'DCS SMART',
                style: TextStyle(
                  color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          _SidebarItem(
            icon: Icons.notifications_none_rounded,
            label: 'Alerts',
            active: false,
            expanded: expanded,
            onTap: onTapNotifications,
            hasDot: hasNotifications,
            critical: criticalGlow,
          ),
          const SizedBox(height: 8),
          _SidebarItem(
            key: settingsKey,
            icon: Icons.settings_outlined,
            label: 'Settings',
            active: false,
            expanded: expanded,
            onTap: onTapSettings,
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool expanded;
  final VoidCallback onTap;
  final bool hasDot;
  final bool critical;

  const _SidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.expanded,
    required this.onTap,
    this.hasDot = false,
    this.critical = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final c = active
        ? AppTheme.accentGreen
        : (isLight
            ? AppTheme.lightTextSecondary.withValues(alpha: 0.90)
            : Colors.white.withValues(alpha: 0.7));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 0),
        decoration: BoxDecoration(
          color: active
              ? (isLight
                  ? AppTheme.accentGreen.withValues(alpha: 0.14)
                  : AppTheme.accentGreen.withValues(alpha: 0.1))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isLight && active
              ? Border.all(
                  color: AppTheme.accentGreen.withValues(alpha: 0.20),
                )
              : null,
        ),
        child: expanded
            ? Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Icon(icon, color: c, size: 24),
                      if (hasDot)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: critical
                                  ? AppTheme.statusError
                                  : AppTheme.accentGreen,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isLight
                                    ? const Color(0xFFF7FBFF)
                                    : const Color(0xFF0E141B),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Stack(
                  children: [
                    Icon(icon, color: c, size: 24),
                    if (hasDot)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: critical
                                ? AppTheme.statusError
                                : AppTheme.accentGreen,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isLight
                                  ? const Color(0xFFF7FBFF)
                                  : const Color(0xFF0E141B),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
