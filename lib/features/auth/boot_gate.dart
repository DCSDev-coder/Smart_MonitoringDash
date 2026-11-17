import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/auth/remember_me_store.dart';
import '../../core/auth/session_flow_service.dart';
import '../../core/config/app_config.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/security/app_lock_controller.dart';
import '../../shared/widgets/animated_dcs_logo.dart';

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
      final savedToken = await rememberMeStore.getAuthToken();
      final webSessionToken =
          kIsWeb ? CpanelApiService.instance.getAuthTokenInMemory() : null;
      final token = (enabled && savedToken != null && savedToken.isNotEmpty)
          ? savedToken
          : (webSessionToken != null && webSessionToken.isNotEmpty
              ? webSessionToken
              : null);

      if (token == null || token.isEmpty) {
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
        requireImmediateUnlock: !kIsWeb,
      );
      Navigator.of(context).pushReplacementNamed('/home');
    } on SessionBootstrapTransientException {
      if (kIsWeb && CpanelApiService.instance.currentSite != null) {
        _goHome();
      } else {
        _goWelcome();
      }
    } on SessionBootstrapInvalidException {
      await SessionFlowService.instance.signOut();
      _goWelcome();
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
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF060B11),
      body: SafeArea(
        child: Stack(
          children: [
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: 220,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: AnimatedDcsLogo.login(),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 28,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 3,
                      child: _working
                          ? LinearProgressIndicator(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.12,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(accent),
                            )
                          : Container(
                              color: accent,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
