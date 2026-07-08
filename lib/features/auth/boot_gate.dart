import 'package:flutter/material.dart';

import '../../core/auth/remember_me_store.dart';
import '../../core/auth/session_flow_service.dart';
import '../../core/config/app_config.dart';
import '../../core/security/app_lock_controller.dart';
import '../../core/theme/app_theme.dart';

/// App entry gate.
///
/// If the user enabled "Remember Me" and we still have a valid portal token,
/// we silently restore the session and jump straight to `/home`.
/// Otherwise, we go to `/welcome`.
class BootGate extends StatefulWidget {
  const BootGate({super.key});

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  bool _working = true;
  String _label = 'Starting...';

  @override
  void initState() {
    super.initState();
    // Defer to allow the first frame to paint (avoid splash "stuck" feel).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _boot();
    });
  }

  Future<void> _boot() async {
    try {
      if (AppConfig.isDemoMode) {
        AppLockController.instance.prepareForHomeEntry(
          requireImmediateUnlock: false,
        );
        _goHome();
        return;
      }

      final enabled = await rememberMeStore.isEnabled();
      final token = await rememberMeStore.getAuthToken();

      if (!enabled || token == null || token.isEmpty) {
        _goWelcome();
        return;
      }

      if (!mounted) return;
      setState(() {
        _working = true;
        _label = 'Restoring session...';
      });

      final bootstrap =
          await SessionFlowService.instance.bootstrapFromToken(token: token);
      final site = bootstrap.site;

      final isRackConsoleAccount =
          bootstrap.isRackConsoleAccount;
      final buildIsRackConsole = AppConfig.isRackConsoleBuild;
      if (buildIsRackConsole != isRackConsoleAccount) {
        await SessionFlowService.instance.signOut();
        _goWelcome();
        return;
      }

      final targetIp = site['open_ip'];
      final sitePass = (site['site_pass'] ?? '').toString();

      if (targetIp == null || targetIp.toString().isEmpty || sitePass.isEmpty) {
        // Can't log into the rack API without per-site credentials.
        await rememberMeStore.clear();
        _goWelcome();
        return;
      }

      if (!mounted) return;
      setState(() {
        _label = 'Connecting to rack...';
      });

      final ok = await SessionFlowService.instance.connectRackSession(site);

      if (!ok) {
        // Portal session is valid but rack credentials/network failed;
        // keep token (user may fix network), but route them to auth so they can retry.
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/auth');
        return;
      }

      if (!mounted) return;
      AppLockController.instance.prepareForHomeEntry(
        requireImmediateUnlock: true,
      );
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (_) {
      // Any unexpected boot error: fall back to welcome.
      _goWelcome();
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  void _goWelcome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/welcome');
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'DCS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 18),
              if (_working)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
