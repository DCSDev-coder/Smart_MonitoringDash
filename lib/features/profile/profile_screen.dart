import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_service.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/auth/remember_me_store.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/glass_confirm_dialog.dart';
import '../../shared/widgets/reset_password_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _username;
  int? _portalUserId;

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

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = await CpanelApiService.instance.getUsername();
    final uid = await CpanelApiService.instance.getUserId();
    if (mounted) {
      setState(() {
        _username = user;
        _portalUserId = uid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final uiScale = screenW >= 900 ? (screenW / 1150).clamp(1.0, 1.25) : 1.0;
 
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(uiScale)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenW >= 800 ? screenW * 0.5 : double.infinity,
            ),
            child: ListView(
              padding: EdgeInsets.fromLTRB(24, AppConstants.headerClearance(context), 24, 24),
            children: [
              // Profile Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.accentGreen, width: 2),
                      ),
                      child: const Icon(Icons.person_rounded, size: 50, color: AppTheme.accentGreen),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _username?.toUpperCase() ?? 'ADMIN',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Text(
                      'System Specialist',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
    
              // Account Section
              _sectionLabel('ACCOUNT'),
              const SizedBox(height: 12),
              if (_canManageUsers) ...[
                _buildProfileTile(
                  icon: Icons.group_add_outlined,
                  title: 'Manage Users',
                  subtitle: 'Create site sub-users and set permissions',
                  onTap: () => Navigator.pushNamed(context, '/manage_users'),
                ),
                const SizedBox(height: 12),
              ],
              _buildProfileTile(
                icon: Icons.password_rounded,
                title: 'Reset Password',
                subtitle: 'Change your account password',
                onTap: () => _handleChangePassword(context),
              ),
              const SizedBox(height: 12),
              _buildProfileTile(
                icon: Icons.logout_rounded,
                title: 'Sign Out',
                subtitle: 'Securely end your session',
                textColor: AppTheme.statusError,
                iconColor: AppTheme.statusError,
                onTap: () => _handleLogout(context),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSecondary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildProfileTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    Color? textColor,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? AppTheme.accentBlue).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor ?? AppTheme.accentBlue, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: textColor ?? AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
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
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
      }
    }
  }

  Future<void> _handleChangePassword(BuildContext context) async {
    final username = _username;
    if (username == null || username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User profile is not loaded yet.')),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ResetPasswordAlertDialog(username: username),
    );

    if (result == true && context.mounted) {
      await rememberMeStore.clear();
      await PushNotificationService.instance.deactivateCurrentTokenIfPossible();
      await CpanelApiService.instance.logout();
      await ApiService.instance.logout();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
      }
    }
  }
}
