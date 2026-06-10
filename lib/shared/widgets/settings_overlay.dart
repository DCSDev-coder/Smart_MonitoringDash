import 'package:flutter/material.dart';

import '../../core/network/api_service.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/auth/remember_me_store.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/controllers/app_theme_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../features/dashboard/widgets/dashboard_typography.dart';
import '../../features/settings/control_presets_screen.dart';
import '../../features/settings/export_pdf_screen.dart';
import 'glass_confirm_dialog.dart';
import 'reset_password_dialog.dart';
import 'safe_network_image.dart';
import 'secure_action_guard.dart';
import '../../core/network/adapter_api_service.dart';
import '../utils/app_toast.dart';

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
  }

  @override
  void dispose() {
    AppThemeController.instance.removeListener(_syncThemeMode);
    super.dispose();
  }

  bool _isAppearanceExpanded = false;

  void _syncThemeMode() {
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
                  ? AppTheme.accentGreen
                  : (isLight
                      ? const Color(0xFFF0F0F0)
                      : const Color(0xFF1E242B)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppTheme.accentGreen : Colors.transparent,
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
      await rememberMeStore.clear();
      await PushNotificationService.instance.deactivateCurrentTokenIfPossible();
      await CpanelApiService.instance.logout();
      await ApiService.instance.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
    }
  }

  Future<void> _handleSetPin() async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _SetPinDialog(),
    );
    if (pin != null && pin.length >= 4 && mounted) {
      bool success = false;
      if (AdapterApiService.instance.isConfigured) {
        success = await AdapterApiService.instance.setPin(pin);
      }
      
      if (!success) {
        success = await CpanelApiService.instance.setPin(pin);
      }
      
      if (mounted) {
        if (success) {
          AppToast.showSuccess(context, 'Door Access PIN updated securely');
        } else {
          AppToast.showError(context, 'Failed to set PIN');
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

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final headerTextColor = isLight ? AppTheme.lightTextPrimary : Colors.white;
    final trailingTextColor = isLight
        ? AppTheme.lightTextSecondary
        : Colors.white.withValues(alpha: 0.75);
    return Container(
      // Match the dashboard background per theme.
      color: isLight
          ? Theme.of(context).scaffoldBackgroundColor
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
                                        borderRadius: BorderRadius.circular(23),
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
                                        color:
                                            Colors.white.withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(23),
                                      ),
                                    ),
                                    Icon(Icons.camera_alt_rounded,
                                        color:
                                            Colors.white.withValues(alpha: 0.7),
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
                  // Top left back button
                  Positioned(
                    top: 0,
                    left: 0,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: headerTextColor),
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
                      Container(
                        decoration: BoxDecoration(
                          color: isLight
                              ? Colors.white
                              : Theme.of(context).cardTheme.color,
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
                        child: Column(
                          children: [
                            if (_canManageUsers) ...[
                              _SettingsTile(
                                title: 'Manage Users',
                                icon: Icons.manage_accounts_outlined,
                                iconColor: const Color(0xFF007AFF),
                                onTap: widget.onManageUsers,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 72, right: 16),
                                child: Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: isLight
                                      ? Colors.black.withValues(alpha: 0.05)
                                      : Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                            ],
                            _SettingsTile(
                              title: 'Reset Password',
                              icon: Icons.lock_reset_rounded,
                              iconColor: const Color(0xFFFF9500),
                              onTap: _handleChangePassword,
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 72, right: 16),
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: isLight
                                    ? Colors.black.withValues(alpha: 0.05)
                                    : Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            _SettingsTile(
                              title: 'Set Door Access PIN',
                              icon: Icons.dialpad_rounded,
                              iconColor: const Color(0xFF34C759),
                              onTap: _handleSetPin,
                            ),
                            if (_canUseControlPresets) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 72, right: 16),
                                child: Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: isLight
                                      ? Colors.black.withValues(alpha: 0.05)
                                      : Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              _SettingsTile(
                                title: 'AC Control Presets',
                                icon: Icons.tune_rounded,
                                iconColor: const Color(0xFF00B8D9),
                                onTap: _openControlPresets,
                              ),
                            ],
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 72, right: 16),
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: isLight
                                    ? Colors.black.withValues(alpha: 0.05)
                                    : Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            _SettingsTile(
                              title: 'Export PDF Report',
                              icon: Icons.picture_as_pdf_rounded,
                              iconColor: const Color(0xFFFF3B30),
                              onTap: () async {
                                Navigator.pop(context); // Close settings overlay
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ExportPdfScreen(),
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 72, right: 16),
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: isLight
                                    ? Colors.black.withValues(alpha: 0.05)
                                    : Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
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
  final Color iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.title,
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
                child: Text(
                  title,
                  style: bitcount(
                    context,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textColor,
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
    );
  }
}

class _SetPinDialog extends StatefulWidget {
  const _SetPinDialog();
  @override
  State<_SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<_SetPinDialog> {
  final _pinCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return AlertDialog(
      title: const Text('Set Door Access PIN'),
      content: TextField(
        controller: _pinCtrl,
        keyboardType: TextInputType.number,
        obscureText: true,
        autofocus: true,
        maxLength: 6,
        decoration: const InputDecoration(
          hintText: 'Enter 4-6 digit PIN',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(
                  color: isLight ? AppTheme.textSecondary : Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () {
            final pin = _pinCtrl.text.trim();
            if (pin.length < 4) {
              AppToast.showError(context, 'PIN must be at least 4 digits');
              return;
            }
            Navigator.pop(context, pin);
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
              foregroundColor: Colors.white),
          child: const Text('Save PIN'),
        ),
      ],
    );
  }
}
