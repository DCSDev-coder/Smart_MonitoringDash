import 'package:flutter/material.dart';

import '../../core/network/api_service.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/auth/remember_me_store.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/controllers/app_theme_controller.dart';
import '../../core/controllers/smart_polling_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../features/dashboard/widgets/dashboard_typography.dart';
import 'glass_confirm_dialog.dart';
import 'reset_password_dialog.dart';
import 'safe_network_image.dart';

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
          // Replace the settings popup route directly to avoid a pop->push
          // intermediate frame (which looks like a flash).
          nav.pushReplacementNamed('/manage_users');
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

    // Slide from the right (1.0 to 0.0)
    final slide = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(curved);

    return SlideTransition(
      position: slide,
      child: child,
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
    final size = MediaQuery.of(context).size;
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        width: size.width,
        height: double.infinity,
        child: _SettingsPanel(
          onClose: () => Navigator.of(context).pop(),
          onManageUsers: onManageUsers,
          onCctvConfig: onCctvConfig,
          onUploadLogo: onUploadLogo,
          onGoHome: onGoHome,
        ),
      ),
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
  String? _logoUrl;
  bool _loadingUser = true;
  SmartPollingMode _pollingMode = SmartPollingSettings.instance.mode;

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
    SmartPollingSettings.instance.addListener(_syncPollingMode);
    _syncPollingMode();
    AppThemeController.instance.addListener(_syncThemeMode);
  }

  @override
  void dispose() {
    SmartPollingSettings.instance.removeListener(_syncPollingMode);
    AppThemeController.instance.removeListener(_syncThemeMode);
    super.dispose();
  }

  void _syncPollingMode() {
    if (!mounted) return;
    setState(() {
      _pollingMode = SmartPollingSettings.instance.mode;
    });
  }

  void _syncThemeMode() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _showPollingModeDialog() async {
    SmartPollingMode temp = _pollingMode;
    final selected = await showDialog<SmartPollingMode>(
      context: context,
      builder: (context) {
        final isLight = Theme.of(context).brightness == Brightness.light;
        return AlertDialog(
          backgroundColor:
              isLight ? Colors.white : const Color(0xFF0B0F14),
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Smart Performance',
            style: bitcount(
              context,
              fontSize: 16,
              color: isLight ? AppTheme.lightTextPrimary : Colors.white,
              letterSpacing: 1.0,
            ),
          ),
          content: StatefulBuilder(builder: (context, setStateDialog) {
            final items = <SmartPollingMode, String>{
              SmartPollingMode.auto: 'Auto (Recommended)',
              SmartPollingMode.balanced: 'Balanced',
              SmartPollingMode.lowData: 'Low Data',
              SmartPollingMode.performance: 'Performance',
            };

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isLight
                    ? const Color(0xFFF3F4F7)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isLight
                      ? const Color(0xFFD5DAE2)
                      : Colors.white.withValues(alpha: 0.10),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<SmartPollingMode>(
                  value: temp,
                  isExpanded: true,
                  dropdownColor:
                      isLight ? Colors.white : const Color(0xFF0B0F14),
                  iconEnabledColor: isLight
                      ? AppTheme.lightTextSecondary
                      : Colors.white.withValues(alpha: 0.8),
                  style: TextStyle(
                    color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                  items: items.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setStateDialog(() => temp = v ?? temp),
                ),
              ),
            );
          }),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isLight
                      ? AppTheme.lightTextSecondary
                      : Colors.white70,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context, temp);
              },
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        );
      },
    );

    if (selected == null) return;
    await SmartPollingSettings.instance.setMode(selected);
  }

  String _pollingModeLabel(SmartPollingMode m) {
    switch (m) {
      case SmartPollingMode.auto:
        return 'AUTO';
      case SmartPollingMode.balanced:
        return 'BALANCED';
      case SmartPollingMode.lowData:
        return 'LOW DATA';
      case SmartPollingMode.performance:
        return 'PERFORMANCE';
    }
  }

  Future<void> _showThemeDialog() async {
    final current = AppThemeController.instance.themeMode;
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (context) {
        final isLight = Theme.of(context).brightness == Brightness.light;
        return AlertDialog(
          backgroundColor:
              isLight ? Colors.white : const Color(0xFF0B0F14),
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Appearance',
            style: bitcount(
              context,
              fontSize: 16,
              color: isLight ? AppTheme.lightTextPrimary : Colors.white,
              letterSpacing: 1.0,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _themeOption(context, ThemeMode.light, 'Light Mode',
                  Icons.light_mode_rounded, current),
              _themeOption(context, ThemeMode.dark, 'Dark Mode',
                  Icons.dark_mode_rounded, current),
              _themeOption(context, ThemeMode.system, 'System Default',
                  Icons.settings_suggest_rounded, current),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      await AppThemeController.instance.setThemeMode(selected);
    }
  }

  Widget _themeOption(BuildContext context, ThemeMode mode, String label,
      IconData icon, ThemeMode current) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isSelected = current == mode;
    return ListTile(
      leading:
          Icon(
            icon,
            color: isSelected
                ? AppTheme.accentGreen
                : (isLight
                    ? AppTheme.lightTextSecondary
                    : Colors.white70),
          ),
      title: Text(label,
          style: TextStyle(
              color: isSelected
                  ? (isLight ? AppTheme.lightTextPrimary : Colors.white)
                  : (isLight
                      ? AppTheme.lightTextSecondary
                      : Colors.white70),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded,
              color: AppTheme.accentGreen, size: 20)
          : null,
      onTap: () => Navigator.pop(context, mode),
    );
  }

  Future<void> _loadUserInfo() async {
    final user = await CpanelApiService.instance.getUsername();
    final uid = await CpanelApiService.instance.getUserId();
    final site = CpanelApiService.instance.currentSite;
    final logoPath = site?['company_logo_path']?.toString() ?? '';
    final logoUrl = logoPath.trim().isNotEmpty
        ? '${CpanelApiService.baseAssetUrl}$logoPath'
        : null;

    if (!mounted) return;
    setState(() {
      _username = user;
      _portalUserId = uid;
      _logoUrl = logoUrl;
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
      await rememberMeStore.clear();
      await PushNotificationService.instance.deactivateCurrentTokenIfPossible();
      await CpanelApiService.instance.logout();
      await ApiService.instance.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
    }
  }

  Future<void> _handleChangePassword() async {
    final username = _username;
    if (username == null || username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User profile is not loaded yet.')),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ResetPasswordGlassDialog(username: username),
    );

    if (result == true && context.mounted) {
      await rememberMeStore.clear();
      await PushNotificationService.instance.deactivateCurrentTokenIfPossible();
      await CpanelApiService.instance.logout();
      await ApiService.instance.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final headerTextColor = isLight ? AppTheme.lightTextPrimary : Colors.white;
    final headerIconColor =
        isLight ? Colors.black.withValues(alpha: 0.75) : Colors.white;
    final trailingTextColor = isLight
        ? AppTheme.lightTextSecondary
        : Colors.white.withValues(alpha: 0.75);
    return Container(
      // Match the dashboard background per theme.
      color: isLight
          ? const Color.fromARGB(255, 236, 244, 255)
          : const Color(0xFF060B11),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  // Redesigned Header Section: Centered Profile
                  Stack(
                    children: [
                      // Center the profile info
                      Align(
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () async {
                                  if (widget.onUploadLogo != null) {
                                    await widget.onUploadLogo!();
                                    _loadUserInfo();
                                  }
                                },
                                child: SizedBox(
                                  width: 140,
                                  height: 140,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (_logoUrl != null)
                                        Positioned.fill(
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(23),
                                            child: SafeNetworkImage(
                                              _logoUrl!,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        )
                                      else
                                        const Icon(Icons.business_rounded,
                                            color: Colors.white24, size: 48),
                                      if (_logoUrl == null) ...[
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.4),
                                            borderRadius:
                                                BorderRadius.circular(23),
                                          ),
                                        ),
                                        Icon(Icons.camera_alt_rounded,
                                            color: Colors.white
                                                .withValues(alpha: 0.7),
                                            size: 32),
                                      ],
                                    ],
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
                      // Top right close button
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: headerIconColor, size: 28),
                          onPressed: widget.onClose,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (_canManageUsers) ...[
                            _SettingsTile(
                              title: 'Manage Users',
                              icon: Icons.manage_accounts_outlined,
                              onTap: widget.onManageUsers,
                            ),
                            const SizedBox(height: 16),
                          ],
                          _SettingsTile(
                            title: 'Reset Password',
                            icon: Icons.lock_reset_rounded,
                            onTap: _handleChangePassword,
                          ),
                          // CCTV Configuration Hidden as requested
                          const SizedBox(height: 16),
                          _SettingsTile(
                            title: 'Appearance',
                            icon: Icons.palette_outlined,
                            trailing: Text(
                              AppThemeController.instance.themeMode.name
                                  .toUpperCase(),
                              style: TextStyle(
                                color: trailingTextColor,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                                fontSize: 12,
                              ),
                            ),
                            onTap: _showThemeDialog,
                          ),
                          const SizedBox(height: 16),
                          _SettingsTile(
                            title: 'Smart Performance',
                            icon: Icons.speed_rounded,
                            trailing: Text(
                              _pollingModeLabel(_pollingMode),
                              style: TextStyle(
                                color: trailingTextColor,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                                fontSize: 12,
                              ),
                            ),
                            onTap: _showPollingModeDialog,
                          ),
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
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.title,
    required this.icon,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    final tileBg = isLight
        ? theme.colorScheme.surface
        : Colors.white.withValues(alpha: 0.05);
    final tileBorder =
        isLight ? AppTheme.lightStroke : Colors.white.withValues(alpha: 0.08);
    final iconBg = isLight
        ? const Color(0xFFEAF2FF)
        : Colors.white.withValues(alpha: 0.10);
    final iconColor = isLight
        ? AppTheme.lightTextPrimary
        : Colors.white.withValues(alpha: 0.88);
    final textColor = isLight ? AppTheme.lightTextPrimary : Colors.white;
    final chevronColor = isLight
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.75);

    return Container(
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tileBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: bitcount(
                      context,
                      fontSize: 14,
                      color: textColor,
                      letterSpacing: 1.0,
                    ),
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
      ),
    );
  }
}
