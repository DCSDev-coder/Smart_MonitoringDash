import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';
import '../../../shared/widgets/dashboard_glass.dart';
import '../../../core/network/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_gradient_fill.dart';

class DoorControlSection extends StatelessWidget {
  final List<Map<String, dynamic>> doors;
  final void Function(int id, String name) onUnlock;
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
      return DashboardGlass(
        radius: 22,
        padding: const EdgeInsets.all(16),
        tint: isLight ? const Color(0xFF00A3FF) : null,
        borderColor: isLight ? Colors.transparent : null,
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
                      ? Colors.white.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.72),
                  fontSize: isLight ? 13 : 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      );
    }

    if (doors.isEmpty) {
      return DashboardGlass(
        radius: 18,
        padding: const EdgeInsets.all(16),
        tint: isLight ? const Color(0xFF00A3FF) : null,
        borderColor: isLight ? Colors.transparent : null,
        child: Center(
          child: Text(
            'No doors configured',
            style: TextStyle(
              color: isLight
                  ? Colors.white.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.65),
              fontSize: isLight ? 13 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return DashboardGlass(
      radius: 22,
      padding: const EdgeInsets.all(16),
      tint: isLight ? const Color(0xFF00A3FF) : null,
      borderColor: isLight ? Colors.transparent : null,
      child: LayoutBuilder(
        builder: (context, outer) {
          final heightBounded = outer.maxHeight.isFinite;

          Widget doorBody({required bool scrollable}) {
            return LayoutBuilder(builder: (context, c) {
              final isWide = c.maxWidth >= 520;

              if (!isWide) {
                final list = Column(
                  children: [
                    for (final door in doors)
                      _DoorRow(
                        door: door,
                        canUnlock: canUnlock,
                        onUnlock: onUnlock,
                      ),
                  ],
                );
                if (!scrollable) return list;
                return SingleChildScrollView(child: list);
              }

              final tiles = doors
                  .map((d) => _DoorTile(
                        door: d,
                        canUnlock: canUnlock,
                        onUnlock: onUnlock,
                      ))
                  .toList();

              if (!scrollable) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tiles.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.45,
                  ),
                  itemBuilder: (_, i) => tiles[i],
                );
              }

              return GridView.builder(
                itemCount: tiles.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.45,
                ),
                itemBuilder: (_, i) => tiles[i],
              );
            });
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DOOR ACCESS',
                style: TextStyle(
                  color: isLight ? Colors.white : Colors.white,
                  fontSize: isLight ? 13 : 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${doors.length} doors',
                style: TextStyle(
                  color: isLight
                      ? Colors.white.withValues(alpha: 0.75)
                      : Colors.white.withValues(alpha: 0.55),
                  fontSize: isLight ? 12 : 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
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

class _DoorRow extends StatelessWidget {
  final Map<String, dynamic> door;
  final bool canUnlock;
  final void Function(int id, String name) onUnlock;

  const _DoorRow({
    required this.door,
    required this.canUnlock,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final rawName = door['name']?.toString() ?? 'Unknown';
    final id = int.tryParse(door['id']?.toString() ?? '') ?? 0;
    final isUnlocked = door['isOpen'] == true;
    final enabled = canUnlock && !isUnlocked && id != 0;

    // Light-mode: keep the section card blue but make each row a light surface.
    // User request: keep all door rows the same background color.
    final rowTint = isLight ? const Color(0xFFF5F7FF) : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DashboardGlass(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        tint: rowTint ??
            (isLight
                ? const Color(0xFFF5F7FF)
                : const Color(0xFF0B0F14).withValues(alpha: 0.35)),
        borderColor: isLight ? AppTheme.lightStroke : null,
        child: Row(
          children: [
            Expanded(
              child: Text(
                rawName,
                style: TextStyle(
                  color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: isLight ? 14 : 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 128,
              height: isLight ? 40 : 38,
              child: _AnimatedUnlockButton(
                enabled: enabled,
                label: isUnlocked ? 'Unlocked' : (canUnlock ? 'Unlock' : 'No Access'),
                onPressed: enabled ? () => onUnlock(id, rawName) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoorTile extends StatelessWidget {
  final Map<String, dynamic> door;
  final bool canUnlock;
  final void Function(int id, String name) onUnlock;

  const _DoorTile({
    required this.door,
    required this.canUnlock,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final rawName = (door['name']?.toString() ?? 'Unknown').toUpperCase();
    final id = int.tryParse(door['id']?.toString() ?? '') ?? 0;
    final isUnlocked = door['isOpen'] == true;
    final enabled = canUnlock && !isUnlocked && id != 0;

    return DashboardGlass(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      tint: isLight
          ? const Color(0xFFF5F7FF)
          : const Color(0xFF0B0F14).withValues(alpha: 0.35),
      borderColor: isLight ? AppTheme.lightStroke : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            rawName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isLight ? AppTheme.lightTextPrimary : Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: isLight ? 14 : 13,
              letterSpacing: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: isLight ? 42 : 40,
            child: _AnimatedUnlockButton(
              enabled: enabled,
              label: isUnlocked ? 'UNLOCKED' : (canUnlock ? 'UNLOCK' : 'NO ACCESS'),
              onPressed: enabled ? () => onUnlock(id, door['name']?.toString() ?? '') : null,
              pill: true,
            ),
          ),
        ],
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
        final bg =
            disabled ? (isLight ? Colors.black : Colors.white).withValues(alpha: 0.10) : null;

        return Material(
          color: Colors.transparent,
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
                          color: const Color(0xFF00A3FF)
                              .withValues(alpha: 0.16),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: AppTheme.accentGreen
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
                        fontSize:
                            widget.pill ? (isLight ? 15 : 14) : (isLight ? 13 : 12),
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
  final _pwdCtrl = TextEditingController();
  final _pwdFocus = FocusNode();

  bool _isAuthenticating = false;
  bool _obscurePwd = true;

  bool _biometricsChecked = false;
  bool _deviceAuthSupported = false;
  bool _hasBiometrics = false;
  bool _autoPrompted = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _checkAndAutoPrompt();
    }
  }

  @override
  void dispose() {
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

      final res = await ApiService.instance.openCloseDoor(widget.doorId, 1);
      if (!mounted) return;

      if (res != null && res['success'] == true) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.doorName} unlocked!')),
        );
      } else {
        setState(() => _isAuthenticating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Unlock failed. If your session expired, use password.'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isAuthenticating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric auth failed. Use password instead.'),
        ),
      );
    }
  }

  Future<void> _runPasswordUnlock() async {
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);
    try {
      final username = await ApiService.instance.getUsername() ?? 'admin';
      final pwd = _pwdCtrl.text;
      final loginSuccess = await ApiService.instance.login(username, pwd);
      if (!mounted) return;

      if (!loginSuccess) {
        setState(() => _isAuthenticating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect password')),
        );
        return;
      }

      final res = await ApiService.instance.openCloseDoor(widget.doorId, 1);
      if (!mounted) return;

      if (res != null && res['success'] == true) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.doorName} unlocked!')),
        );
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to unlock door via API')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isAuthenticating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlock failed. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DashboardGlass(
        radius: 24,
        padding: const EdgeInsets.all(24),
        tint: isLight ? Colors.white : const Color(0xFF0B0F14),
        borderColor: isLight ? AppTheme.lightStroke : null,
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
                    color: isLight
                        ? AppTheme.lightTextPrimary
                        : Colors.white,
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
              _deviceAuthSupported
                  ? (_hasBiometrics
                      ? 'Confirm with fingerprint/Face ID, or enter password to unlock ${widget.doorName}'
                      : 'Confirm with phone PIN, or enter password to unlock ${widget.doorName}')
                  : 'Please enter password to unlock ${widget.doorName}',
              style: TextStyle(
                color: isLight
                    ? AppTheme.lightTextSecondary
                    : Colors.white.withValues(alpha: 0.70),
                fontSize: 12,
              ),
            ),
            if (_deviceAuthSupported) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.fingerprint_rounded, size: 18),
                label: Text(
                  _hasBiometrics ? 'Use Fingerprint / Face ID' : 'Use Phone PIN',
                ),
                onPressed:
                    _isAuthenticating ? null : _runDeviceAuthUnlock,
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
            TextField(
              controller: _pwdCtrl,
              focusNode: _pwdFocus,
              obscureText: _obscurePwd,
              autofocus: false,
              style: TextStyle(
                color: isLight ? AppTheme.lightTextPrimary : Colors.white,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: isLight
                    ? const Color(0xFFF3F4F7)
                    : Colors.white.withValues(alpha: 0.08),
                hintText: 'Password',
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
                  borderSide:
                      const BorderSide(color: AppTheme.accentGreen, width: 1.4),
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
                  child: CircularProgressIndicator(color: AppTheme.accentGreen),
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
    );
  }
}
