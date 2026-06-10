import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/network/api_service.dart';
import '../../core/network/adapter_api_service.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/security/secure_action_session.dart';
import './dashboard_glass.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/utils/app_toast.dart';

class SecureActionGuard {
  SecureActionGuard._();

  static Future<bool> ensureAuthorized(
    BuildContext context, {
    required String reason,
    Duration ttl = const Duration(seconds: 30),
    bool allowPin = false,
  }) async {
    if (SecureActionSession.instance.isValid) return true;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SecureActionSheet(reason: reason, allowPin: allowPin),
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
  final bool allowPin;
  const _SecureActionSheet({required this.reason, required this.allowPin});

  @override
  State<_SecureActionSheet> createState() => _SecureActionSheetState();
}

class _SecureActionSheetState extends State<_SecureActionSheet> {
  final _localAuth = LocalAuthentication();
  final _userCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _pwdFocus = FocusNode();

  bool _isAuthenticating = false;
  bool _obscurePwd = true;
  late bool _usePin = widget.allowPin;

  bool _biometricsChecked = false;
  bool _deviceAuthSupported = false;
  bool _hasBiometrics = false;
  bool _autoPrompted = false;

  @override
  void initState() {
    super.initState();
    _initUsername();
    if (!kIsWeb) {
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
      AppToast.showError(context, 'Biometric auth failed. Use password instead.');
    }
  }

  Future<void> _runPasswordAuth() async {
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);
    try {
      if (_usePin) {
        final pin = _pwdCtrl.text.trim();
        if (pin.length < 4) {
          setState(() => _isAuthenticating = false);
          AppToast.show(context, 'Enter your 4-6 digit PIN');
          return;
        }

        Map<String, dynamic>? verifyRes;
        if (AdapterApiService.instance.isConfigured) {
          verifyRes = await AdapterApiService.instance.verifyPin(pin);
        }
        verifyRes ??= await CpanelApiService.instance.verifyPin(pin);
        if (!mounted) return;

        final verified = verifyRes != null && verifyRes['status'] == 'success';
        if (!verified) {
          setState(() => _isAuthenticating = false);
          AppToast.showError(context, 'Incorrect PIN');
          return;
        }

        Navigator.pop(context, true);
        return;
      }

      final portalUsername = _userCtrl.text.trim();
      final pwd = _pwdCtrl.text;
      
      final loginRes =
          await CpanelApiService.instance.login(portalUsername, pwd);
      if (!mounted) return;

      bool loginSuccess = loginRes != null && loginRes['status'] == 'success';
      if (!loginSuccess) {
        // Fallback to Dahua credentials check
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

      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isAuthenticating = false);
      AppToast.showError(context, 'Auth failed. Try again.');
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
              _usePin
                  ? (_deviceAuthSupported
                      ? '${widget.reason}. Confirm with biometrics, or enter your 4-6 digit PIN.'
                      : '${widget.reason}. Enter your 4-6 digit PIN.')
                  : widget.reason,
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
                    backgroundColor:
                        Colors.orangeAccent.withValues(alpha: 0.85),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                      _hasBiometrics ? 'Use Biometrics' : 'Use Device PIN'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _usePin ? 'PIN' : 'Password',
                  style: TextStyle(
                    color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.allowPin)
                  TextButton(
                    onPressed: _isAuthenticating
                        ? null
                        : () {
                            setState(() {
                              _usePin = !_usePin;
                              _pwdCtrl.clear();
                            });
                          },
                    child: Text(
                        _usePin ? 'Use Password instead' : 'Use PIN instead'),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _pwdCtrl,
              focusNode: _pwdFocus,
              obscureText: _obscurePwd,
              keyboardType: _usePin ? TextInputType.number : TextInputType.text,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _runPasswordAuth(),
              style: TextStyle(
                color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                fontSize: _usePin ? 24 : null,
                letterSpacing: _usePin ? 8.0 : null,
                fontWeight: FontWeight.w700,
              ),
              textAlign: _usePin ? TextAlign.center : TextAlign.start,
              decoration: InputDecoration(
                labelText: _usePin ? 'PIN' : 'Password',
                hintText: _usePin ? '••••' : null,
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
