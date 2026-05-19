import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/network/api_service.dart';
import '../../core/security/secure_action_session.dart';
import './dashboard_glass.dart';
import '../../core/theme/app_theme.dart';

class SecureActionGuard {
  SecureActionGuard._();

  static Future<bool> ensureAuthorized(
    BuildContext context, {
    required String reason,
    Duration ttl = const Duration(seconds: 30),
  }) async {
    if (SecureActionSession.instance.isValid) return true;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SecureActionSheet(reason: reason),
    );

    if (ok == true) {
      SecureActionSession.instance.grant(ttl: ttl);
      return true;
    }
    return false;
  }
}

class _SecureActionSheet extends StatefulWidget {
  final String reason;
  const _SecureActionSheet({required this.reason});

  @override
  State<_SecureActionSheet> createState() => _SecureActionSheetState();
}

class _SecureActionSheetState extends State<_SecureActionSheet> {
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
    if (_hasBiometrics && !_autoPrompted) {
      _autoPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _runDeviceAuth();
      });
    }
  }

  Future<void> _runDeviceAuth() async {
    if (!mounted) return;
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: widget.reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;
      if (!ok) {
        setState(() => _isAuthenticating = false);
        return;
      }
      Navigator.pop(context, true);
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

  Future<void> _runPasswordAuth() async {
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

      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isAuthenticating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auth failed. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                  'CONFIRM ACTION',
                  style: TextStyle(
                    color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isLight
                        ? AppTheme.lightTextSecondary
                        : Colors.white.withValues(alpha: 0.8),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.reason,
              style: TextStyle(
                color: isLight
                    ? AppTheme.lightTextSecondary
                    : Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 14),
            if (!kIsWeb && _deviceAuthSupported) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isAuthenticating ? null : _runDeviceAuth,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orangeAccent.withValues(alpha: 0.85),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(_hasBiometrics ? 'Use Biometrics' : 'Use PIN'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _pwdCtrl,
              focusNode: _pwdFocus,
              obscureText: _obscurePwd,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _runPasswordAuth(),
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
                  icon: Icon(
                    _obscurePwd ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isAuthenticating ? null : _runPasswordAuth,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  foregroundColor:
                      isLight ? AppTheme.lightTextPrimary : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Confirm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
