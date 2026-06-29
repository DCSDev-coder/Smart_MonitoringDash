import 'package:flutter/material.dart';

import '../../core/network/cpanel_api_service.dart';
import '../../core/security/app_lock_controller.dart';
import 'secure_action_guard.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  bool _promptInFlight = false;

  @override
  void initState() {
    super.initState();
    AppLockController.instance.addListener(_handleLockStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleLockStateChanged();
    });
  }

  @override
  void dispose() {
    AppLockController.instance.removeListener(_handleLockStateChanged);
    super.dispose();
  }

  void _handleLockStateChanged() {
    if (!mounted) return;
    setState(() {});
    _maybePromptUnlock();
  }

  void _maybePromptUnlock() {
    if (!mounted) return;
    if (_promptInFlight || !AppLockController.instance.isLocked) return;

    _promptInFlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _promptInFlight = false;
        return;
      }

      final ok = await SecureActionGuard.requestAuthorization(
        context,
        reason: 'Unlock Smart Monitoring to continue',
        allowPin: CpanelApiService.instance.hasPin,
      );

      if (!mounted) {
        _promptInFlight = false;
        return;
      }

      _promptInFlight = false;
      if (ok) {
        AppLockController.instance.unlock();
      } else {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locked = AppLockController.instance.isLocked;

    return Stack(
      children: [
        widget.child,
        if (locked)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xE60A0F16),
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF111823),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x59000000),
                              blurRadius: 32,
                              offset: Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00BD10)
                                      .withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.lock_rounded,
                                  size: 34,
                                  color: Color(0xFF00BD10),
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'App Locked',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                CpanelApiService.instance.hasPin
                                    ? 'Use biometrics, device passcode, or your app PIN to continue.'
                                    : 'Use biometrics, device passcode, or your password to continue.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontSize: 14,
                                  height: 1.4,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _promptInFlight
                                      ? null
                                      : _maybePromptUnlock,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF00BD10),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    _promptInFlight ? 'Checking...' : 'Unlock',
                                    style: const TextStyle(
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
