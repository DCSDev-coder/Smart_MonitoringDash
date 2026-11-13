import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

import 'core/theme/app_theme.dart';
import 'core/network/api_service.dart';
import 'core/network/cpanel_api_service.dart';
import 'core/config/app_config.dart';
import 'core/constants/app_constants.dart';
import 'core/controllers/app_theme_controller.dart';
import 'core/controllers/global_status_poller.dart';
import 'core/controllers/smart_polling_settings.dart';
import 'core/navigation/app_navigator.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/security/app_lock_controller.dart';
import 'core/utils/app_log.dart';
import 'features/auth/auth_screen.dart';
import 'features/dashboard/dashboard_v2_screen.dart';
import 'features/smart_rack_console/smart_rack_console_shell.dart';
import 'features/admin/manage_users_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/auth/welcome_screen.dart';
import 'features/auth/setup_user_screen.dart';
import 'features/auth/boot_gate.dart';
import 'features/report/report_screen.dart';
import 'features/control/control_screen.dart';
import 'shared/widgets/floating_nav_bar.dart';
import 'shared/widgets/app_lock_gate.dart';
import 'shared/widgets/notifications_overlay.dart';
import 'shared/widgets/sticky_header_bar.dart';
import 'shared/widgets/dashboard_header.dart';
import 'shared/widgets/desktop_side_nav_rail.dart';
import 'shared/widgets/settings_overlay.dart';
import 'features/dashboard/widgets/critical_alert_banner.dart';
import 'features/rack_view/rack_view_screen.dart';
import 'features/smart_rack_console/widgets/console_header.dart';
import 'features/smart_rack_console/models/smart_rack_device_profile.dart';
import 'features/smart_rack_console/services/smart_rack_console_repository.dart';
import 'shared/utils/app_toast.dart';
import 'shared/widgets/set_pin_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/network/adapter_api_service.dart';

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
        color: const Color(0xFFD3D1D9),
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
          return Scaffold(
            backgroundColor: const Color(0xFF060B11),
            body: Center(
              child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary),
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

  // MediaKit is only needed for the non-rack-console video surfaces.
  // Skip it on rack-console builds to avoid the startup/decode overhead.
  if (!AppConfig.isRackConsoleBuild) {
    await safeInit(() async {
      MediaKit.ensureInitialized();
    });
  }

  // Initialize ApiService to load stored Server IP.
  await safeInit(ApiService.instance.init);
  // Load the saved portal session for user display.
  await safeInit(CpanelApiService.instance.init);
  // Load user preference for polling policy (best-effort).
  await safeInit(SmartPollingSettings.instance.init);
  // Load persisted theme mode (best-effort).
  await safeInit(AppThemeController.instance.init);
  // Load persisted app lock preference (best-effort).
  await safeInit(AppLockController.instance.init);
  // Firebase push setup (best-effort; no boot blocking).
  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    AppLog.d('Starting push init', tag: 'Boot');
    PushNotificationService.instance.init().catchError((e) {
      AppLog.w('Push init failed', tag: 'Boot', error: '$e');
    });
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
          title: AppConfig.appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: AppThemeController.instance.themeMode,
          scrollBehavior: MyScrollBehavior(),
          builder: (context, child) {
            final theme = Theme.of(context);
            return DefaultTextStyle(
              style: GoogleFonts.manrope(
                textStyle: theme.textTheme.bodyMedium ??
                    const TextStyle(color: Colors.white, fontSize: 14),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          initialRoute: '/boot',
          onGenerateRoute: (settings) {
            if (settings.name == '/manage_users') {
              return _slideFromRightRoute<void>(const _ManageUsersGate());
            }
            return null;
          },
          routes: {
            '/boot': (_) => const BootGate(),
            '/welcome': (_) => const WelcomeScreen(),
            '/register': (_) => const SetupUserScreen(),
            '/auth': (_) => const AuthScreen(),
            '/home': (_) => AppConfig.isRackConsoleBuild
                ? const _HomeLaunchHold(child: SmartRackConsoleShell())
                : const _HomeLaunchHold(
                    child: AppLockGate(child: MainShell()),
                  ),
            '/smart_rack_console': (_) {
              if (!AppConfig.isRackConsoleBuild) {
                return const _PermissionDeniedScreen(
                  message:
                      'Rack Console access is not available in the main Smart Monitoring app.',
                );
              }
              return const SmartRackConsoleShell();
            },
            '/profile': (_) => const ProfileScreen(),
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

class _HomeLaunchHold extends StatefulWidget {
  const _HomeLaunchHold({required this.child});

  final Widget child;

  @override
  State<_HomeLaunchHold> createState() => _HomeLaunchHoldState();
}

class _HomeLaunchHoldState extends State<_HomeLaunchHold> {
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted) {
        setState(() => _showOverlay = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          ignoring: !_showOverlay,
          child: AnimatedOpacity(
            opacity: _showOverlay ? 1 : 0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFF060B11)),
              child: SafeArea(
                child: Stack(
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Image.asset(
                          'assets/DCS_Logo/DCS Logo.png',
                          width: 220,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 28,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: 3,
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.12,
                            ),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(accent),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  final GlobalStatusPoller _poller = GlobalStatusPoller.instance;
  final GlobalKey _mobileSettingsKey = GlobalKey();
  final GlobalKey _desktopSettingsKey = GlobalKey();
  late AnimationController _headerController;
  bool _isHeaderVisible = true;

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
    return CpanelApiService.instance.currentCompanyLogoUrl();
  }

  int _getTotalNotifications() {
    int count = _poller.hasAnyIssue ? 1 : 0;
    if (_hasPinNotification()) count += 1;
    return count;
  }

  bool _hasPinNotification() {
    final api = CpanelApiService.instance;
    return !api.isCurrentSiteRackConsole() && !api.hasPin;
  }

  Future<void> _checkPinSetup() async {
    final api = CpanelApiService.instance;
    if (api.isCurrentSiteRackConsole() || api.hasPin) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('never_show_pin_prompt') == true) return;

    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SetPinDialog(showSkipOptions: true),
    );

    if (result != null &&
        result != 'skipped' &&
        result.length >= 4 &&
        mounted) {
      final pinRes = await AdapterApiService.instance.setPinDetailed(result);
      final success = pinRes != null && pinRes['status'] == 'success';
      if (mounted) {
        AppToast.show(
          context,
          success
              ? 'PIN setup successfully.'
              : (pinRes?['message']?.toString() ?? 'Failed to set PIN.'),
        );
        if (success) {
          api.currentUser ??= {};
          api.currentUser!['has_pin'] = 1;
          setState(() {});
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );

    _tabs = _computeTabs();
    _selectedIndex = _selectedIndex.clamp(0, _tabs.length - 1);
    _poller.start();
    SmartRackConsoleRepository.instance.start(
      initialSections: const {
        RackConsoleSupplementalSection.overview,
        RackConsoleSupplementalSection.power,
        RackConsoleSupplementalSection.ac,
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPinSetup();
    });
  }

  @override
  void dispose() {
    _poller.stop();
    SmartRackConsoleRepository.instance.stop();
    _headerController.dispose();
    super.dispose();
  }

  String _currentDesktopPageTitle() {
    if (_selectedIndex >= 0 && _selectedIndex < _tabs.length) {
      final tab = _tabs[_selectedIndex];
      if (tab.id == _TabId.dashboard) return 'Overview';
      return tab.label;
    }
    return 'Overview';
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

    return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Theme.of(context).brightness == Brightness.light
              ? Theme.of(context).scaffoldBackgroundColor
              : const Color(0xFF060B11),
          extendBody: true,
          body: Stack(
            children: [
              if (Theme.of(context).brightness == Brightness.dark)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: _MissionBackdrop(),
                  ),
                ),
              // ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ MAIN CONTENT AREA ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬
              Positioned.fill(
                left: isWide ? 84.0 : 0.0,
                child: Column(
                  children: [
                    if (isWide)
                      ConsoleHeader(
                        profile: SmartRackDeviceProfiles.androidOperator,
                        currentPageTitle: _currentDesktopPageTitle(),
                        menuKey: _desktopSettingsKey,
                        onNotificationTap: () =>
                            _showNotificationsOverlay(context),
                        onProfileTap: () => SettingsOverlay.show(
                          context,
                          originRect: SettingsOverlay.rectFromKey(
                              _desktopSettingsKey),
                          onUploadLogo: _handleLogoUpload,
                          onGoHome: () => _onNavTapped(0),
                        ),
                      ),
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _handleScrollNotification,
                        child: Stack(
                    children: [
                      // Global Video Background Layer
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
                              onNavigateToReport: () => _onNavTapped(3),
                              notificationCount: _getTotalNotifications(),
                              notificationCriticalGlow: _poller.hasAnyIssue,
                            );
                          }

                          if (t.id == _TabId.rackView) {
                            return RackViewScreen(isActive: active);
                          }

                          if (t.id == _TabId.control) {
                            return ControlScreen(isActive: active);
                          }

                          if (t.id == _TabId.report) {
                            return ReportScreen(isActive: active);
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
                            final totalNotifications = _getTotalNotifications();
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
                                    child: AnimatedBuilder(
                                      animation: CpanelApiService.instance,
                                      builder: (context, _) => StickyHeaderBar(
                                        glass: true,
                                        height:
                                            AppConstants.headerHeight(context) +
                                                MediaQuery.of(context)
                                                    .padding
                                                    .top,
                                        topPad:
                                            MediaQuery.of(context).padding.top,
                                        contentHeight:
                                            AppConstants.headerContentHeight,
                                        topPadding: 10,
                                        bottomPadding: 10,
                                        child: DashboardHeader(
                                          logoUrl: _companyLogoUrl(),
                                          onNotificationTap: () =>
                                              _showNotificationsOverlay(
                                                  context),
                                          onLogoTap: () => _onNavTapped(0),
                                          onMenuTap: () => SettingsOverlay.show(
                                            context,
                                            originRect:
                                                SettingsOverlay.rectFromKey(
                                                    _mobileSettingsKey),
                                            onUploadLogo: _handleLogoUpload,
                                            onGoHome: () => _onNavTapped(0),
                                          ),
                                          settingsIconKey: _mobileSettingsKey,
                                          notificationCount:
                                              totalNotifications,
                                          notificationCriticalGlow:
                                              criticalGlow,
                                        ),
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
                                barColor: Theme.of(context).brightness ==
                                        Brightness.light
                                    ? Colors.white
                                    : Colors.transparent,
                                inactiveIconColor:
                                    Theme.of(context).brightness ==
                                            Brightness.light
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
        ),
              if (isWide)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  width: 84.0,
                  child: DesktopSideNavRail(
                    selectedIndex: _selectedIndex,
                    tabs: _tabs.map((t) {
                      final label = t.id == _TabId.dashboard ? 'Overview' : t.label;
                      return DesktopNavTabItem(label: label, icon: t.icon);
                    }).toList(),
                    onSelectTab: _onNavTapped,
                  ),
                ),
            ],
          ),
        ));
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
    if (_hasPerm('can_view_control', defaultValue: true) ||
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
      AppLog.w('siteId is null',
          tag: 'LogoUpload', fields: {'siteIdStr': siteIdStr});
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
      AppToast.show(context, 'Uploading logo...');

      final bytes = await image.readAsBytes();

      final result = await CpanelApiService.instance.uploadLogo(
        siteId: siteId,
        fileBytes: bytes,
        fileName: image.name,
      );

      if (!mounted) return;

      if (result != null && result['status'] == 'success') {
        final newUrl = result['url']?.toString();
        if (newUrl != null) {
          setState(() {
            CpanelApiService.instance.updateCurrentSiteLogo(newUrl);
          });
        }
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0B0F14),
            title: Text('Success',
                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            content: const Text('Logo uploaded successfully!',
                style: TextStyle(color: Colors.white)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('OK',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary))),
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
    final List<dynamic> combined = [];
    if (_hasPinNotification()) {
      combined.add({
        'isPinSetupPrompt': true,
        'alarmItem': 'Security Action Required',
        'content': 'Please set up your Rack Access PIN.',
        'alarmLevel': 'Warning',
      });
    }
    combined.addAll(_poller.recentAlarms);

    NotificationsOverlay.show(
      context,
      alarms: combined,
      onNavigateToReport: () => _onNavTapped(3),
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
      AppToast.show(context,
          'No ${level ?? ''} alarms ${filter != null ? 'matching "$filter"' : ''}');
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

class _MissionBackdrop extends StatelessWidget {
  const _MissionBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF05080D),
            Color(0xFF091018),
            Color(0xFF0D141D),
            Color(0xFF111A24),
          ],
          stops: [0.0, 0.28, 0.68, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: const Alignment(0.92, -0.18),
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.035),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.08),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.22),
                ],
                stops: const [0.0, 0.36, 1.0],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.12, -0.08),
                radius: 1.18,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.14),
                  Colors.black.withValues(alpha: 0.34),
                ],
                stops: const [0.0, 0.58, 0.82, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
