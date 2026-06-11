import 'package:flutter/material.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/background_layer.dart';
import '../../shared/utils/app_toast.dart';

class EditUserScreen extends StatefulWidget {
  final String username;
  final int siteId;
  final int memberUserId;
  final String adminUsername;

  final bool canViewDashboard;
  final bool canViewReport;
  final bool canViewRack;
  final bool canViewControl;
  final bool canControlDoors;
  final bool canChangeSettings;
  final bool canManageUsers;
  final bool isRackConsole;

  const EditUserScreen({
    super.key,
    required this.username,
    required this.siteId,
    required this.memberUserId,
    required this.adminUsername,
    required this.canViewDashboard,
    required this.canViewReport,
    required this.canViewRack,
    required this.canViewControl,
    required this.canControlDoors,
    required this.canChangeSettings,
    required this.canManageUsers,
    required this.isRackConsole,
  });

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  late bool _canViewDashboard;
  late bool _canViewReport;
  late bool _canViewRack;
  late bool _canViewControl;
  final bool _canViewCctv = false; // Add if needed later
  late bool _canControlDoors;
  late bool _canChangeSettings;
  late bool _canManageUsers;
  late bool _isRackConsole;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _canViewDashboard = widget.canViewDashboard;
    _canViewReport = widget.canViewReport;
    _canViewRack = widget.canViewRack;
    _canViewControl = widget.canViewControl;
    _canControlDoors = widget.canControlDoors;
    _canChangeSettings = widget.canChangeSettings;
    _canManageUsers = widget.canManageUsers;
    _isRackConsole = widget.isRackConsole;
  }

  Future<void> _submit() async {
    if (_submitting) return;

    setState(() => _submitting = true);

    // Keep backend API compatibility: treat "Manage Users" as "admin".
    final roleComputed = _canManageUsers ? 'admin' : 'user';
    final res = await CpanelApiService.instance.updateSiteMember(
      siteId: widget.siteId,
      adminUsername: widget.adminUsername,
      memberUserId: widget.memberUserId,
      role: roleComputed,
      permissions: {
        "can_view_dashboard": _canViewDashboard ? 1 : 0,
        "can_view_report": _canViewReport ? 1 : 0,
        "can_view_rack": _canViewRack ? 1 : 0,
        "can_view_control": _canViewControl ? 1 : 0,
        "can_view_cctv": _canViewCctv ? 1 : 0,
        "can_control_doors": _canControlDoors ? 1 : 0,
        "can_change_settings": _canChangeSettings ? 1 : 0,
        "can_manage_users": _canManageUsers ? 1 : 0,
        "is_kiosk": _isRackConsole ? 1 : 0,
      },
    );

    if (!mounted) return;

    final ok = res?['status']?.toString() == 'success';
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _submitting = false);
      final msg = res?['message']?.toString() ?? 'Failed to update member.';
      AppToast.showError(context, msg);
    }
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
                      'Edit User',
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
                        Text(
                          'USERNAME',
                          style: TextStyle(
                            color: isLight
                                ? AppTheme.lightTextPrimary.withOpacity(0.5)
                                : Colors.white.withOpacity(0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.username,
                          style: TextStyle(
                            color: isLight
                                ? AppTheme.lightTextPrimary
                                : Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          'ACCOUNT MODE',
                          style: TextStyle(
                            color: isLight
                                ? AppTheme.lightTextPrimary.withOpacity(0.5)
                                : Colors.white.withOpacity(0.5),
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
                                  ? AppTheme.lightTextPrimary.withOpacity(0.5)
                                  : Colors.white.withOpacity(0.5),
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
                          ? const Color(0xFFF7FBFF).withOpacity(0.0)
                          : const Color(0xFF060B11).withOpacity(0.0),
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
                            'Save Changes',
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
                : Colors.white.withOpacity(0.85),
            inactiveTrackColor: isLight
                ? const Color(0xFF3F3F3F)
                : Colors.white.withOpacity(0.18),
          ),
        ],
      ),
    );
  }
}
