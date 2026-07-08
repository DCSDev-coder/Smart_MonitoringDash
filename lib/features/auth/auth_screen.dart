import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/network/api_service.dart';
import '../../core/network/adapter_api_service.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/config/app_config.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/security/app_lock_controller.dart';
import '../../core/auth/remember_me_store.dart';
import '../../core/utils/app_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/widgets/animated_dcs_logo.dart';
import '../../shared/widgets/fade_in_slide.dart';
import '../../shared/utils/global_video_background.dart';
import 'setup_user_screen.dart';
import '../../shared/utils/app_toast.dart';

class _RememberMeInvalidException implements Exception {
  const _RememberMeInvalidException(this.message);
  final String message;

  @override
  String toString() => message;
}

class _RememberMeTransientException implements Exception {
  const _RememberMeTransientException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  bool _loading = false;
  bool _obscure = true;
  bool _rememberMe = false;
  bool _autoLoginTried = false;
  bool _suppressLogoHero = false;

  DateTime? _lockoutEndTime;
  Timer? _lockoutTimer;

  String get _signInLabel {
    if (_lockoutEndTime == null) return 'SIGN IN';
    final diff = _lockoutEndTime!.difference(DateTime.now());
    if (diff.isNegative) return 'SIGN IN';
    final min = diff.inMinutes;
    final sec = diff.inSeconds % 60;
    return 'TRY AGAIN IN $min:${sec.toString().padLeft(2, '0')}';
  }

  TextStyle get _authFieldLabelStyle => GoogleFonts.manrope(
        color: Colors.white70,
        fontSize: 16,
        letterSpacing: 0.4,
      );

  bool get _isRackConsoleBuild => AppConfig.isRackConsoleBuild;

  bool _canEnterCurrentApp(Map<String, dynamic> site) {
    final isRackConsoleAccount =
        CpanelApiService.instance.isCurrentSiteRackConsole(site);
    return _isRackConsoleBuild ? isRackConsoleAccount : !isRackConsoleAccount;
  }

  Future<void> _rejectWrongAppMode({
    required String message,
    required bool clearRememberMe,
  }) async {
    await CpanelApiService.instance.clearSession();
    if (clearRememberMe) {
      await rememberMeStore.clear();
    }
    await ApiService.instance.logout();
    if (!mounted) return;
    setState(() => _loading = false);
    AppToast.showError(context, message);
  }

  @override
  void initState() {
    super.initState();
    GlobalVideoBackground.auth.player?.play();
    _tryAutoLogin();
    _startLockoutChecker();
  }

  void _startLockoutChecker() {
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final prefs = await SharedPreferences.getInstance();
      final lockoutMs = prefs.getInt('login_lockout_until');
      if (lockoutMs != null) {
        final lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutMs);
        if (DateTime.now().isBefore(lockoutTime)) {
          if (mounted) setState(() => _lockoutEndTime = lockoutTime);
          return;
        } else {
          await prefs.remove('login_lockout_until');
          await prefs.remove('login_failed_attempts');
        }
      }
      if (_lockoutEndTime != null && mounted) {
        setState(() => _lockoutEndTime = null);
      }
    });
  }

  Future<void> _tryAutoLogin() async {
    if (_autoLoginTried) return;
    _autoLoginTried = true;

    final enabled = await rememberMeStore.isEnabled();
    if (!enabled) return;

    final username = await rememberMeStore.getUsername();
    final token = await rememberMeStore.getAuthToken();
    if (token == null || token.isEmpty) {
      // Migration case: old versions stored passwords. We don't keep passwords
      // for Remember Me anymore, so disable and require a fresh login.
      await rememberMeStore.clear();
      return;
    }

    if (!mounted) return;
    setState(() {
      _rememberMe = true;
      _userCtrl.text = username ?? '';
      _passCtrl.clear();
    });

    await _signInWithToken(token: token, isAuto: true);
  }

  Future<Map<String, dynamic>> _mergeSiteWithRemoteConfig(
      Map<String, dynamic> site) async {
    final siteId = int.tryParse(site['site_id']?.toString() ?? '');
    Map<String, dynamic>? cfgEnvelope;

    if (siteId != null) {
      if (AdapterApiService.instance.isConfigured) {
        cfgEnvelope =
            await AdapterApiService.instance.fetchAppConfig(siteId: siteId);
      }
      cfgEnvelope ??=
          await CpanelApiService.instance.fetchAppConfig(siteId: siteId);
    }

    return CpanelApiService.instance.mergeSiteWithAppConfig(site, cfgEnvelope);
  }

  Future<void> _signInWithToken(
      {required String token, bool isAuto = false}) async {
    setState(() => _loading = true);
    try {
      final authRes = await CpanelApiService.instance.authMe(token: token);
      if (authRes == null) {
        throw const _RememberMeTransientException(
          'Saved session could not be restored right now. Please try signing in again.',
        );
      }
      if (authRes['status'] != 'success') {
        final msg = authRes['message']?.toString().trim();
        throw _RememberMeInvalidException(
          (msg != null && msg.isNotEmpty)
              ? msg
              : 'Session expired. Please sign in again.',
        );
      }

      final sites = authRes['sites'];
      if (sites is! List || sites.isEmpty) {
        throw 'No Racks found for this account. Please contact support.';
      }

      final firstSite = sites[0] as Map<String, dynamic>;
      final mergedSite = await CpanelApiService.instance
          .mergeCurrentMemberPermissions(Map<String, dynamic>.from(firstSite));
      CpanelApiService.instance.currentSite =
          await _mergeSiteWithRemoteConfig(mergedSite);
      await PushNotificationService.instance.syncTokenWithBackendIfPossible();

      if (!_canEnterCurrentApp(CpanelApiService.instance.currentSite!)) {
        final isRackConsoleAccount =
            CpanelApiService.instance.isCurrentSiteRackConsole();
        final message = _isRackConsoleBuild
            ? 'Wrong account'
            : 'This account is reserved for the Rack Console app. Please use the Rack Console installation.';
        await _rejectWrongAppMode(
          message: message,
          clearRememberMe: true,
        );
        if (!mounted) return;
        if (isRackConsoleAccount) {
          Navigator.of(context).pushReplacementNamed('/welcome');
        }
        return;
      }

      final targetIp = CpanelApiService.instance.currentSite?['open_ip'];
      final dbLocalIp =
          CpanelApiService.instance.currentSite?['local_ip']?.toString();
      final siteUser =
          CpanelApiService.instance.currentSite?['site_user'] ?? 'admin';
      final sitePass =
          (CpanelApiService.instance.currentSite?['site_pass'] ?? '')
              .toString();
      final expiryStr = CpanelApiService.instance.currentSite?['expiry_date'];

      if (expiryStr != null) {
        try {
          final expiryDate = DateTime.parse(expiryStr);
          if (expiryDate.isBefore(DateTime.now())) {
            throw 'Your Smart Rack license has expired ($expiryStr). Please contact DCS support to renew your subscription.';
          }
        } catch (e) {
          AppLog.w('Expiry parse error', tag: 'Auth', error: e);
        }
      }

      if (sitePass.isEmpty) {
        throw 'Rack credentials are missing for this site. Please ask your admin to update site_user/site_pass.';
      }

      bool ok = false;
      final prefs = await SharedPreferences.getInstance();
      final manualFallbackIp = prefs.getString('local_fallback_ip') ?? '';
      final fallbackIp = (dbLocalIp != null && dbLocalIp.isNotEmpty)
          ? dbLocalIp
          : manualFallbackIp;

      if (AdapterApiService.instance.isConfigured) {
        ok = true;
        // Attempt direct login in the background for local features (like cameras) if on Wi-Fi
        ApiService.instance.login(siteUser, sitePass, ip: targetIp).ignore();
      } else {
        ok = await ApiService.instance.login(
          siteUser,
          sitePass,
          ip: targetIp,
        );

        if (!ok && fallbackIp.isNotEmpty) {
          AppLog.i('Public IP failed, trying local fallback IP', tag: 'Auth');
          ok = await ApiService.instance.login(
            siteUser,
            sitePass,
            ip: fallbackIp,
          );
        }
      }

      if (!mounted) return;
      setState(() => _loading = false);

      if (ok) {
        AppToast.showSuccess(context, 'Login successful!');
        AppLockController.instance.prepareForHomeEntry(
          requireImmediateUnlock: isAuto,
        );
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        throw 'Connection to Rack failed.';
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.showError(context, e.toString());
      if (isAuto && e is _RememberMeInvalidException) {
        await rememberMeStore.clear();
      }
    }
  }

  Widget _buildAuthFieldBlock({
    required Duration delay,
    required String label,
    required Widget child,
  }) {
    return FadeInSlide(
      delay: delay,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _authFieldLabelStyle),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Future<void> _signIn(
      {String? username, String? password, bool isAuto = false}) async {
    final u = (username ?? _userCtrl.text).trim();
    final p = (password ?? _passCtrl.text);

    if (u.isEmpty || p.isEmpty) {
      AppToast.show(context, 'Please enter your username and password.');
      return;
    }

    setState(() => _loading = true);

    try {
      // 1. Global Login to dcstack.my
      final cpanelRes = await CpanelApiService.instance.login(
        u,
        p,
        rememberMe: _rememberMe,
      );

      if (cpanelRes == null || cpanelRes['status'] != 'success') {
        final apiMsg = cpanelRes?['message']?.toString();
        throw apiMsg ?? 'Global Login failed. Check your admin credentials.';
      }

      // 2. Fetch user's linked sites using token identity (same as auth restore).
      final token = CpanelApiService.instance.getAuthTokenInMemory();
      if (token == null || token.isEmpty) {
        throw 'Login succeeded but no session token was returned. Please sign in again.';
      }
      final authRes = await CpanelApiService.instance.authMe(token: token);
      if (authRes == null || authRes['status'] != 'success') {
        final msg = (authRes is Map<String, dynamic>)
            ? (authRes['message']?.toString() ?? 'Failed to fetch racks.')
            : 'Failed to fetch racks.';
        throw msg;
      }
      final sites = authRes['sites'];
      if (sites is! List || sites.isEmpty) {
        throw 'No Racks found for account "$u". Please contact DCS support to link your Smart Rack.';
      }

      // 3. Connect to the first site using its SPECIFIC credentials
      final firstSite = sites[0];
      final mergedSite = await CpanelApiService.instance
          .mergeCurrentMemberPermissions(Map<String, dynamic>.from(firstSite));
      CpanelApiService.instance.currentSite =
          await _mergeSiteWithRemoteConfig(mergedSite);
      await PushNotificationService.instance.syncTokenWithBackendIfPossible();

      final targetIp = CpanelApiService.instance.currentSite?['open_ip'];
      final dbLocalIp =
          CpanelApiService.instance.currentSite?['local_ip']?.toString();
      final siteUser =
          CpanelApiService.instance.currentSite?['site_user'] ?? 'admin';
      final sitePass =
          (CpanelApiService.instance.currentSite?['site_pass'] ?? '')
              .toString();
      final expiryStr = CpanelApiService.instance.currentSite?['expiry_date'];

      // 4. Validate License Expiry (Production Guard)
      if (expiryStr != null) {
        try {
          final expiryDate = DateTime.parse(expiryStr);
          if (expiryDate.isBefore(DateTime.now())) {
            throw 'Your Smart Rack license has expired ($expiryStr). Please contact DCS support to renew your subscription.';
          }
        } catch (e) {
          AppLog.w('Expiry parse error', tag: 'Auth', error: e);
        }
      }

      bool ok = false;
      final prefs = await SharedPreferences.getInstance();
      final manualFallbackIp = prefs.getString('local_fallback_ip') ?? '';
      final fallbackIp = (dbLocalIp != null && dbLocalIp.isNotEmpty)
          ? dbLocalIp
          : manualFallbackIp;

      if (AdapterApiService.instance.isConfigured) {
        ok = true;
        // Attempt direct login in the background for local features (like cameras) if on Wi-Fi
        ApiService.instance.login(siteUser, sitePass, ip: targetIp).ignore();
      } else {
        ok = await ApiService.instance.login(
          siteUser,
          sitePass,
          ip: targetIp,
        );

        if (!ok && fallbackIp.isNotEmpty) {
          AppLog.i('Public IP failed, trying local fallback IP', tag: 'Auth');
          ok = await ApiService.instance.login(
            siteUser,
            sitePass,
            ip: fallbackIp,
          );
        }
      }

      if (!mounted) {
        return;
      }
      setState(() => _loading = false);

      if (ok) {
        if (_rememberMe) {
          final token = CpanelApiService.instance.getAuthTokenInMemory();
          if (token != null && token.isNotEmpty) {
            await rememberMeStore.setEnabled(true);
            await rememberMeStore.setUsername(u);
            await rememberMeStore.setAuthToken(token);
          }
        } else {
          await rememberMeStore.clear();
        }
        if (!mounted) return;
        AppToast.showSuccess(context, 'Login successful!');
        AppLockController.instance.prepareForHomeEntry(
          requireImmediateUnlock: false,
        );
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        throw 'Connection to Rack failed. Verify your phone is on the Office Wi-Fi and that the Rack login matches.';
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showErrorDialog(e.toString());
      if (isAuto && e is _RememberMeInvalidException) {
        // Auto-login failed; don't keep retrying in a loop.
        await rememberMeStore.clear();
      }
    }
  }

  void _showErrorDialog(String message) {
    final safeMsg = AppToast.sanitizeErrorMessage(message);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E242B),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Sign In Failed', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          safeMsg,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Color(0xFF00BD10))),
          ),
        ],
      ),
    );
  }

  Future<void> _openRequestAccess() async {
    setState(() => _suppressLogoHero = true);
    // Let the widget rebuild with Hero disabled before the route transition starts.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1100),
        reverseTransitionDuration: const Duration(milliseconds: 1100),
        pageBuilder: (_, __, ___) => const SetupUserScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );

    if (!mounted) return;
    setState(() => _suppressLogoHero = false);
  }

  Future<void> _openResetPassword() async {
    setState(() => _suppressLogoHero = true);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1100),
        reverseTransitionDuration: const Duration(milliseconds: 1100),
        pageBuilder: (_, __, ___) =>
            const SetupUserScreen(mode: SetupUserMode.resetPassword),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );

    if (!mounted) return;
    setState(() => _suppressLogoHero = false);
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final uiScale = screenW >= 900 ? (screenW / 1150).clamp(1.0, 1.25) : 1.0;

    final bg = GlobalVideoBackground.auth;
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(uiScale)),
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: const Color(0xFF060B11),
          body: TickerMode(
            enabled: ModalRoute.of(context)?.isCurrent ?? true,
            child: Stack(
              children: [
                // 1. Cinematic Video Background
                Positioned.fill(
                  child: bg.controller == null
                      ? Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFF0A1220),
                                Color(0xFF060B11),
                              ],
                            ),
                          ),
                        )
                      : RepaintBoundary(
                          child: Video(
                            controller: bg.controller!,
                            fit: BoxFit.cover,
                            controls: NoVideoControls,
                            wakelock: false,
                          ),
                        ),
                ),

                // 2. Dark Overlay for glassmorphism contrast
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF060B11).withValues(alpha: 0.70),
                  ),
                ),

                // 3. Main Content
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 768;
                      return SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.only(
                          bottom: media.viewInsets.bottom + 24,
                        ),
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                const SizedBox(height: 0),
                                // ── Animated Logo ──────────────────────────────────
                                const SizedBox(height: 40),
                                SizedBox(
                                  height: 160,
                                  child: Center(
                                    child: HeroMode(
                                      enabled: !_suppressLogoHero,
                                      child: Hero(
                                        tag: 'logo',
                                        transitionOnUserGestures: true,
                                        flightShuttleBuilder: (
                                          _,
                                          animation,
                                          flightDirection,
                                          __,
                                          ___,
                                        ) {
                                          // Ensure pop always rotates RIGHT->UP regardless
                                          // of whether the Hero animation is reversing.
                                          final curved = CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeInOutSine,
                                          );
                                          final isReversing =
                                              animation.status ==
                                                  AnimationStatus.reverse;
                                          final a = flightDirection ==
                                                  HeroFlightDirection.pop
                                              ? (isReversing
                                                  ? curved
                                                  : ReverseAnimation(curved))
                                              : (isReversing
                                                  ? ReverseAnimation(curved)
                                                  : curved);
                                          return Material(
                                            type: MaterialType.transparency,
                                            child: RepaintBoundary(
                                              child: AnimatedDcsLogo.flight(
                                                animation: a,
                                              ),
                                            ),
                                          );
                                        },
                                        placeholderBuilder:
                                            (context, _, child) {
                                          // Prevent a 1-frame flash of the destination/static
                                          // logo during Hero flights (common on pop).
                                          return const SizedBox(
                                            width: 250,
                                            height: 120,
                                          );
                                        },
                                        child: const SizedBox(
                                          height: 120,
                                          child: AnimatedDcsLogo.login(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                FadeInSlide(
                                  delay: const Duration(milliseconds: 150),
                                  child: Text(
                                    'SIGN IN',
                                    style: GoogleFonts.manrope(
                                      fontSize: 28,
                                      letterSpacing: 1.2,
                                      color: Colors.white,
                                      shadows: const [
                                        Shadow(
                                          color: Color(0x6600BD10),
                                          blurRadius: 18,
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 26),

                                // ── Form Fields ────────────────────────────────────
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 560),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildAuthFieldBlock(
                                        delay:
                                            const Duration(milliseconds: 200),
                                        label: 'Username :',
                                        child: _buildGlassTextField(
                                          controller: _userCtrl,
                                          focusNode: _userFocus,
                                          hint: '',
                                          action: TextInputAction.next,
                                          onSubmitted: (_) =>
                                              _passFocus.requestFocus(),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      _buildAuthFieldBlock(
                                        delay:
                                            const Duration(milliseconds: 400),
                                        label: 'Password :',
                                        child: _buildGlassTextField(
                                          controller: _passCtrl,
                                          focusNode: _passFocus,
                                          hint: '',
                                          isPassword: true,
                                          onSubmitted: (_) => _signIn(),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      FadeInSlide(
                                        delay:
                                            const Duration(milliseconds: 450),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                onTap: () => setState(() =>
                                                    _rememberMe = !_rememberMe),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Checkbox(
                                                      value: _rememberMe,
                                                      activeColor: const Color(
                                                          0xFF00BD10),
                                                      checkColor: Colors.white,
                                                      side: const BorderSide(
                                                          color:
                                                              Colors.white54),
                                                      onChanged: (val) =>
                                                          setState(() =>
                                                              _rememberMe =
                                                                  val == true),
                                                    ),
                                                    Text(
                                                      'Remember Me',
                                                      style:
                                                          GoogleFonts.manrope(
                                                        color: Colors.white70,
                                                        fontSize: 14,
                                                        letterSpacing: 0.2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: _openResetPassword,
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    const Color(0xFFFFB347),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 8,
                                                ),
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              child: Text(
                                                'Forgot Password?',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  decoration:
                                                      TextDecoration.underline,
                                                  decorationColor:
                                                      const Color(0xFFFFB347),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: isWide ? 72 : 52),

                                // ── Buttons ────────────────────────────────
                                FadeInSlide(
                                  delay: const Duration(milliseconds: 600),
                                  child: Container(
                                    width: double.infinity,
                                    constraints:
                                        const BoxConstraints(maxWidth: 600),
                                    margin: const EdgeInsets.only(bottom: 20),
                                    child: _loading
                                        ? const Center(
                                            child: CircularProgressIndicator(
                                                color: Color(0xFF00BD10)))
                                        : (isWide
                                            ? Row(
                                                children: [
                                                  Expanded(
                                                    child: _buildButton(
                                                      label: _signInLabel,
                                                      color: const Color(
                                                          0xFF5588AA),
                                                      onPressed:
                                                          _lockoutEndTime !=
                                                                  null
                                                              ? null
                                                              : _signIn,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: _buildButton(
                                                      label: 'NEW USER SETUP',
                                                      color: const Color(
                                                          0xFF00BD10),
                                                      onPressed:
                                                          _openRequestAccess,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Column(
                                                children: [
                                                  _buildButton(
                                                    label: _signInLabel,
                                                    color:
                                                        const Color(0xFF5588AA),
                                                    onPressed:
                                                        _lockoutEndTime != null
                                                            ? null
                                                            : _signIn,
                                                  ),
                                                  const SizedBox(height: 14),
                                                  _buildButton(
                                                    label: 'NEW USER SETUP',
                                                    color:
                                                        const Color(0xFF00BD10),
                                                    onPressed:
                                                        _openRequestAccess,
                                                  ),
                                                ],
                                              )),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: color.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    String hint = '',
    bool isPassword = false,
    TextInputAction action = TextInputAction.done,
    Function(String)? onSubmitted,
  }) {
    return SizedBox(
      height: 58,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF5B6474).withValues(alpha: 0.28),
              const Color(0xFF303747).withValues(alpha: 0.22),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: isPassword ? _obscure : false,
          textInputAction: action,
          onSubmitted: onSubmitted,
          onTapOutside: (_) => focusNode.unfocus(),
          enableInteractiveSelection: true,
          autocorrect: !isPassword,
          enableSuggestions: !isPassword,
          cursorColor: Colors.white,
          textAlignVertical: TextAlignVertical.center,
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontSize: 16,
            letterSpacing: 0.2,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.transparent,
            hintText: hint.isEmpty ? null : hint,
            hintStyle: GoogleFonts.manrope(
              color: Colors.white38,
              fontSize: 14,
              letterSpacing: 0.2,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white70,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
          ),
        ),
      ),
    );
  }
}
