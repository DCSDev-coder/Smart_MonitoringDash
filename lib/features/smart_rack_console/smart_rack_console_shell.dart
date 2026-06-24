import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/controllers/global_status_poller.dart';
import '../../core/network/api_service.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/utils/app_log.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/utils/app_toast.dart';
import '../../shared/widgets/settings_overlay.dart';
import '../../shared/widgets/notifications_overlay.dart';
import 'models/smart_rack_device_profile.dart';
import 'models/smart_rack_console_snapshot.dart';
import 'smart_rack_console_screen.dart';
import 'theme/console_theme.dart';
import 'ups_console_screen.dart';
import 'widgets/coming_soon_panel.dart';
import 'widgets/console_header.dart';
import 'widgets/console_sidebar.dart';
import 'ac_console_screen.dart';
import 'power_console_screen.dart';
import 'pdu_console_screen.dart';
import 'it_device_console_screen.dart';
import 'door_console_screen.dart';
import 'pue_console_screen.dart';
import 'settings_console_screen.dart';
import 'alarm_console_screen.dart';

class SmartRackConsoleShell extends StatefulWidget {
  const SmartRackConsoleShell({
    super.key,
    this.profile = SmartRackDeviceProfiles.androidOperator,
  });

  final SmartRackDeviceProfile profile;

  @override
  State<SmartRackConsoleShell> createState() => _SmartRackConsoleShellState();
}

class _SmartRackConsoleShellState extends State<SmartRackConsoleShell> {
  int _selectedIndex = 0;
  bool _sidebarHovered = false;
  bool _sidebarSwiped = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalStatusPoller _poller = GlobalStatusPoller.instance;
  bool _accessGuardHandled = false;

  void _setSidebarHovered(bool value) {
    if (_sidebarHovered == value) return;
    setState(() => _sidebarHovered = value);
  }

  void _setSidebarSwiped(bool value) {
    if (_sidebarSwiped == value) return;
    setState(() => _sidebarSwiped = value);
  }

  bool _hasPinNotification() {
    final api = CpanelApiService.instance;
    return !api.isCurrentSiteRackConsole() && !api.hasPin;
  }

  void _showNotificationsOverlay(BuildContext context) {
    final alarms = <dynamic>[];

    if (_hasPinNotification()) {
      alarms.add({
        'isPinSetupPrompt': true,
        'alarmLevel': 'INFO',
        'alarmItem': 'Setup Security PIN',
        'content': 'Secure your door control and settings by setting up a 4-digit PIN.',
        'deviceCabinetName': 'System Security',
        'deviceCabinetItemName': 'PIN Setup Required',
      });
    }

    alarms.addAll(_poller.recentAlarms);

    NotificationsOverlay.show(
      context,
      alarms: alarms,
      onNavigateToReport: () {
        setState(() {
          _selectedIndex = 9; // Navigate to Alarm tab
        });
      },
    );
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
      AppLog.e('Logo upload exception', tag: 'LogoUpload', error: e);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0B0F14),
            title: const Text('Upload Failed',
                style: TextStyle(color: AppTheme.statusError)),
            content: Text('An unexpected error occurred: $e',
                style: const TextStyle(color: Colors.white)),
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

  @override
  void initState() {
    super.initState();
    _poller.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enforceRackConsoleAccess();
    });
  }

  @override
  void dispose() {
    _poller.stop();
    super.dispose();
  }

  Future<void> _enforceRackConsoleAccess() async {
    if (_accessGuardHandled || !mounted) return;
    _accessGuardHandled = true;

    final site = CpanelApiService.instance.currentSite;
    final allowed = site != null &&
        CpanelApiService.instance.isCurrentSiteRackConsole(site);
    if (allowed) return;

    await CpanelApiService.instance.clearSession();
    await ApiService.instance.logout();
    if (!mounted) return;

    AppToast.showError(
      context,
      'Wrong account',
    );
    Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
  }

  String _pageTitle(int index) {
    switch (index) {
      case 0:
        return 'Overview';
      case 1:
        return 'AC';
      case 2:
        return 'UPS';
      case 3:
        return 'Power';
      case 4:
        return 'PDU';
      case 5:
        return 'IT Device';
      case 6:
        return 'Door';
      case 7:
        return 'PUE';
      case 8:
        return 'Settings';
      case 9:
        return 'Alarm';
      default:
        return 'Console';
    }
  }

  Widget _buildMainContent(int index, bool compact) {
    if (index == 0) {
      return SmartRackConsoleScreen(
        profile: widget.profile,
        compact: compact,
      );
    } else if (index == 1) {
      return AcConsoleScreen(
        compact: compact,
      );
    } else if (index == 2) {
      final snapshot = SmartRackConsoleSnapshot.fromPoller(_poller);
      return UpsConsoleScreen(
        snapshot: snapshot,
      );
    } else if (index == 3) {
      final snapshot = SmartRackConsoleSnapshot.fromPoller(_poller);
      return PowerConsoleScreen(
        snapshot: snapshot,
      );
    } else if (index == 4) {
      final snapshot = SmartRackConsoleSnapshot.fromPoller(_poller);
      return PduConsoleScreen(
        snapshot: snapshot,
      );
    } else if (index == 5) {
      final snapshot = SmartRackConsoleSnapshot.fromPoller(_poller);
      return ItDeviceConsoleScreen(
        snapshot: snapshot,
      );
    } else if (index == 6) {
      final snapshot = SmartRackConsoleSnapshot.fromPoller(_poller);
      return DoorConsoleScreen(
        snapshot: snapshot,
      );
    } else if (index == 7) {
      final snapshot = SmartRackConsoleSnapshot.fromPoller(_poller);
      return PueConsoleScreen(
        snapshot: snapshot,
        compact: compact,
      );
    } else if (index == 8) {
      return SettingsConsoleScreen(
        compact: compact,
      );
    } else if (index == 9) {
      return AlarmConsoleScreen(
        compact: compact,
      );
    }
    return ComingSoonPanel(title: _pageTitle(index));
  }

  @override
  Widget build(BuildContext context) {
    final site = CpanelApiService.instance.currentSite;
    final hasAccess = site != null &&
        CpanelApiService.instance.isCurrentSiteRackConsole(site);
    if (!hasAccess) {
      return Scaffold(
        backgroundColor: ConsoleTheme.appBg(context),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final double width = MediaQuery.of(context).size.width;
    final bool isWide = width >= 750;

    if (isWide) {
      return Scaffold(
        backgroundColor: ConsoleTheme.appBg(context),
        body: SafeArea(
          child: Column(
            children: [
              ConsoleHeader(
                profile: widget.profile,
                currentPageTitle: _pageTitle(_selectedIndex),
                onProfileTap: () {
                  SettingsOverlay.show(
                    context,
                    onUploadLogo: _handleLogoUpload,
                    onGoHome: () {
                      setState(() {
                        _selectedIndex = 0;
                      });
                    },
                  );
                },
                onNotificationTap: () => _showNotificationsOverlay(context),
              ),
              Expanded(
                child: Row(
                  children: [
                    MouseRegion(
                      onEnter: (_) => _setSidebarHovered(true),
                      onExit: (_) => _setSidebarHovered(false),
                      child: GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          if (details.primaryDelta! > 5) {
                            _setSidebarSwiped(true);
                          } else if (details.primaryDelta! < -5) {
                            _setSidebarSwiped(false);
                          }
                        },
                        child: ConsoleSidebar(
                          profile: widget.profile,
                          selectedIndex: _selectedIndex,
                          isCollapsed: !(_sidebarHovered || _sidebarSwiped),
                          onItemSelected: (index) {
                            _setSidebarSwiped(false);
                            setState(() {
                              _selectedIndex = index;
                            });
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: ConsoleTheme.lg, bottom: ConsoleTheme.lg),
                        decoration: BoxDecoration(
                          color: ConsoleTheme.panelBg(context).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(ConsoleTheme.cardRadius),
                          border: Border.all(
                            color: ConsoleTheme.divider(context),
                            width: 1.0,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListenableBuilder(
                          listenable: _poller,
                          builder: (context, _) => _buildMainContent(_selectedIndex, false),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Responsive tablet/mobile layout
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: ConsoleTheme.appBg(context),
      drawer: Drawer(
        backgroundColor: ConsoleTheme.panelBg(context),
        child: SafeArea(
          child: ConsoleSidebar(
            profile: widget.profile,
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
              _scaffoldKey.currentState?.closeDrawer();
            },
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            ConsoleHeader(
              profile: widget.profile,
              currentPageTitle: _pageTitle(_selectedIndex),
              leading: IconButton(
                icon: Icon(
                  Icons.menu_rounded,
                  color: ConsoleTheme.textPrimary(context),
                ),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              onProfileTap: () {
                SettingsOverlay.show(
                  context,
                  onUploadLogo: _handleLogoUpload,
                  onGoHome: () {
                    setState(() {
                      _selectedIndex = 0;
                    });
                  },
                );
              },
              onNotificationTap: () => _showNotificationsOverlay(context),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(ConsoleTheme.xl, 0, ConsoleTheme.xl, ConsoleTheme.xl),
                decoration: BoxDecoration(
                  color: ConsoleTheme.panelBg(context).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(ConsoleTheme.cardRadius),
                  border: Border.all(
                    color: ConsoleTheme.divider(context),
                    width: 1.0,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListenableBuilder(
                  listenable: _poller,
                  builder: (context, _) => _buildMainContent(_selectedIndex, true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
