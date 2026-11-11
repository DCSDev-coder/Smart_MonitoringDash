import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';
import '../../../core/config/site_runtime_config.dart';
import '../../../core/network/api_service.dart';
import '../../../core/network/adapter_api_service.dart';
import '../../../core/network/cpanel_api_service.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_log.dart';
import '../../../shared/widgets/animated_gradient_fill.dart';
import '../../../shared/utils/app_toast.dart';
import '../../smart_rack_console/theme/console_theme.dart';

class DoorControlSection extends StatelessWidget {
  final List<Map<String, dynamic>> doors;
  final Future<bool> Function(int id, String name) onUnlock;
  final bool canUnlock;
  final bool loading;

  const DoorControlSection({
    super.key,
    required this.doors,
    required this.onUnlock,
    required this.canUnlock,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    if (loading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Loading doors...',
                style: TextStyle(
                  color: isLight
                      ? AppTheme.lightTextPrimary
                      : Colors.white.withValues(alpha: 0.72),
                  fontSize: isLight ? 13 : 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (doors.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No doors configured',
              style: TextStyle(
                color: isLight
                    ? AppTheme.lightTextPrimary
                    : Colors.white.withValues(alpha: 0.65),
                fontSize: isLight ? 13 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: LayoutBuilder(
        builder: (context, outer) {
          final heightBounded = outer.maxHeight.isFinite;

          Widget doorBody({required bool scrollable}) {
            final tiles = doors
                .map((d) => _DoorTile(
                      door: d,
                      canUnlock: canUnlock,
                      onUnlock: onUnlock,
                    ))
                .toList();

            if (tiles.length > 2) {
              return SizedBox(
                height: 230,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: tiles.length,
                  clipBehavior: Clip.none,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => SizedBox(
                    width:
                        (outer.maxWidth - 12) / 2, // 2 visible items at a time
                    child: tiles[i],
                  ),
                ),
              );
            }

            return GridView.builder(
              shrinkWrap: !scrollable,
              physics: scrollable ? null : const NeverScrollableScrollPhysics(),
              itemCount: tiles.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent:
                    220, // Fixed card height instead of square aspect ratio
              ),
              itemBuilder: (_, i) => tiles[i],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (heightBounded)
                Expanded(child: doorBody(scrollable: true))
              else
                doorBody(scrollable: false),
            ],
          );
        },
      ),
    );
  }
}

class _DoorRow extends StatefulWidget {
  final Map<String, dynamic> door;
  final bool canUnlock;
  final Future<bool> Function(int id, String name) onUnlock;

  const _DoorRow({
    required this.door,
    required this.canUnlock,
    required this.onUnlock,
  });

  @override
  State<_DoorRow> createState() => _DoorRowState();
}

class _DoorRowState extends State<_DoorRow> {
  bool _localUnlocked = false;
  bool _isUnlocking = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _doUnlock(int id, String rawName) async {
    if (_isUnlocking) return;
    setState(() => _isUnlocking = true);
    try {
      final success = await widget.onUnlock(id, rawName);
      if (success == true && mounted) {
        setState(() => _localUnlocked = true);
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _localUnlocked = false);
        });
      }
    } finally {
      if (mounted) setState(() => _isUnlocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final rawName = widget.door['name']?.toString() ?? 'Unknown';
    final id = int.tryParse(widget.door['id']?.toString() ?? '') ?? 0;
    final isUnlocked = _localUnlocked || (widget.door['isOpen'] == true);
    final enabled = widget.canUnlock && !isUnlocked && !_isUnlocking && id != 0;

    // Light-mode: keep the section card blue but make each row a light surface.
    // User request: keep all door rows the same background color.
    final rowTint = isLight ? const Color(0xFFF5F7FF) : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: rowTint ??
              (isLight
                  ? const Color(0xFFF5F7FF)
                  : const Color(0xFF0B0F14).withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(18),
          border: isLight
              ? Border.all(color: AppTheme.lightStroke)
              : Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  _DoorLockIcon(isUnlocked: isUnlocked),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rawName,
                      style: TextStyle(
                        color:
                            isLight ? AppTheme.lightTextPrimary : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: isLight ? 14 : 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 128,
              height: isLight ? 40 : 38,
              child: _AnimatedUnlockButton(
                enabled: enabled,
                label: _isUnlocking
                    ? 'LOCKED...'
                    : isUnlocked
                        ? 'UNLOCKED'
                        : (widget.canUnlock ? 'UNLOCK' : 'NO ACCESS'),
                onPressed: enabled ? () => _doUnlock(id, rawName) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoorTile extends StatefulWidget {
  final Map<String, dynamic> door;
  final bool canUnlock;
  final Future<bool> Function(int id, String name) onUnlock;

  const _DoorTile({
    required this.door,
    required this.canUnlock,
    required this.onUnlock,
  });

  @override
  State<_DoorTile> createState() => _DoorTileState();
}

class _DoorTileState extends State<_DoorTile> {
  bool _localUnlocked = false;
  bool _isUnlocking = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _doUnlock(int id, String rawName) async {
    if (_isUnlocking) return;
    setState(() => _isUnlocking = true);
    try {
      final success = await widget.onUnlock(id, rawName);
      if (success == true && mounted) {
        setState(() => _localUnlocked = true);
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _localUnlocked = false);
        });
      }
    } finally {
      if (mounted) setState(() => _isUnlocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final rawName = widget.door['name']?.toString() ?? 'Unknown';
    final id = int.tryParse(widget.door['id']?.toString() ?? '') ?? 0;
    final isUnlocked = _localUnlocked || (widget.door['isOpen'] == true);
    final enabled = widget.canUnlock && !isUnlocked && !_isUnlocking && id != 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _CabinetDoorVisual(
              isOpen: isUnlocked,
              isDoubleDoor: rawName.toLowerCase().contains('front'),
            ),
            const SizedBox(height: 8),
            Text(
              rawName,
              style: TextStyle(
                color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: _AnimatedUnlockButton(
                enabled: enabled,
                label: isUnlocked
                    ? 'UNLOCKED'
                    : _isUnlocking
                        ? 'LOCKING'
                        : (widget.canUnlock ? 'UNLOCK' : 'NO ACCESS'),
                onPressed: enabled
                    ? () => _doUnlock(id, widget.door['name']?.toString() ?? '')
                    : null,
                pill: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedUnlockButton extends StatefulWidget {
  final bool enabled;
  final String label;
  final VoidCallback? onPressed;
  final bool pill;

  const _AnimatedUnlockButton({
    required this.enabled,
    required this.label,
    required this.onPressed,
    this.pill = false,
  });

  @override
  State<_AnimatedUnlockButton> createState() => _AnimatedUnlockButtonState();
}

class _AnimatedUnlockButtonState extends State<_AnimatedUnlockButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final disabled = !widget.enabled || widget.onPressed == null;
    final radius = widget.pill ? 14.0 : 18.0;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final bg = disabled
            ? (isLight ? Colors.black : Colors.white).withValues(alpha: 0.10)
            : null;

        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(radius),
            child: Ink(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(radius),
                boxShadow: disabled
                    ? null
                    : [
                        BoxShadow(
                          // Keep the button glow aligned with the light-mode
                          // Door Access section tint (cyan).
                          color:
                              const Color(0xFF00A3FF).withValues(alpha: 0.16),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.10),
                          blurRadius: 28,
                          spreadRadius: 6,
                        ),
                      ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!disabled)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: AnimatedGradientFill(
                        t: _c,
                        borderRadius: BorderRadius.circular(radius),
                        colors: [
                          const Color(0xFF00A3FF),
                          const Color(0xFF0FA4A8),
                          Theme.of(context).colorScheme.primary,
                          const Color(0xFF00A3FF),
                        ],
                      ),
                    ),
                  Center(
                    child: Text(
                      widget.label.toUpperCase(),
                      style: TextStyle(
                        color: disabled
                            ? Colors.white.withValues(alpha: 0.75)
                            : Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        fontSize: widget.pill
                            ? (isLight ? 15 : 14)
                            : (isLight ? 13 : 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class UnlockDoorSheet extends StatefulWidget {
  final int doorId;
  final String doorName;
  final bool isRackConsoleStyle;
  final int? siteId;

  const UnlockDoorSheet({
    super.key,
    required this.doorId,
    required this.doorName,
    this.isRackConsoleStyle = false,
    this.siteId,
  });

  @override
  State<UnlockDoorSheet> createState() => _UnlockDoorSheetState();
}

class _UnlockDoorSheetState extends State<UnlockDoorSheet> {
  final _localAuth = LocalAuthentication();
  final _userCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _pwdFocus = FocusNode();

  bool _isAuthenticating = false;
  bool _obscurePwd = true;

  bool _biometricsChecked = false;
  bool _deviceAuthSupported = false;
  bool _hasBiometrics = false;
  bool _showCredentialFallback = false;
  bool _autoPrompted = false;
  List<BiometricType> _availableBiometrics = const [];
  bool get _isRackConsoleMode =>
      CpanelApiService.instance.isCurrentSiteRackConsole();
  bool get _hasFaceId => _availableBiometrics.contains(BiometricType.face);
  bool get _hasFingerprint =>
      _availableBiometrics.contains(BiometricType.fingerprint);
  bool get _shouldShowBiometricPrompt =>
      !_showCredentialFallback && _hasBiometrics;
  String get _biometricLabel => _hasFaceId
      ? 'Use Face ID'
      : (_hasFingerprint ? 'Use Fingerprint' : 'Use Biometrics');
  String get _biometricHint =>
      _hasFaceId ? 'Face ID' : (_hasFingerprint ? 'Fingerprint' : 'biometrics');
  int? get _effectiveSiteId =>
      widget.siteId ??
      SiteRuntimeConfig.siteId(CpanelApiService.instance.currentSite);

  @override
  void initState() {
    super.initState();
    _initUsername();
    AppLog.d(
      'Unlock sheet opened',
      tag: 'DoorUnlock',
      fields: {
        'doorId': widget.doorId,
        'doorName': widget.doorName,
        'siteId': _effectiveSiteId,
        'isRackConsoleStyle': widget.isRackConsoleStyle,
        'isRackConsoleMode': _isRackConsoleMode,
        'adapterConfigured': AdapterApiService.instance.isConfigured,
        'kIsWeb': kIsWeb,
      },
    );
    if (!kIsWeb && !widget.isRackConsoleStyle) {
      _checkAndAutoPrompt();
    }
  }

  Future<void> _initUsername() async {
    final portalUsername =
        await CpanelApiService.instance.getUsername() ?? 'admin';
    if (mounted) {
      setState(() {
        _userCtrl.text = portalUsername;
      });
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _pwdCtrl.dispose();
    _pwdFocus.dispose();
    super.dispose();
  }

  Future<void> _checkAndAutoPrompt() async {
    if (_biometricsChecked) return;
    _biometricsChecked = true;
    try {
      final supported = await _localAuth.isDeviceSupported();
      final available = await _localAuth.getAvailableBiometrics();
      if (!mounted) return;
      setState(() {
        _deviceAuthSupported = supported;
        _availableBiometrics = available;
        _hasBiometrics = supported && available.isNotEmpty;
        _showCredentialFallback = !_hasBiometrics;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deviceAuthSupported = false;
        _hasBiometrics = false;
        _availableBiometrics = const [];
        _showCredentialFallback = true;
      });
    }

    if (!mounted) return;
    // Only auto-prompt when biometrics are actually enrolled; otherwise some
    // Android devices will send users into "enroll biometrics" flows.
    if (_hasBiometrics && !_autoPrompted) {
      _autoPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _runDeviceAuthUnlock();
      });
    }
  }

  String _friendlyDoorUnlockError(dynamic rawMessage) {
    final message = rawMessage?.toString().trim();
    if (message == null || message.isEmpty) {
      return 'Unlock failed. Please try again.';
    }

    final lower = message.toLowerCase();
    if (lower.contains('wrong account')) {
      return 'This PIN does not belong to the signed-in account.';
    }
    if (lower.contains('invalid pin') ||
        lower.contains('invalid username or pin')) {
      return 'Incorrect PIN.';
    }
    if (lower.contains('not allowed to unlock doors')) {
      return 'This account is not allowed to unlock doors.';
    }
    if (lower.contains('invalid bearer token') ||
        lower.contains('expired token') ||
        lower.contains('session expired')) {
      return 'Your session has expired. Please sign in again or use password unlock.';
    }
    if (lower.contains('user not found for this site')) {
      return 'This account is not linked to the selected site.';
    }

    return message;
  }

  Future<void> _runDeviceAuthUnlock() async {
    if (!mounted) return;
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Confirm to unlock ${widget.doorName}',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;
      if (!ok) {
        setState(() {
          _isAuthenticating = false;
          _showCredentialFallback = true;
        });
        return;
      }

      final siteId = _effectiveSiteId;
      final usedAdapter =
          AdapterApiService.instance.isConfigured && siteId != null;

      AppLog.d(
        'Door unlock via device auth',
        tag: 'DoorUnlock',
        fields: {
          'doorId': widget.doorId,
          'doorName': widget.doorName,
          'siteId': siteId,
          'adapterConfigured': AdapterApiService.instance.isConfigured,
          'usedAdapter': usedAdapter,
          'mode': _isRackConsoleMode ? 'rack_console' : 'standard',
        },
      );

      Map<String, dynamic>? res;
      if (usedAdapter) {
        await PushNotificationService.instance.ensureTokenRegistered();
        res = await AdapterApiService.instance.openCloseDoor(
          siteId: siteId,
          accessId: widget.doorId,
          status: 1,
          accessType: '1',
        );
      }
      if (!usedAdapter || ApiService.instance.canUseDirectFallback) {
        res ??= await ApiService.instance.openCloseDoor(widget.doorId, 1);
      }
      if (!mounted) return;

      if (res != null && res['success'] == true) {
        if (!usedAdapter && siteId != null) {
          CpanelApiService.instance.logRemoteAccess(
            siteId: siteId,
            doorId: widget.doorId,
          );
        }
        Navigator.pop(context, true);
        AppToast.showSuccess(context, '${widget.doorName} unlocked!');
      } else {
        setState(() => _isAuthenticating = false);
        AppToast.showError(
          context,
          _friendlyDoorUnlockError(
            res?['message'] ??
                'Unlock failed. If your session expired, use password.',
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _showCredentialFallback = true;
      });
      AppToast.showError(
        context,
        'Biometric authentication was not completed. Please use PIN or password.',
      );
    }
  }

  bool _usePin = true;

  Future<void> _runPasswordUnlock() async {
    if (_isAuthenticating) return;

    AppLog.d(
      'Unlock submit tapped',
      tag: 'DoorUnlock',
      fields: {
        'doorId': widget.doorId,
        'doorName': widget.doorName,
        'siteId': _effectiveSiteId,
        'usePin': _usePin,
        'isRackConsoleMode': _isRackConsoleMode,
        'isRackConsoleStyle': widget.isRackConsoleStyle,
        'adapterConfigured': AdapterApiService.instance.isConfigured,
        'pinLength': _pwdCtrl.text.trim().length,
        'hasPasswordValue': _pwdCtrl.text.isNotEmpty,
      },
    );

    setState(() => _isAuthenticating = true);
    try {
      final siteId = _effectiveSiteId;
      final adapterAvailable =
          AdapterApiService.instance.isConfigured && siteId != null;

      AppLog.d(
        'Unlock path evaluation',
        tag: 'DoorUnlock',
        fields: {
          'doorId': widget.doorId,
          'doorName': widget.doorName,
          'siteId': siteId,
          'adapterAvailable': adapterAvailable,
          'usePin': _usePin,
          'isRackConsoleMode': _isRackConsoleMode,
        },
      );

      int? remoteLogOverrideUserId;
      Map<String, dynamic>? res;
      bool usedAdapter = false;

      if (_isRackConsoleMode) {
        if (siteId == null) {
          setState(() => _isAuthenticating = false);
          AppToast.show(context, 'Site connection required.');
          return;
        }

        final pin = _pwdCtrl.text.trim();
        if (pin.length < 4 || pin.length > 6) {
          AppLog.w(
            'Unlock validation failed',
            tag: 'DoorUnlock',
            fields: {
              'doorId': widget.doorId,
              'doorName': widget.doorName,
              'siteId': siteId,
              'reason': 'rack_console_pin_length',
              'pinLength': pin.length,
            },
          );
          setState(() => _isAuthenticating = false);
          AppToast.show(context, 'Enter a 4-6 digit PIN.');
          return;
        }

        if (adapterAvailable) {
          usedAdapter = true;
          AppLog.d(
            'Door unlock with user PIN via adapter',
            tag: 'DoorUnlock',
            fields: {
              'doorId': widget.doorId,
              'doorName': widget.doorName,
              'siteId': siteId,
              'mode': 'rack_console',
            },
          );
          await PushNotificationService.instance.ensureTokenRegistered();
          res = await AdapterApiService.instance.unlockWithUserPin(
            siteId: siteId,
            accessId: widget.doorId,
            pin: pin,
          );
        } else {
          AppLog.w(
            'Door unlock with user PIN fell back to legacy path',
            tag: 'DoorUnlock',
            fields: {
              'doorId': widget.doorId,
              'doorName': widget.doorName,
              'siteId': siteId,
              'adapterConfigured': AdapterApiService.instance.isConfigured,
              'mode': 'rack_console',
            },
          );
          final verifyRes = await CpanelApiService.instance.verifySiteUserPin(
            siteId: siteId,
            pin: pin,
          );
          if (!mounted) return;

          if (verifyRes != null && verifyRes['status'] == 'success') {
            remoteLogOverrideUserId = verifyRes['user_id'];
            res = await ApiService.instance.openCloseDoor(widget.doorId, 1);
          } else {
            setState(() => _isAuthenticating = false);
            AppToast.showError(
              context,
              _friendlyDoorUnlockError(
                verifyRes?['message']?.toString() ??
                    'Invalid PIN or Access Denied',
              ),
            );
            return;
          }
        }
      } else if (_usePin) {
        final pin = _pwdCtrl.text.trim();
        if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
          AppLog.w(
            'Unlock validation failed',
            tag: 'DoorUnlock',
            fields: {
              'doorId': widget.doorId,
              'doorName': widget.doorName,
              'siteId': siteId,
              'reason': 'standard_pin_format',
              'pinLength': pin.length,
            },
          );
          AppToast.showError(context, 'Enter a 4-6 digit PIN.');
          setState(() => _isAuthenticating = false);
          return;
        }

        if (adapterAvailable) {
          usedAdapter = true;
          AppLog.d(
            'Door unlock with PIN via adapter',
            tag: 'DoorUnlock',
            fields: {
              'doorId': widget.doorId,
              'doorName': widget.doorName,
              'siteId': siteId,
              'mode': 'standard',
            },
          );
          await PushNotificationService.instance.ensureTokenRegistered();
          res = await AdapterApiService.instance.unlockWithPin(
            siteId: siteId,
            accessId: widget.doorId,
            pin: pin,
          );
        } else {
          AppLog.w(
            'Door unlock with PIN fell back to legacy path',
            tag: 'DoorUnlock',
            fields: {
              'doorId': widget.doorId,
              'doorName': widget.doorName,
              'siteId': siteId,
              'adapterConfigured': AdapterApiService.instance.isConfigured,
              'mode': 'standard',
            },
          );
          // Strictly verify PIN with our secure CPanel backend
          final verifyRes = await CpanelApiService.instance.verifyPin(pin);
          if (!mounted) return;

          if (verifyRes != null && verifyRes['status'] == 'success') {
            res = await ApiService.instance.openCloseDoor(widget.doorId, 1);
          } else {
            setState(() => _isAuthenticating = false);
            AppToast.showError(context, 'Incorrect PIN');
            return;
          }
        }
      } else {
        // Try portal password check first
        final portalUsername = _userCtrl.text.trim();
        final pwd = _pwdCtrl.text;
        AppLog.d(
          'Password unlock login attempt',
          tag: 'DoorUnlock',
          fields: {
            'doorId': widget.doorId,
            'doorName': widget.doorName,
            'siteId': siteId,
            'username': portalUsername,
            'adapterConfigured': AdapterApiService.instance.isConfigured,
            'adapterAvailable': adapterAvailable,
          },
        );
        final loginRes =
            await CpanelApiService.instance.login(portalUsername, pwd);
        if (!mounted) return;

        bool loginSuccess = loginRes != null && loginRes['status'] == 'success';
        AppLog.d(
          'Password unlock login result',
          tag: 'DoorUnlock',
          fields: {
            'doorId': widget.doorId,
            'doorName': widget.doorName,
            'siteId': siteId,
            'username': portalUsername,
            'loginSuccess': loginSuccess,
            'loginStatus': loginRes?['status']?.toString(),
            'loginMessage': loginRes?['message']?.toString(),
            'adapterAvailable': adapterAvailable,
          },
        );
        if (!loginSuccess) {
          AppLog.w(
            'Unlock validation failed',
            tag: 'DoorUnlock',
            fields: {
              'doorId': widget.doorId,
              'doorName': widget.doorName,
              'siteId': siteId,
              'reason': 'password_login_failed',
              'username': portalUsername,
            },
          );
          setState(() => _isAuthenticating = false);
          AppToast.showError(context, 'Incorrect password');
          return;
        }

        if (adapterAvailable) {
          usedAdapter = true;
          AppLog.d(
            'Door unlock with password via adapter',
            tag: 'DoorUnlock',
            fields: {
              'doorId': widget.doorId,
              'doorName': widget.doorName,
              'siteId': siteId,
              'mode': 'standard',
            },
          );
          await PushNotificationService.instance.ensureTokenRegistered();
          res = await AdapterApiService.instance.openCloseDoor(
            siteId: siteId,
            accessId: widget.doorId,
            status: 1,
            accessType: '1',
          );
        } else {
          AppLog.w(
            'Door unlock with password fell back to legacy path',
            tag: 'DoorUnlock',
            fields: {
              'doorId': widget.doorId,
              'doorName': widget.doorName,
              'siteId': siteId,
              'adapterConfigured': AdapterApiService.instance.isConfigured,
              'mode': 'standard',
            },
          );
        }
        if (!adapterAvailable || ApiService.instance.canUseDirectFallback) {
          res ??= await ApiService.instance.openCloseDoor(widget.doorId, 1);
        }
      }

      if (!mounted) return;

      if (res != null && res['success'] == true) {
        AppLog.d(
          'Door unlock succeeded',
          tag: 'DoorUnlock',
          fields: {
            'doorId': widget.doorId,
            'doorName': widget.doorName,
            'siteId': siteId,
            'usedAdapter': usedAdapter,
            'mode': _isRackConsoleMode ? 'rack_console' : 'standard',
          },
        );
        if (!usedAdapter && siteId != null) {
          CpanelApiService.instance.logRemoteAccess(
            siteId: siteId,
            doorId: widget.doorId,
            overrideUserId: remoteLogOverrideUserId,
          );
        }
        Navigator.pop(context, true);
        AppToast.showSuccess(context, '${widget.doorName} unlocked!');
      } else {
        AppLog.w(
          'Door unlock failed',
          tag: 'DoorUnlock',
          fields: {
            'doorId': widget.doorId,
            'doorName': widget.doorName,
            'siteId': siteId,
            'usedAdapter': usedAdapter,
            'mode': _isRackConsoleMode ? 'rack_console' : 'standard',
            'message': res?['message']?.toString(),
          },
        );
        Navigator.pop(context);
        AppToast.showError(
          context,
          _friendlyDoorUnlockError(
            res?['message'] ?? 'Failed to unlock door via API',
          ),
        );
      }
    } catch (error) {
      AppLog.w(
        'Unlock threw exception',
        tag: 'DoorUnlock',
        fields: {
          'doorId': widget.doorId,
          'doorName': widget.doorName,
          'siteId': _effectiveSiteId,
          'mode': _isRackConsoleMode ? 'rack_console' : 'standard',
          'usePin': _usePin,
          'error': error.toString(),
        },
      );
      if (!mounted) return;
      setState(() => _isAuthenticating = false);
      AppToast.showError(context, 'Unlock failed. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isRack = widget.isRackConsoleStyle;
    final showBiometricPath = _shouldShowBiometricPrompt;

    Widget content = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isRack
                    ? Colors.white.withValues(alpha: 0.22)
                    : (isLight
                        ? Colors.black.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.22)),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'UNLOCK DOOR',
                style: TextStyle(
                  color: isRack
                      ? ConsoleTheme.textPrimary(context)
                      : (isLight ? AppTheme.lightTextPrimary : Colors.white),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    color: isRack
                        ? ConsoleTheme.textSecondary(context)
                        : (isLight
                            ? AppTheme.lightTextSecondary
                            : Colors.white.withValues(alpha: 0.8))),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isRack
                ? 'Enter the approving user PIN to unlock ${widget.doorName} from the Rack Console.'
                : showBiometricPath
                    ? 'Confirm with $_biometricHint to unlock ${widget.doorName}.'
                    : (_usePin
                        ? 'Please enter your 4-6 digit Door Access PIN to unlock ${widget.doorName}'
                        : 'Please enter your account password to unlock ${widget.doorName}'),
            style: TextStyle(
              color: isRack
                  ? ConsoleTheme.textSecondary(context)
                  : (isLight
                      ? AppTheme.lightTextSecondary
                      : Colors.white.withValues(alpha: 0.70)),
              fontSize: 12,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            reverseDuration: const Duration(milliseconds: 160),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.topCenter,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: showBiometricPath && !kIsWeb && _deviceAuthSupported
                ? Column(
                    key: const ValueKey('biometric-path'),
                    children: [
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.fingerprint_rounded, size: 18),
                          label: Text(_biometricLabel),
                          onPressed:
                              _isAuthenticating ? null : _runDeviceAuthUnlock,
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                Colors.orangeAccent.withValues(alpha: 0.85),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          _isAuthenticating
                              ? 'Waiting for $_biometricHint...'
                              : 'Use biometric unlock to continue',
                          style: TextStyle(
                            color: isLight
                                ? AppTheme.lightTextSecondary
                                : Colors.white.withValues(alpha: 0.65),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('credential-path'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isRack ? 'PIN' : (_usePin ? 'PIN' : 'Password'),
                            style: TextStyle(
                              color: isRack
                                  ? ConsoleTheme.textPrimary(context)
                                  : (isLight
                                      ? AppTheme.lightTextPrimary
                                      : Colors.white),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!isRack)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _usePin = !_usePin;
                                  _pwdCtrl.clear();
                                });
                              },
                              child: Text(
                                _usePin ? 'Use Password' : 'Use PIN',
                                style: TextStyle(
                                  color: isLight
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _pwdCtrl,
                        focusNode: _pwdFocus,
                        obscureText: _obscurePwd,
                        obscuringCharacter: '*',
                        autofocus: false,
                        keyboardType:
                            _usePin ? TextInputType.number : TextInputType.text,
                        style: TextStyle(
                          color: isRack
                              ? ConsoleTheme.textPrimary(context)
                              : (isLight
                                  ? AppTheme.lightTextPrimary
                                  : Colors.white),
                          fontSize: _usePin ? 24 : 16,
                          letterSpacing: _usePin ? 8.0 : null,
                        ),
                        textAlign: _usePin ? TextAlign.center : TextAlign.start,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isRack
                              ? Colors.white.withValues(alpha: 0.05)
                              : (isLight
                                  ? const Color(0xFFF3F4F7)
                                  : Colors.white.withValues(alpha: 0.08)),
                          hintText: _usePin ? '****' : 'Password',
                          hintStyle: TextStyle(
                            color: isRack
                                ? ConsoleTheme.textSecondary(context)
                                    .withValues(alpha: 0.5)
                                : (isLight
                                    ? AppTheme.lightTextSecondary
                                    : Colors.white.withValues(alpha: 0.45)),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isRack
                                  ? ConsoleTheme.cardBorder(context)
                                  : (isLight
                                      ? const Color(0xFFD5DAE2)
                                      : Colors.white.withValues(alpha: 0.18)),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isRack
                                  ? ConsoleTheme.cardBorder(context)
                                  : (isLight
                                      ? const Color(0xFFD5DAE2)
                                      : Colors.white.withValues(alpha: 0.18)),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isRack
                                  ? ConsoleTheme.primaryBlue(context)
                                  : Theme.of(context).colorScheme.primary,
                              width: 1.4,
                            ),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePwd
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: isRack
                                  ? ConsoleTheme.textSecondary(context)
                                  : (isLight
                                      ? AppTheme.lightTextSecondary
                                      : Colors.white.withValues(alpha: 0.75)),
                            ),
                            onPressed: () =>
                                setState(() => _obscurePwd = !_obscurePwd),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_isAuthenticating)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: CircularProgressIndicator(
                              color: isRack
                                  ? ConsoleTheme.primaryBlue(context)
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.lock_open_rounded, size: 16),
                            label: const Text('Unlock Door'),
                            onPressed: _runPasswordUnlock,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isRack
                                  ? const Color(0xFF109B5B)
                                  : Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(isRack ? 24 : 16),
                              ),
                              padding: isRack
                                  ? const EdgeInsets.symmetric(vertical: 16)
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: isRack
          ? Container(
              decoration: BoxDecoration(
                gradient: ConsoleTheme.cardBgGradient(context),
                borderRadius: BorderRadius.circular(ConsoleTheme.cardRadius),
                border: Border.all(color: ConsoleTheme.cardBorder(context)),
                boxShadow: ConsoleTheme.glowShadow(context),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: content,
              ),
            )
          : Card(
              child: content,
            ),
    );
  }
}

class _DoorLockIcon extends StatelessWidget {
  final bool isUnlocked;
  static const double size = 28;
  const _DoorLockIcon({required this.isUnlocked});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return ScaleTransition(scale: animation, child: child);
      },
      child: Icon(
        isUnlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
        key: ValueKey(isUnlocked),
        size: size,
        color: isUnlocked
            ? Theme.of(context).colorScheme.primary
            : (isLight ? AppTheme.lightTextSecondary : Colors.white54),
      ),
    );
  }
}

class _CabinetDoorVisual extends StatelessWidget {
  final bool isOpen;
  final bool isDoubleDoor;

  const _CabinetDoorVisual({
    required this.isOpen,
    required this.isDoubleDoor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 82,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: isOpen ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
        builder: (context, openValue, _) {
          return CustomPaint(
            painter: _CabinetDoorPainter(
              openFactor: openValue,
              isDoubleDoor: isDoubleDoor,
            ),
          );
        },
      ),
    );
  }
}

class _CabinetDoorPainter extends CustomPainter {
  final double openFactor;
  final bool isDoubleDoor;

  _CabinetDoorPainter({
    required this.openFactor,
    required this.isDoubleDoor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    const frameMargin = 6.0;
    final frameRect = Rect.fromLTWH(
      frameMargin,
      frameMargin,
      w - frameMargin * 2,
      h - frameMargin * 2,
    );

    // 1. Dark Server Interior Background
    final interiorPaint = Paint()
      ..color = const Color(0xFF070B10)
      ..style = PaintingStyle.fill;
    final frameRRect =
        RRect.fromRectAndRadius(frameRect, const Radius.circular(8));
    canvas.drawRRect(frameRRect, interiorPaint);

    // 2. Interior Server Rack Equipment (illuminated when door is open)
    if (openFactor > 0.01) {
      // Glow background
      final glowPaint = Paint()
        ..color = const Color(0xFF00C08B).withValues(alpha: 0.22 * openFactor)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawRRect(frameRRect, glowPaint);

      // Server slots horizontal lines
      final slotPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.12 * openFactor)
        ..strokeWidth = 1.2;
      const slotCount = 6;
      for (int i = 1; i < slotCount; i++) {
        final y = frameRect.top + (frameRect.height / slotCount) * i;
        canvas.drawLine(
          Offset(frameRect.left + 4, y),
          Offset(frameRect.right - 4, y),
          slotPaint,
        );
      }

      // Blinking / Status LED dots on the rack
      final ledPaintCyan = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.85 * openFactor);
      final ledPaintGreen = Paint()
        ..color = const Color(0xFF00C08B).withValues(alpha: 0.85 * openFactor);
      for (int i = 1; i < slotCount; i++) {
        final y = frameRect.top + (frameRect.height / slotCount) * i - 3;
        canvas.drawCircle(Offset(frameRect.left + 8, y), 1.5, ledPaintGreen);
        canvas.drawCircle(Offset(frameRect.left + 14, y), 1.5, ledPaintCyan);
      }
    }

    // 3. Draw Cabinet Doors (closed or swinging open)
    final doorPaint = Paint()
      ..color = const Color(0xFF141D27)
      ..style = PaintingStyle.fill;
    final doorBorder = Paint()
      ..color = openFactor > 0.5
          ? const Color(0xFF00C08B).withValues(alpha: 0.6)
          : const Color(0xFF2A3A4E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    if (isDoubleDoor) {
      // FRONT 1: Double Door (Swings open left and right)
      final midX = frameRect.center.dx;
      final doorW = (frameRect.width / 2) - 1.5;

      // Left Door
      final leftOpenShift = doorW * 0.65 * openFactor;
      final leftPath = Path()
        ..moveTo(frameRect.left + 1, frameRect.top + 1)
        ..lineTo(
            midX - 1 - leftOpenShift, frameRect.top + 1 + (4 * openFactor))
        ..lineTo(
            midX - 1 - leftOpenShift, frameRect.bottom - 1 - (4 * openFactor))
        ..lineTo(frameRect.left + 1, frameRect.bottom - 1)
        ..close();
      canvas.drawPath(leftPath, doorPaint);
      canvas.drawPath(leftPath, doorBorder);

      // Right Door
      final rightOpenShift = doorW * 0.65 * openFactor;
      final rightPath = Path()
        ..moveTo(
            midX + 1 + rightOpenShift, frameRect.top + 1 + (4 * openFactor))
        ..lineTo(frameRect.right - 1, frameRect.top + 1)
        ..lineTo(frameRect.right - 1, frameRect.bottom - 1)
        ..lineTo(midX + 1 + rightOpenShift,
            frameRect.bottom - 1 - (4 * openFactor))
        ..close();
      canvas.drawPath(rightPath, doorPaint);
      canvas.drawPath(rightPath, doorBorder);

      // Center Handles
      final handlePaint = Paint()
        ..color = (openFactor > 0.5 ? const Color(0xFF00C08B) : Colors.white)
            .withValues(alpha: 0.7)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      final leftHandleX = midX - 4 - leftOpenShift;
      final rightHandleX = midX + 4 + rightOpenShift;
      final handleY = frameRect.center.dy;
      canvas.drawLine(Offset(leftHandleX, handleY - 6),
          Offset(leftHandleX, handleY + 6), handlePaint);
      canvas.drawLine(Offset(rightHandleX, handleY - 6),
          Offset(rightHandleX, handleY + 6), handlePaint);
    } else {
      // BACK 1: Single Door (Swings open from the right towards left)
      final openShift = (frameRect.width - 2) * 0.55 * openFactor;
      final singleDoorPath = Path()
        ..moveTo(frameRect.left + 1, frameRect.top + 1)
        ..lineTo(frameRect.right - 1 - openShift,
            frameRect.top + 1 + (5 * openFactor))
        ..lineTo(frameRect.right - 1 - openShift,
            frameRect.bottom - 1 - (5 * openFactor))
        ..lineTo(frameRect.left + 1, frameRect.bottom - 1)
        ..close();
      canvas.drawPath(singleDoorPath, doorPaint);
      canvas.drawPath(singleDoorPath, doorBorder);

      // Door Handle on Right
      final handlePaint = Paint()
        ..color = (openFactor > 0.5 ? const Color(0xFF00C08B) : Colors.white)
            .withValues(alpha: 0.7)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      final handleX = frameRect.right - 6 - openShift;
      final handleY = frameRect.center.dy;
      canvas.drawLine(Offset(handleX, handleY - 8),
          Offset(handleX, handleY + 8), handlePaint);
    }

    // 4. Outer Metallic Frame Border
    final outerFramePaint = Paint()
      ..color = const Color(0xFF2A3A4E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(frameRRect, outerFramePaint);
  }

  @override
  bool shouldRepaint(covariant _CabinetDoorPainter oldDelegate) {
    return oldDelegate.openFactor != openFactor ||
        oldDelegate.isDoubleDoor != isDoubleDoor;
  }
}
