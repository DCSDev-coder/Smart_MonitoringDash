import 'package:flutter/material.dart';

import '../../core/auth/session_flow_service.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/controllers/app_theme_controller.dart';
import '../../core/security/app_lock_controller.dart';
import '../../core/security/secure_action_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_log.dart';
import '../../features/dashboard/widgets/dashboard_typography.dart';
import '../../features/settings/control_presets_screen.dart';
import '../../features/settings/export_pdf_screen.dart';
import '../../features/smart_rack_console/services/rack_console_preferences.dart';
import 'safe_network_image.dart';
import 'glass_confirm_dialog.dart';
import 'reset_password_dialog.dart';
import 'secure_action_guard.dart';
import 'set_pin_dialog.dart';
import '../../core/network/adapter_api_service.dart';
import '../../core/notifications/push_notification_service.dart';
import '../utils/app_toast.dart';
import '../../features/smart_rack_console/theme/console_theme.dart';

class SettingsOverlay {
  static Rect? rectFromKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final ro = ctx.findRenderObject();
    if (ro is! RenderBox) return null;
    if (!ro.hasSize) return null;

    final topLeft = ro.localToGlobal(Offset.zero);
    final rect = Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      ro.size.width,
      ro.size.height,
    );
    // A tiny inflation reads better than animating from a 24x24 icon box.
    return rect.inflate(6);
  }

  static Future<void> show(
    BuildContext context, {
    Rect? originRect,
    Future<void> Function()? onUploadLogo,
    VoidCallback? onGoHome,
  }) {
    final nav = Navigator.of(context);
    return nav.push<void>(
      _SettingsOverlayRoute(
        onManageUsers: () {
          // Push instead of replace so that popping the manage users page
          // returns the user back to the settings overlay.
          nav.pushNamed('/manage_users');
        },
        onUploadLogo: onUploadLogo,
        onGoHome: onGoHome,
      ),
    );
  }
}

class _SettingsOverlayRoute extends PopupRoute<void> {
  final VoidCallback onManageUsers;
  final Future<void> Function()? onUploadLogo;
  final VoidCallback? onGoHome;

  _SettingsOverlayRoute({
    required this.onManageUsers,
    this.onUploadLogo,
    this.onGoHome,
  });

  @override
  Color get barrierColor => Colors.black
      .withValues(alpha: 0.55); // Dim the dashboard more with dark color

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => 'Settings';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _SettingsOverlayPage(
      onManageUsers: onManageUsers,
      onUploadLogo: onUploadLogo,
      onGoHome: onGoHome,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
        child: child,
      ),
    );
  }
}

class _SettingsOverlayPage extends StatelessWidget {
  final VoidCallback onManageUsers;
  final Future<void> Function()? onUploadLogo;
  final VoidCallback? onGoHome;

  const _SettingsOverlayPage({
    required this.onManageUsers,
    this.onUploadLogo,
    this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final panelWidth =
        isMobile ? (viewportWidth - 32).clamp(280.0, 380.0).toDouble() : 380.0;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: isMobile ? Alignment.topCenter : Alignment.topRight,
            child: Padding(
              padding: isMobile
                  ? const EdgeInsets.only(
                      top: 76,
                      left: 16,
                      right: 16,
                      bottom: 24,
                    )
                  : const EdgeInsets.only(top: 76, right: 24, bottom: 24),
              child: SizedBox(
                width: panelWidth,
                child: Material(
                  elevation: 16,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 380,
                      maxHeight: 650,
                    ),
                    child: _SettingsPanel(
                      onClose: () => Navigator.of(context).pop(),
                      onManageUsers: onManageUsers,
                      onUploadLogo: onUploadLogo,
                      onGoHome: onGoHome,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsPanel extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onManageUsers;
  final Future<void> Function()? onUploadLogo;
  final VoidCallback? onGoHome;

  const _SettingsPanel({
    required this.onClose,
    required this.onManageUsers,
    this.onUploadLogo,
    this.onGoHome,
  });

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  String? _username;
  int? _portalUserId;
  bool _loadingUser = true;
  bool _updatingAppLock = false;
  bool _loggedLogoPermission = false;

  bool get _canManageUsers {
    final site = CpanelApiService.instance.currentSite;
    if (site == null) return false;

    final ownerId = int.tryParse(site['owner_user_id']?.toString() ?? '');
    if (_portalUserId != null && ownerId != null && ownerId == _portalUserId) {
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

  bool get _canUseControlPresets {
    final site = CpanelApiService.instance.currentSite;
    if (site == null) return false;

    final ownerId = int.tryParse(site['owner_user_id']?.toString() ?? '');
    if (_portalUserId != null && ownerId != null && ownerId == _portalUserId) {
      return true;
    }

    final role = site['role']?.toString().trim().toLowerCase();
    if (role == 'admin') return true;

    return CpanelApiService.instance.isTruthyFlag(
          site['can_change_settings'],
        ) ||
        CpanelApiService.instance.isTruthyFlag(site['can_view_control']);
  }

  bool get _canChangeSettings {
    return CpanelApiService.instance.canCurrentSiteChangeSettings(
      portalUserId: _portalUserId,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    AppThemeController.instance.addListener(_syncThemeMode);
    AppLockController.instance.addListener(_syncAppLock);
  }

  @override
  void dispose() {
    AppThemeController.instance.removeListener(_syncThemeMode);
    AppLockController.instance.removeListener(_syncAppLock);
    super.dispose();
  }

  bool _isAppearanceExpanded = false;

  void _syncThemeMode() {
    if (!mounted) return;
    setState(() {});
  }

  void _syncAppLock() {
    if (!mounted) return;
    setState(() {});
  }

  Widget _buildAppearanceDropdown() {
    if (!_isAppearanceExpanded) return const SizedBox.shrink();

    final current = AppThemeController.instance.themeMode;
    final isLight = Theme.of(context).brightness == Brightness.light;

    int getIndex() {
      if (current == ThemeMode.light) return 0;
      if (current == ThemeMode.system) return 1;
      return 2;
    }

    final int selectedIndex = getIndex();

    return Padding(
      padding: const EdgeInsets.only(
        top: 12.0,
        bottom: 8.0,
        left: 16,
        right: 16,
      ),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFFE5E5EA) : const Color(0xFF1E242B),
          borderRadius: BorderRadius.circular(25),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double itemWidth = constraints.maxWidth / 3;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  left: selectedIndex * itemWidth,
                  top: 0,
                  bottom: 0,
                  width: itemWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(21),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPillOption(
                      ThemeMode.light,
                      Icons.light_mode_rounded,
                      selectedIndex == 0,
                    ),
                    _buildPillOption(
                      ThemeMode.system,
                      Icons.brightness_auto_rounded,
                      selectedIndex == 1,
                    ),
                    _buildPillOption(
                      ThemeMode.dark,
                      Icons.dark_mode_rounded,
                      selectedIndex == 2,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPillOption(ThemeMode mode, IconData icon, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => AppThemeController.instance.setThemeMode(mode),
        child: Center(
          child: Icon(
            icon,
            size: 24,
            color: isSelected
                ? Colors.white
                : (Theme.of(context).brightness == Brightness.light
                    ? Colors.black54
                    : Colors.white54),
          ),
        ),
      ),
    );
  }

  Future<void> _loadUserInfo() async {
    final user = await CpanelApiService.instance.getUsername();
    final uid = await CpanelApiService.instance.getUserId();

    if (!mounted) return;
    setState(() {
      _username = user;
      _portalUserId = uid;
      _loadingUser = false;
      _loggedLogoPermission = false;
    });
  }

  Future<void> _handleLogout() async {
    final confirm = await showGlassConfirmDialog(
      context,
      title: 'SIGN OUT',
      message: 'Are you sure you want to sign out of Smart Rack?',
      confirmText: 'Sign Out',
      confirmColor: AppTheme.statusError,
    );

    if (confirm == true) {
      await SessionFlowService.instance.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
    }
  }

  Future<void> _handleChangePassword() async {
    final username = _username;
    if (username == null || username.isEmpty) {
      AppToast.showError(context, 'User profile is not loaded yet.');
      return;
    }

    final authorized = await SecureActionGuard.ensureAuthorized(
      context,
      reason: 'Please authenticate to reset password.',
    );
    if (!authorized) return;

    if (!context.mounted) return;

    if (!mounted) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ResetPasswordGlassDialog(username: username),
      ),
    );

    if (result == true && context.mounted) {
      await SessionFlowService.instance.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
    }
  }

  Future<void> _handleSetPin() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const SetPinDialog(),
    );
    if (result != null && result.length >= 4 && mounted) {
      String? failureMessage;
      bool success = false;
      if (AdapterApiService.instance.isConfigured) {
        final adapterRes = await AdapterApiService.instance.setPinDetailed(
          result,
        );
        success = adapterRes != null && adapterRes['status'] == 'success';
        failureMessage = adapterRes?['message']?.toString();
      }

      if (!success) {
        success = await CpanelApiService.instance.setPin(result);
      }

      if (mounted) {
        if (success) {
          SecureActionSession.instance.clear();
          AppToast.showSuccess(context, 'Door Access PIN updated securely');
        } else {
          AppToast.showError(context, failureMessage ?? 'Failed to set PIN.');
        }
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final username = _username;
    if (username == null || username.isEmpty) {
      AppToast.showError(context, 'User profile is not loaded yet.');
      return;
    }

    final authorized = await SecureActionGuard.ensureAuthorized(
      context,
      reason: 'Please authenticate to delete your account.',
    );
    if (!authorized) return;
    if (!mounted) return;

    final confirm = await showGlassConfirmDialog(
      context,
      title: 'DELETE ACCOUNT',
      message:
          'This permanently removes your Smart Rack account access, signs you out, and cannot be undone.',
      confirmText: 'Delete Account',
      confirmColor: AppTheme.statusError,
    );

    if (confirm != true) return;

    final res = await CpanelApiService.instance.deleteMyAccount();
    final ok = res?['status']?.toString() == 'success';
    if (!mounted) return;

    if (!ok) {
      final msg = res?['message']?.toString() ?? 'Failed to delete account.';
      AppToast.showError(context, msg);
      return;
    }

    await SessionFlowService.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
  }

  Future<void> _openControlPresets() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ControlPresetsScreen()));
  }

  Future<void> _handleAppLockChanged(bool enabled) async {
    if (!AppLockController.instance.isSupported || _updatingAppLock) return;

    setState(() => _updatingAppLock = true);
    try {
      await AppLockController.instance.setEnabled(enabled);
      if (!mounted) return;
      AppToast.showSuccess(
        context,
        enabled
            ? 'App Lock enabled. Re-entry protection starts after 30 seconds away.'
            : 'App Lock disabled.',
      );
    } finally {
      if (mounted) {
        setState(() => _updatingAppLock = false);
      }
    }
  }

  Future<void> _openPushDiagnostics() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _PushDiagnosticsSheet(),
    );
  }

  Widget _buildGroup(String title, List<Widget> children, bool isLight) {
    if (children.isEmpty) return const SizedBox.shrink();

    final isRackConsole = CpanelApiService.instance.isCurrentSiteRackConsole();
    final List<Widget> groupedChildren = [];
    for (int i = 0; i < children.length; i++) {
      groupedChildren.add(children[i]);
      if (i < children.length - 1) {
        groupedChildren.add(
          Padding(
            padding: const EdgeInsets.only(left: 72, right: 16),
            child: Divider(
              height: 1,
              thickness: 1,
              color: isRackConsole
                  ? ConsoleTheme.divider(context)
                  : (isLight
                      ? Colors.black.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.05)),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8, top: 16),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isRackConsole
                  ? ConsoleTheme.textSecondary(context)
                  : (isLight ? Colors.black54 : Colors.white54),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isRackConsole
                ? ConsoleTheme.cardBg(context)
                : (isLight ? Colors.white : Theme.of(context).cardTheme.color),
            borderRadius: BorderRadius.circular(24),
            boxShadow: isLight
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: groupedChildren),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final site = CpanelApiService.instance.currentSite;
    final canUploadLogo = widget.onUploadLogo != null && _canChangeSettings;
    final companyLogoUrl = CpanelApiService.instance.currentCompanyLogoUrl();
    if (!_loadingUser && !_loggedLogoPermission) {
      _loggedLogoPermission = true;
      AppLog.d(
        'Logo upload permission snapshot',
        tag: 'SettingsOverlay',
        fields: {
          'hasUploadHandler': widget.onUploadLogo != null,
          'canUploadLogo': canUploadLogo,
          'portalUserId': _portalUserId,
          'siteId': site?['site_id'],
          'ownerUserId': site?['owner_user_id'],
          'role': site?['role'],
          'siteRole': site?['site_role'],
          'memberRole': site?['member_role'],
          'canChangeSettings': site?['can_change_settings'],
          'currentUserRole': CpanelApiService.instance.currentUser?['role'],
        },
      );
    }
    final isRackConsole = CpanelApiService.instance.isCurrentSiteRackConsole();
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isWebPreview = !AppLockController.instance.isSupported;
    final headerTextColor = isRackConsole
        ? ConsoleTheme.textPrimary(context)
        : (isLight ? AppTheme.lightTextPrimary : Colors.white);
    final trailingTextColor = isRackConsole
        ? ConsoleTheme.textSecondary(context)
        : (isLight
            ? AppTheme.lightTextSecondary
            : Colors.white.withValues(alpha: 0.75));
    return Container(
      // Match the dashboard background per theme.
      color: isRackConsole
          ? ConsoleTheme.panelBg(context)
          : (isLight
              ? Theme.of(context).scaffoldBackgroundColor
              : const Color(0xFF060B11)),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top right close button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: Icon(Icons.close_rounded, color: headerTextColor),
                  onPressed: widget.onClose,
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Centered Profile Info (Now scrolls with content)
                      Align(
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                              clipBehavior: Clip.antiAlias,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: isLight
                                      ? const Color(0xFFF1F5F9)
                                      : Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isLight
                                        ? const Color(0xFFD5DAE2)
                                        : Colors.white.withValues(alpha: 0.16),
                                    width: 1.5,
                                  ),
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(22),
                                      child: companyLogoUrl != null &&
                                              companyLogoUrl.isNotEmpty
                                          ? SafeNetworkImage(
                                              companyLogoUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_) =>
                                                  const Center(
                                                child: Icon(
                                                  Icons.person_outline_rounded,
                                                  size: 58,
                                                  color: Colors.white24,
                                                ),
                                              ),
                                            )
                                          : const Center(
                                              child: Icon(
                                                Icons.person_outline_rounded,
                                                size: 58,
                                                color: Colors.white24,
                                              ),
                                            ),
                                    ),
                                    if (canUploadLogo)
                                      Positioned.fill(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: widget.onUploadLogo,
                                            borderRadius: BorderRadius.circular(
                                              22,
                                            ),
                                            child: Container(
                                              alignment: Alignment.bottomRight,
                                              padding: const EdgeInsets.all(8),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.edit,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _loadingUser ? '...' : (_username ?? 'ADMIN'),
                              textAlign: TextAlign.center,
                              style: bitcount(
                                context,
                                fontSize: 22,
                                color: headerTextColor,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      if (!isRackConsole)
                        _buildGroup(
                            'Account & Security',
                            [
                              if (_canManageUsers)
                                _SettingsTile(
                                  title: 'Manage Users',
                                  icon: Icons.manage_accounts_outlined,
                                  iconColor: const Color(0xFF007AFF),
                                  onTap: widget.onManageUsers,
                                ),
                              _SettingsTile(
                                title: 'Reset Password',
                                icon: Icons.lock_reset_rounded,
                                iconColor: const Color(0xFFFF9500),
                                onTap: _handleChangePassword,
                              ),
                              _SettingsTile(
                                title: 'Set Door PIN',
                                icon: Icons.dialpad_rounded,
                                iconColor: const Color(0xFF34C759),
                                onTap: _handleSetPin,
                              ),
                              _SettingsTile(
                                title: 'Delete Account',
                                subtitle:
                                    'Permanently remove this Smart Rack account',
                                icon: Icons.delete_forever_rounded,
                                iconColor: const Color(0xFFFF3B30),
                                onTap: _handleDeleteAccount,
                              ),
                            ],
                            isLight),
                      _buildGroup(
                          'Rack Management',
                          [
                            if (_canUseControlPresets)
                              _SettingsTile(
                                title: 'AC Control Presets',
                                icon: Icons.tune_rounded,
                                iconColor: const Color(0xFF00B8D9),
                                onTap: _openControlPresets,
                              ),
                            _SettingsTile(
                              title: 'Export PDF Report',
                              icon: Icons.picture_as_pdf_rounded,
                              iconColor: const Color(0xFFFF3B30),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ExportPdfScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                          isLight),
                      _buildGroup(
                          'Preferences',
                          [
                            if (isRackConsole)
                              AnimatedBuilder(
                                animation: RackConsolePreferences.instance,
                                builder: (context, _) {
                                  final prefs = RackConsolePreferences.instance;
                                  return _SettingsTile(
                                    title: 'Use 24-Hour Time',
                                    subtitle: prefs.use24HourTime
                                        ? 'Header clock and trend charts use 24-hour labels.'
                                        : 'Header clock and trend charts use 12-hour labels.',
                                    icon: Icons.schedule_rounded,
                                    iconColor: const Color(0xFF007AFF),
                                    trailing: Switch.adaptive(
                                      value: prefs.use24HourTime,
                                      onChanged: (value) {
                                        prefs.setUse24HourTime(value);
                                      },
                                      activeThumbColor:
                                          ConsoleTheme.primaryBlue(
                                        context,
                                      ),
                                    ),
                                    onTap: () {
                                      prefs.setUse24HourTime(
                                          !prefs.use24HourTime);
                                    },
                                  );
                                },
                              ),
                            if (!isRackConsole)
                              _SettingsTile(
                                title: 'App Lock',
                                subtitle: isWebPreview
                                    ? 'Design preview in web. Enable on iPhone or Android after install.'
                                    : null,
                                icon: Icons.lock_rounded,
                                iconColor: const Color(0xFF00BD10),
                                trailing: isWebPreview
                                    ? const Switch.adaptive(
                                        value: false,
                                        onChanged: null,
                                        activeThumbColor: Color(0xFF00BD10),
                                      )
                                    : Switch.adaptive(
                                        value: AppLockController
                                            .instance.isEnabled,
                                        onChanged: _updatingAppLock
                                            ? null
                                            : _handleAppLockChanged,
                                        activeThumbColor:
                                            const Color(0xFF00BD10),
                                      ),
                                onTap: isWebPreview || _updatingAppLock
                                    ? null
                                    : () => _handleAppLockChanged(
                                          !AppLockController.instance.isEnabled,
                                        ),
                              ),
                            if (!isRackConsole)
                              _SettingsTile(
                                title: 'Push Diagnostics',
                                subtitle:
                                    'Check APNs, FCM, and backend token registration',
                                icon: Icons.notifications_active_outlined,
                                iconColor: const Color(0xFF007AFF),
                                onTap: _openPushDiagnostics,
                              ),
                            Column(
                              children: [
                                _SettingsTile(
                                  title: 'Appearance',
                                  icon: Icons.palette_outlined,
                                  iconColor: const Color(0xFF5856D6),
                                  trailing: AnimatedRotation(
                                    turns: _isAppearanceExpanded ? 0.25 : 0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      Icons.chevron_right_rounded,
                                      color: trailingTextColor,
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _isAppearanceExpanded =
                                          !_isAppearanceExpanded;
                                    });
                                  },
                                ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 200),
                                  alignment: Alignment.topCenter,
                                  child: _buildAppearanceDropdown(),
                                ),
                              ],
                            ),
                          ],
                          isLight),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFB30000),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _handleLogout,
                          child: Text(
                            'SIGN OUT',
                            style: bitcount(
                              context,
                              fontSize: 18,
                              color: Colors.white,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
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

class _SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    final textColor = isLight ? Colors.black : Colors.white;
    final chevronColor = isLight
        ? Colors.black.withValues(alpha: 0.3)
        : Colors.white.withValues(alpha: 0.5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
                child: Center(child: Icon(icon, color: Colors.white, size: 18)),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: bitcount(
                        context,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: isLight
                              ? Colors.black.withValues(alpha: 0.58)
                              : Colors.white.withValues(alpha: 0.58),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing ??
                  Icon(Icons.chevron_right_rounded, color: chevronColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _PushDiagnosticsSheet extends StatefulWidget {
  const _PushDiagnosticsSheet();

  @override
  State<_PushDiagnosticsSheet> createState() => _PushDiagnosticsSheetState();
}

class _PushDiagnosticsSheetState extends State<_PushDiagnosticsSheet> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await PushNotificationService.instance.refreshDiagnostics();
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  String _fmt(DateTime? value) {
    if (value == null) return 'Not seen';
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  String _boolText(bool? value) {
    if (value == null) return 'Unknown';
    return value ? 'Yes' : 'No';
  }

  Color _statusColor(BuildContext context, bool ok) {
    return ok ? const Color(0xFF18A957) : Theme.of(context).colorScheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final background = isLight ? const Color(0xFFF5F7FB) : const Color(0xFF0B1118);
    final card = isLight ? Colors.white : const Color(0xFF121A23);
    final text = isLight ? Colors.black : Colors.white;
    final subtext = isLight
        ? Colors.black.withValues(alpha: 0.62)
        : Colors.white.withValues(alpha: 0.62);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Push Diagnostics',
                          style: bitcount(
                            context,
                            fontSize: 18,
                            color: text,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _refreshing ? null : _refresh,
                        icon: _refreshing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(Icons.refresh_rounded, color: text),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close_rounded, color: text),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ValueListenableBuilder<PushDiagnosticsSnapshot>(
                    valueListenable: PushNotificationService.instance.diagnostics,
                    builder: (context, snapshot, _) {
                      final registered = snapshot.tokenRegisteredToBackend;
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          _DiagnosticsCard(
                            title: 'Current Status',
                            background: card,
                            children: [
                              _DiagnosticsRow(
                                label: 'Permission',
                                value: snapshot.permissionStatus,
                                valueColor: text,
                              ),
                              _DiagnosticsRow(
                                label: 'APNs token',
                                value: _boolText(snapshot.hasApnsToken),
                                valueColor: snapshot.hasApnsToken == null
                                    ? subtext
                                    : _statusColor(
                                        context,
                                        snapshot.hasApnsToken == true,
                                      ),
                              ),
                              _DiagnosticsRow(
                                label: 'FCM token',
                                value: _boolText(snapshot.hasFcmToken),
                                valueColor: snapshot.hasFcmToken == null
                                    ? subtext
                                    : _statusColor(
                                        context,
                                        snapshot.hasFcmToken == true,
                                      ),
                              ),
                              _DiagnosticsRow(
                                label: 'Backend registered',
                                value: registered ? 'Yes' : 'No',
                                valueColor: _statusColor(context, registered),
                              ),
                              _DiagnosticsRow(
                                label: 'Site ID',
                                value: snapshot.siteId?.toString() ?? 'Unknown',
                                valueColor: text,
                              ),
                              _DiagnosticsRow(
                                label: 'Token preview',
                                value: snapshot.tokenPreview ?? 'Unavailable',
                                valueColor: text,
                              ),
                              _DiagnosticsRow(
                                label: 'Last sync status',
                                value: snapshot.lastSyncStatus,
                                valueColor: text,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _DiagnosticsCard(
                            title: 'Recent Activity',
                            background: card,
                            children: [
                              _DiagnosticsRow(
                                label: 'Last refresh',
                                value: _fmt(snapshot.lastRefreshAt),
                                valueColor: text,
                              ),
                              _DiagnosticsRow(
                                label: 'Last backend sync',
                                value: _fmt(snapshot.lastSyncAt),
                                valueColor: text,
                              ),
                              _DiagnosticsRow(
                                label: 'Foreground push seen',
                                value: _fmt(snapshot.lastForegroundMessageAt),
                                valueColor: text,
                              ),
                              _DiagnosticsRow(
                                label: 'Background push seen',
                                value: _fmt(snapshot.lastBackgroundMessageAt),
                                valueColor: text,
                              ),
                              _DiagnosticsRow(
                                label: 'Opened from push',
                                value: _fmt(snapshot.lastOpenedFromPushAt),
                                valueColor: text,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              'Use this screen on iPhone before testing. If APNs token is No or Unknown, the device is not ready for iOS remote push. If FCM token is Yes but Backend registered is No, the adapter is not storing the iPhone token. If all show Yes but background push never appears, the issue is in APNs delivery.',
                              style: TextStyle(
                                color: subtext,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiagnosticsCard extends StatelessWidget {
  final String title;
  final Color background;
  final List<Widget> children;

  const _DiagnosticsCard({
    required this.title,
    required this.background,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final titleColor = isLight ? Colors.black87 : Colors.white;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: bitcount(
              context,
              fontSize: 14,
              color: titleColor,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DiagnosticsRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _DiagnosticsRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final labelColor = isLight
        ? Colors.black.withValues(alpha: 0.56)
        : Colors.white.withValues(alpha: 0.56);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
