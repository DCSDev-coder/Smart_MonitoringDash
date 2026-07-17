import 'package:flutter/material.dart';

import '../../core/auth/session_flow_service.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/controllers/app_theme_controller.dart';
import '../../core/security/app_lock_controller.dart';
import '../../core/security/secure_action_session.dart';
import '../../core/theme/app_theme.dart';
import '../../features/dashboard/widgets/dashboard_typography.dart';
import '../../features/settings/control_presets_screen.dart';
import '../../features/settings/export_pdf_screen.dart';
import '../../features/smart_rack_console/services/rack_console_preferences.dart';
import 'glass_confirm_dialog.dart';
import 'reset_password_dialog.dart';
import 'secure_action_guard.dart';
import 'set_pin_dialog.dart';
import '../../core/network/adapter_api_service.dart';
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
    final rect =
        Rect.fromLTWH(topLeft.dx, topLeft.dy, ro.size.width, ro.size.height);
    // A tiny inflation reads better than animating from a 24x24 icon box.
    return rect.inflate(6);
  }

  static Future<void> show(
    BuildContext context, {
    Rect? originRect,
    VoidCallback? onCctvConfig,
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
        onCctvConfig: onCctvConfig,
        onUploadLogo: onUploadLogo,
        onGoHome: onGoHome,
      ),
    );
  }
}

class _SettingsOverlayRoute extends PopupRoute<void> {
  final VoidCallback onManageUsers;
  final VoidCallback? onCctvConfig;
  final Future<void> Function()? onUploadLogo;
  final VoidCallback? onGoHome;

  _SettingsOverlayRoute({
    required this.onManageUsers,
    this.onCctvConfig,
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
      onCctvConfig: onCctvConfig,
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
  final VoidCallback? onCctvConfig;
  final Future<void> Function()? onUploadLogo;
  final VoidCallback? onGoHome;

  const _SettingsOverlayPage({
    required this.onManageUsers,
    this.onCctvConfig,
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
                      top: 76, left: 16, right: 16, bottom: 24)
                  : const EdgeInsets.only(top: 76, right: 24, bottom: 24),
              child: SizedBox(
                width: panelWidth,
                child: Material(
                  elevation: 16,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: 380, maxHeight: 650),
                    child: _SettingsPanel(
                      onClose: () => Navigator.of(context).pop(),
                      onManageUsers: onManageUsers,
                      onCctvConfig: onCctvConfig,
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
  final VoidCallback? onCctvConfig;
  final Future<void> Function()? onUploadLogo;
  final VoidCallback? onGoHome;

  const _SettingsPanel({
    required this.onClose,
    required this.onManageUsers,
    this.onCctvConfig,
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

    return CpanelApiService.instance
            .isTruthyFlag(site['can_change_settings']) ||
        CpanelApiService.instance.isTruthyFlag(site['can_view_control']);
  }

  /*
  bool get _canViewCctv {
    final site = CpanelApiService.instance.currentSite;
    if (site == null) return true; // Default to true if site not loaded
    final v = site['can_view_cctv'];
    if (v == null) return true;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }
  */

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

    Widget buildBtn(ThemeMode mode, String label, IconData icon) {
      final isSelected = current == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () async {
            await AppThemeController.instance.setThemeMode(mode);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : (isLight
                      ? const Color(0xFFF0F0F0)
                      : const Color(0xFF1E242B)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected
                      ? Colors.white
                      : (isLight ? Colors.black54 : Colors.white54),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isLight ? Colors.black87 : Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          buildBtn(ThemeMode.light, 'Light', Icons.light_mode_rounded),
          const SizedBox(width: 8),
          buildBtn(ThemeMode.system, 'System', Icons.settings_suggest_rounded),
          const SizedBox(width: 8),
          buildBtn(ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
        ],
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
        final adapterRes =
            await AdapterApiService.instance.setPinDetailed(result);
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
          AppToast.showError(
            context,
            failureMessage ?? 'Failed to set PIN.',
          );
        }
      }
    }
  }

  Future<void> _openControlPresets() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ControlPresetsScreen(),
      ),
    );
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
                    )
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
                              child: SizedBox(
                                width: 140,
                                height: 140,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(23),
                                  child: Image.asset(
                                    'assets/DCS_Logo/untitled_design.png',
                                    fit: BoxFit.contain,
                                  ),
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
                                          ConsoleTheme.primaryBlue(context),
                                    ),
                                    onTap: () {
                                      prefs.setUse24HourTime(
                                        !prefs.use24HourTime,
                                      );
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
                child: Center(
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
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
                  Icon(
                    Icons.chevron_right_rounded,
                    color: chevronColor,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
