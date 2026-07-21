import 'package:flutter/material.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/background_layer.dart';
import '../../shared/utils/app_toast.dart';

class AddUserScreen extends StatefulWidget {
  final int siteId;
  final String adminUsername;
  final String adminPassword;

  const AddUserScreen({
    super.key,
    required this.siteId,
    required this.adminUsername,
    required this.adminPassword,
  });

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _newUserCtrl = TextEditingController();

  bool _canViewDashboard = true;
  bool _canViewReport = false;
  bool _canViewRack = false;
  bool _canViewControl = false;
  bool _canControlDoors = false;
  bool _canChangeSettings = false;
  bool _canManageUsers = false;
  bool _isRackConsole = false;
  bool _submitting = false;

  @override
  void dispose() {
    _newUserCtrl.dispose();
    super.dispose();
  }

  String _friendlyCreateUserError(Map<String, dynamic>? res) {
    final raw = res?['message']?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return 'Failed to create user. Please check your inputs and try again.';
    }

    final lower = raw.toLowerCase();
    if (lower.contains('invalid json body')) {
      return 'The server rejected the user record. Please check the username and permissions, then try again.';
    }
    if (lower.contains('username already exists')) {
      return 'That username already exists. Use a different username.';
    }
    if (lower.contains('site membership') && lower.contains('failed')) {
      return 'The account was created but could not be linked to this site. Please try again.';
    }
    if (lower.contains('admin credentials')) {
      return 'Admin verification failed. Please sign in again and retry.';
    }

    return raw;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final nu = _newUserCtrl.text.trim();
    if (nu.isEmpty) {
      AppToast.showError(context, 'Username is required.');
      return;
    }

    setState(() => _submitting = true);
    // Keep backend API compatibility: treat "Manage Users" as "admin".
    final roleComputed = _canManageUsers ? 'admin' : 'user';
    final res = await CpanelApiService.instance.createSiteUser(
      siteId: widget.siteId,
      adminUsername: widget.adminUsername,
      adminPassword: widget.adminPassword,
      newUsername: nu,
      role: roleComputed,
      permissions: {
        "can_view_dashboard": _canViewDashboard ? 1 : 0,
        "can_view_report": _canViewReport ? 1 : 0,
        "can_view_rack": _canViewRack ? 1 : 0,
        "can_view_control": _canViewControl ? 1 : 0,
        "can_control_doors": _canControlDoors ? 1 : 0,
        "can_change_settings": _canChangeSettings ? 1 : 0,
        "can_manage_users": _canManageUsers ? 1 : 0,
        "is_kiosk": _isRackConsole ? 1 : 0,
      },
    );

    if (!mounted) return;
    final status = res?['status']?.toString();
    final ok = status == 'success';
    if (ok) {
      Navigator.pop(context, true);
      return;
    }

    setState(() => _submitting = false);
    AppToast.showError(context, _friendlyCreateUserError(res));
  }

  void _setManageUsers(bool value) {
    setState(() {
      _canManageUsers = value;
      if (value) {
        _isRackConsole = false;
      }
    });
  }

  void _setRackConsoleMode(bool value) {
    setState(() {
      _isRackConsole = value;
      if (value) {
        _canManageUsers = false;
        _canViewDashboard = true;
        _canControlDoors = true;
        _canViewReport = true;
        _canViewRack = true;
        _canViewControl = true;
        _canChangeSettings = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final uiScale =
        screenWidth >= 900 ? (screenWidth / 1150).clamp(1.0, 1.25) : 1.0;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final topPad = media.padding.top;

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(uiScale)),
      child: Scaffold(
        backgroundColor: isLight
            ? const Color.fromARGB(255, 247, 251, 255)
            : const Color(0xFF060B11),
        body: Stack(
          children: [
            if (!isLight)
              const Positioned.fill(
                child: BackgroundLayer(
                  channel: BackgroundChannel.app,
                  overlayAlpha: 0.74,
                  staticForApp: true,
                ),
              ),
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: topPad + 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: isLight
                                ? AppTheme.lightTextPrimary
                                : Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Add User',
                      style: TextStyle(
                        color:
                            isLight ? AppTheme.lightTextPrimary : Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        _buildInputField(
                          context,
                          label: 'USERNAME',
                          controller: _newUserCtrl,
                          hint: 'Enter new username',
                          enabled: !_submitting,
                        ),
                        const SizedBox(height: 36),
                        Text(
                          'ACCOUNT MODE',
                          style: TextStyle(
                            color: isLight
                                ? AppTheme.lightTextPrimary
                                    .withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPermToggle('Rack Console Mode', _isRackConsole,
                            _setRackConsoleMode),

                        if (!_isRackConsole) ...[
                          const SizedBox(height: 36),
                          Text(
                            'PERMISSIONS',
                            style: TextStyle(
                              color: isLight
                                  ? AppTheme.lightTextPrimary
                                      .withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildPermToggle('Dashboard', _canViewDashboard,
                              (v) => setState(() => _canViewDashboard = v)),
                          _buildPermToggle('Reports + PDF', _canViewReport,
                              (v) => setState(() => _canViewReport = v)),
                          _buildPermToggle('View Power', _canViewRack,
                              (v) => setState(() => _canViewRack = v)),
                          _buildPermToggle('Control Panel', _canViewControl,
                              (v) => setState(() => _canViewControl = v)),
                          _buildPermToggle('Door Access', _canControlDoors,
                              (v) => setState(() => _canControlDoors = v)),
                          _buildPermToggle('Settings', _canChangeSettings,
                              (v) => setState(() => _canChangeSettings = v)),
                          _buildPermToggle(
                              'Manage Users', _canManageUsers, _setManageUsers),
                        ],
                        const SizedBox(height: 120), // bottom padding
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    EdgeInsets.fromLTRB(24, 16, 24, media.padding.bottom + 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      isLight
                          ? const Color(0xFFF7FBFF).withValues(alpha: 0.0)
                          : const Color(0xFF060B11).withValues(alpha: 0.0),
                      isLight
                          ? const Color(0xFFF7FBFF)
                          : const Color(0xFF060B11),
                    ],
                    stops: const [0.0, 0.4],
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Create User',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool enabled,
    bool obscureText = false,
    Widget? trailing,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isLight
                ? AppTheme.lightTextPrimary.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                obscureText: obscureText,
                style: TextStyle(
                  color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                cursorColor: isLight ? AppTheme.lightTextPrimary : Colors.white,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: isLight
                        ? AppTheme.lightTextPrimary.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.3),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: isLight
                          ? AppTheme.lightStroke
                          : Colors.white.withValues(alpha: 0.18),
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: isLight
                          ? AppTheme.lightStroke
                          : Colors.white.withValues(alpha: 0.18),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2.0,
                    ),
                  ),
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ],
    );
  }

  Widget _buildPermToggle(
      String label, bool value, ValueChanged<bool> onChanged) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isLight ? AppTheme.lightTextPrimary : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          Switch(
            value: value,
            onChanged: _submitting ? null : onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveThumbColor: isLight
                ? const Color(0xFFEDEDED)
                : Colors.white.withValues(alpha: 0.85),
            inactiveTrackColor: isLight
                ? const Color(0xFF3F3F3F)
                : Colors.white.withValues(alpha: 0.18),
          ),
        ],
      ),
    );
  }
}
