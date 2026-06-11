import 'package:flutter/material.dart';

import '../../core/auth/remember_me_store.dart';
import '../../core/network/adapter_api_service.dart';
import '../../core/network/api_service.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/notifications/push_notification_service.dart';
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

      final authRes = await CpanelApiService.instance.authMe(token: token);
      if (authRes == null || authRes['status'] != 'success') {
        await rememberMeStore.clear();
        _goWelcome();
        return;
      }

      final sites = authRes['sites'];
      if (sites is! List || sites.isEmpty) {
        await rememberMeStore.clear();
        _goWelcome();
        return;
      }

      final firstSite = sites[0];
      if (firstSite is! Map) {
        await rememberMeStore.clear();
        _goWelcome();
        return;
      }

      final mergedSite = await CpanelApiService.instance
          .mergeCurrentMemberPermissions(Map<String, dynamic>.from(firstSite));
      final site = await _mergeSiteWithRemoteConfig(mergedSite);
      CpanelApiService.instance.currentSite = site;
      await PushNotificationService.instance.syncTokenWithBackendIfPossible();

      final targetIp = site['open_ip'];
      final siteUser = (site['site_user'] ?? 'admin').toString();
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

      final ok = await ApiService.instance.login(
        siteUser,
        sitePass,
        ip: targetIp.toString(),
      );

      if (!ok) {
        // Portal session is valid but rack credentials/network failed;
        // keep token (user may fix network), but route them to auth so they can retry.
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/auth');
        return;
      }

      if (!mounted) return;
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

  Future<Map<String, dynamic>> _mergeSiteWithRemoteConfig(
      Map<String, dynamic> site) async {
    final siteId = int.tryParse(site['site_id']?.toString() ?? '');
    Map<String, dynamic>? cfgEnvelope;

    if (siteId != null) {
      if (AdapterApiService.instance.isConfigured) {
        cfgEnvelope = await AdapterApiService.instance.fetchAppConfig(siteId: siteId);
      }
      cfgEnvelope ??=
          await CpanelApiService.instance.fetchAppConfig(siteId: siteId);
    }

    return CpanelApiService.instance.mergeSiteWithAppConfig(site, cfgEnvelope);
  }

  void _goWelcome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/welcome');
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
