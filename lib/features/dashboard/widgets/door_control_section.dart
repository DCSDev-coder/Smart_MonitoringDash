import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';
import '../../../core/network/api_service.dart';
import '../../../core/network/adapter_api_service.dart';
import '../../../core/network/cpanel_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_gradient_fill.dart';
import '../../../shared/utils/app_toast.dart';

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
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppTheme.accentGreen,
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
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _doUnlock(int id, String rawName) async {
    final success = await widget.onUnlock(id, rawName);
    if (success == true && mounted) {
      setState(() => _localUnlocked = true);
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _localUnlocked = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final rawName = widget.door['name']?.toString() ?? 'Unknown';
    final id = int.tryParse(widget.door['id']?.toString() ?? '') ?? 0;
    final isUnlocked = _localUnlocked || (widget.door['isOpen'] == true);
    final enabled = widget.canUnlock && !isUnlocked && id != 0;

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
                label: isUnlocked
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
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _doUnlock(int id, String rawName) async {
    final success = await widget.onUnlock(id, rawName);
    if (success == true && mounted) {
      setState(() => _localUnlocked = true);
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _localUnlocked = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final rawName = widget.door['name']?.toString() ?? 'Unknown';
    final id = int.tryParse(widget.door['id']?.toString() ?? '') ?? 0;
    final isUnlocked = _localUnlocked || (widget.door['isOpen'] == true);
    final enabled = widget.canUnlock && !isUnlocked && id != 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isLight
                    ? const Color(0xFFF1F5F9)
                    : Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _DoorLockIcon(isUnlocked: isUnlocked, size: 38),
              ),
            ),
            const SizedBox(height: 5),
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
                          color: AppTheme.accentGreen.withValues(alpha: 0.10),
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
                        colors: const [
                          Color(0xFF00A3FF),
                          Color(0xFF0FA4A8),
                          AppTheme.accentGreen,
                          Color(0xFF00A3FF),
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

  const UnlockDoorSheet({
    super.key,
    required this.doorId,
    required this.doorName,
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
  bool _autoPrompted = false;
  bool get _isRackConsoleMode =>
      CpanelApiService.instance.isCurrentSiteRackConsole();

  @override
  void initState() {
    super.initState();
    _initUsername();
    if (!kIsWeb && !_isRackConsoleMode) {
      _checkAndAutoPrompt();
    }
  }

  Future<void> _initUsername() async {
    final portalUsername = await CpanelApiService.instance.getUsername() ?? 'admin';
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
        _hasBiometrics = supported && available.isNotEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deviceAuthSupported = false;
        _hasBiometrics = false;
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

  Future<void> _runDeviceAuthUnlock() async {
    if (!mounted) return;
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Confirm to unlock ${widget.doorName}',
        options: const AuthenticationOptions(
          // Allow device credentials fallback (PIN/pattern) so devices without
          // enrolled biometrics aren't forced into biometric setup screens.
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;
      if (!ok) {
        setState(() => _isAuthenticating = false);
        return;
      }

      final site = CpanelApiService.instance.currentSite;
      final siteId = site == null
          ? null
          : (int.tryParse(site['site_id']?.toString() ?? '') ??
              int.tryParse(site['id']?.toString() ?? ''));

      Map<String, dynamic>? res;
      if (AdapterApiService.instance.isConfigured && siteId != null) {
        res = await AdapterApiService.instance.openCloseDoor(
          siteId: siteId,
          accessId: widget.doorId,
          status: 1,
          accessType: '1',
        );
      }
      res ??= await ApiService.instance.openCloseDoor(widget.doorId, 1);
      if (!mounted) return;

      if (res != null && res['success'] == true) {
        Navigator.pop(context, true);
        AppToast.showSuccess(context, '${widget.doorName} unlocked!');
      } else {
        setState(() => _isAuthenticating = false);
        AppToast.showError(
            context, 'Unlock failed. If your session expired, use password.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isAuthenticating = false);
      AppToast.showError(
          context, 'Biometric auth failed. Use password instead.');
    }
  }

  bool _usePin = true;

  Future<void> _runPasswordUnlock() async {
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);
    try {
      final site = CpanelApiService.instance.currentSite;
      final siteId = site == null
          ? null
          : (int.tryParse(site['site_id']?.toString() ?? '') ??
              int.tryParse(site['id']?.toString() ?? ''));

      int? remoteLogOverrideUserId;
      Map<String, dynamic>? res;

      if (_isRackConsoleMode) {
        if (siteId == null) {
          setState(() => _isAuthenticating = false);
          AppToast.show(context, 'Site connection required.');
          return;
        }

        final pin = _pwdCtrl.text.trim();
        if (pin.length < 4 || pin.length > 6) {
          setState(() => _isAuthenticating = false);
          AppToast.show(context, 'Enter a 4-6 digit PIN.');
          return;
        }

        final verifyRes = await CpanelApiService.instance.verifySiteUserPin(
          siteId: siteId,
          pin: pin,
        );
        if (!mounted) return;

        if (verifyRes != null && verifyRes['status'] == 'success') {
          remoteLogOverrideUserId = verifyRes['user_id'];
          res = await AdapterApiService.instance.openCloseDoor(
            siteId: siteId,
            accessId: widget.doorId,
            status: 1,
            accessType: '1',
          );
          res ??= await ApiService.instance.openCloseDoor(widget.doorId, 1);
        } else {
          setState(() => _isAuthenticating = false);
          AppToast.showError(context, 'Invalid PIN or Access Denied');
          return;
        }
      } else if (_usePin) {
        final pin = _pwdCtrl.text.trim();
        if (pin.isEmpty) {
          AppToast.showError(context, 'Please enter PIN');
          setState(() => _isAuthenticating = false);
          return;
        }

        // Strictly verify PIN with our secure CPanel backend
        final verifyRes = await CpanelApiService.instance.verifyPin(pin);
        if (!mounted) return;

        if (verifyRes != null && verifyRes['status'] == 'success') {
          // PIN is securely verified! Now open the door.
          if (AdapterApiService.instance.isConfigured && siteId != null) {
            res = await AdapterApiService.instance.openCloseDoor(
              siteId: siteId,
              accessId: widget.doorId,
              status: 1,
              accessType: '1',
            );
          }
          res ??= await ApiService.instance.openCloseDoor(widget.doorId, 1);
        } else {
          setState(() => _isAuthenticating = false);
          AppToast.showError(context, 'Incorrect PIN');
          return;
        }
      } else {
        // Try portal password check first
        final portalUsername = _userCtrl.text.trim();
        final pwd = _pwdCtrl.text;
        final loginRes =
            await CpanelApiService.instance.login(portalUsername, pwd);
        if (!mounted) return;

        bool loginSuccess = loginRes != null && loginRes['status'] == 'success';
        if (!loginSuccess) {
          // Fallback to old password login against physical Dahua
          final dahuaUsername =
              await ApiService.instance.getUsername() ?? 'admin';
          final dahuaLoginSuccess =
              await ApiService.instance.login(dahuaUsername, pwd);
          if (!mounted) return;

          if (!dahuaLoginSuccess) {
            setState(() => _isAuthenticating = false);
            AppToast.showError(context, 'Incorrect password');
            return;
          }
        }

        if (AdapterApiService.instance.isConfigured && siteId != null) {
          res = await AdapterApiService.instance.openCloseDoor(
            siteId: siteId,
            accessId: widget.doorId,
            status: 1,
            accessType: '1',
          );
        }
        res ??= await ApiService.instance.openCloseDoor(widget.doorId, 1);
      }

      if (!mounted) return;

      if (res != null && res['success'] == true) {
        if (siteId != null) {
          CpanelApiService.instance.logRemoteAccess(
            siteId: siteId,
            doorId: widget.doorId,
            overrideUserId: remoteLogOverrideUserId,
          );
        }
        Navigator.pop(context, true);
        AppToast.showSuccess(context, '${widget.doorName} unlocked!');
      } else {
        Navigator.pop(context);
        AppToast.showError(
            context, res?['message'] ?? 'Failed to unlock door via API');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isAuthenticating = false);
      AppToast.showError(context, 'Unlock failed. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Card(
        child: Padding(
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
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.22),
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
                      color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: isLight
                            ? AppTheme.lightTextSecondary
                            : Colors.white.withValues(alpha: 0.8)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _isRackConsoleMode
                    ? 'Enter the approving user PIN to unlock ${widget.doorName} from the Rack Console.'
                    : _usePin
                        ? (_deviceAuthSupported
                            ? 'Confirm with fingerprint/Face ID, or enter your 4-6 digit Door Access PIN to unlock ${widget.doorName}'
                            : 'Please enter your 4-6 digit Door Access PIN to unlock ${widget.doorName}')
                        : 'Please enter your account password to unlock ${widget.doorName}',
                style: TextStyle(
                  color: isLight
                      ? AppTheme.lightTextSecondary
                      : Colors.white.withValues(alpha: 0.70),
                  fontSize: 12,
                ),
              ),
              if (!_isRackConsoleMode && _deviceAuthSupported) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.fingerprint_rounded, size: 18),
                  label: Text(
                    _hasBiometrics
                        ? 'Use Fingerprint / Face ID'
                        : 'Use Phone PIN',
                  ),
                  onPressed: _isAuthenticating ? null : _runDeviceAuthUnlock,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentGreen,
                    side: BorderSide(
                      color: isLight
                          ? AppTheme.lightStroke
                          : Colors.white.withValues(alpha: 0.22),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isRackConsoleMode ? 'PIN' : (_usePin ? 'PIN' : 'Password'),
                    style: TextStyle(
                      color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!_isRackConsoleMode)
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
                          color: isLight ? AppTheme.accentGreen : Colors.white,
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
                autofocus: false,
                keyboardType:
                    _usePin ? TextInputType.number : TextInputType.text,
                style: TextStyle(
                  color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                  fontSize: _usePin ? 24 : 16,
                  letterSpacing: _usePin ? 8.0 : null,
                ),
                textAlign: _usePin ? TextAlign.center : TextAlign.start,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isLight
                      ? const Color(0xFFF3F4F7)
                      : Colors.white.withValues(alpha: 0.08),
                  hintText: _usePin ? '••••' : 'Password',
                  hintStyle: TextStyle(
                    color: isLight
                        ? AppTheme.lightTextSecondary
                        : Colors.white.withValues(alpha: 0.45),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isLight
                          ? const Color(0xFFD5DAE2)
                          : Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isLight
                          ? const Color(0xFFD5DAE2)
                          : Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: AppTheme.accentGreen, width: 1.4),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePwd ? Icons.visibility_off : Icons.visibility,
                      color: isLight
                          ? AppTheme.lightTextSecondary
                          : Colors.white.withValues(alpha: 0.75),
                    ),
                    onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (_isAuthenticating)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child:
                        CircularProgressIndicator(color: AppTheme.accentGreen),
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
                      backgroundColor: AppTheme.accentGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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

class _DoorLockIcon extends StatelessWidget {
  final bool isUnlocked;
  final double size;
  const _DoorLockIcon({required this.isUnlocked, this.size = 28});

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
            ? AppTheme.accentGreen
            : (isLight ? AppTheme.lightTextSecondary : Colors.white54),
      ),
    );
  }
}
