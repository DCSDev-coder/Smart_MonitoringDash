import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/network/cpanel_api_service.dart';
import '../../core/config/app_config.dart';
import '../../core/auth/session_flow_service.dart';
import '../../core/security/app_lock_controller.dart';
import '../../core/auth/remember_me_store.dart';
import '../../core/utils/app_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/widgets/animated_dcs_logo.dart';
import '../../shared/widgets/fade_in_slide.dart';
import 'widgets/animated_auth_field.dart';
import '../../shared/utils/global_video_background.dart';
import 'setup_user_screen.dart';
import '../../shared/utils/app_toast.dart';

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
  final _userFieldKey = GlobalKey<AnimatedAuthFieldState>();
  final _passFieldKey = GlobalKey<AnimatedAuthFieldState>();
  bool _loading = false;
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

  bool get _isRackConsoleBuild => AppConfig.isRackConsoleBuild;

  bool _canEnterCurrentApp(Map<String, dynamic> site) {
    final isRackConsoleAccount =
        CpanelApiService.instance.isCurrentSiteRackConsole(site);
    return _isRackConsoleBuild ? isRackConsoleAccount : !isRackConsoleAccount;
  }

  Future<void> _rejectWrongAppMode({
    required String message,
  }) async {
    await SessionFlowService.instance.signOut();
    if (!mounted) return;
    setState(() => _loading = false);
    AppToast.showError(context, message);
  }

  @override
  void initState() {
    super.initState();
    if (!AppConfig.isRackConsoleBuild) {
      GlobalVideoBackground.auth.player?.play();
    }
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

  Future<void> _signInWithToken(
      {required String token, bool isAuto = false}) async {
    setState(() => _loading = true);
    try {
      final bootstrap =
          await SessionFlowService.instance.bootstrapFromToken(token: token);

      if (!_canEnterCurrentApp(bootstrap.site)) {
        final isRackConsoleAccount = bootstrap.isRackConsoleAccount;
        final message = _isRackConsoleBuild
            ? 'Wrong account'
            : 'This account is reserved for the Rack Console app. Please use the Rack Console installation.';
        await _rejectWrongAppMode(message: message);
        if (!mounted) return;
        if (isRackConsoleAccount) {
          Navigator.of(context).pushReplacementNamed('/welcome');
        }
        return;
      }

      final expiryStr = bootstrap.site['expiry_date'];

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

      final ok =
          await SessionFlowService.instance.connectRackSession(bootstrap.site);

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
      if (isAuto && e is SessionBootstrapInvalidException) {
        await rememberMeStore.clear();
      }
    }
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
      final bootstrap =
          await SessionFlowService.instance.bootstrapFromToken(token: token);

      if (!_canEnterCurrentApp(bootstrap.site)) {
        final message = _isRackConsoleBuild
            ? 'Wrong account'
            : 'This account is reserved for the Rack Console app. Please use the Rack Console installation.';
        await _rejectWrongAppMode(message: message);
        return;
      }

      final expiryStr = bootstrap.site['expiry_date'];

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

      final ok =
          await SessionFlowService.instance.connectRackSession(bootstrap.site);

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
      final safeMsg = AppToast.sanitizeErrorMessage(e.toString());
      final lowerMsg = safeMsg.toLowerCase();
      if (lowerMsg.contains('password') || lowerMsg.contains('credentials')) {
        _passFieldKey.currentState?.showError("");
      } else if (lowerMsg.contains('user')) {
        _userFieldKey.currentState?.showError("");
      } else {
        _userFieldKey.currentState?.showError("");
        _passFieldKey.currentState?.showError(safeMsg);
      }
      if (isAuto && e is SessionBootstrapInvalidException) {
        // Auto-login failed; don't keep retrying in a loop.
        await rememberMeStore.clear();
      }
    }
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
                                      FadeInSlide(
                                        delay: const Duration(milliseconds: 200),
                                        child: AnimatedAuthField(
                                          key: _userFieldKey,
                                          controller: _userCtrl,
                                          focusNode: _userFocus,
                                          label: 'Username',
                                          action: TextInputAction.next,
                                          onSubmitted: (_) => _passFocus.requestFocus(),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      FadeInSlide(
                                        delay: const Duration(milliseconds: 400),
                                        child: AnimatedAuthField(
                                          key: _passFieldKey,
                                          controller: _passCtrl,
                                          focusNode: _passFocus,
                                          label: 'Password',
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
                                                      label: 'SIGN UP',
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
                                                    label: 'SIGN UP',
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
    return _CustomRippleButton(
      label: label,
      color: color,
      onPressed: onPressed,
    );
  }

}

class _CustomRippleButton extends StatefulWidget {
  const _CustomRippleButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  State<_CustomRippleButton> createState() => _CustomRippleButtonState();
}

class _CustomRippleButtonState extends State<_CustomRippleButton>
    with TickerProviderStateMixin {
  Offset? _tapPos;
  AnimationController? _animCtrl;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    setState(() {
      _tapPos = details.localPosition;
    });
    _animCtrl?.dispose();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _animCtrl!.forward().then((_) {
      if (mounted) setState(() => _tapPos = null);
    });
  }

  void _handleTap() {
    if (widget.onPressed != null) widget.onPressed!();
  }

  @override
  void dispose() {
    _animCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: 0.5),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              child: Text(
                widget.label,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: Colors.white.withValues(alpha: widget.onPressed == null ? 0.5 : 1.0),
                ),
              ),
            ),
            if (_tapPos != null && _animCtrl != null)
              Positioned(
                left: _tapPos!.dx - 50,
                top: _tapPos!.dy - 50,
                child: IgnorePointer(
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 1.0, end: 0.0)
                        .animate(_animCtrl!),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.0, end: 2.6)
                          .animate(_animCtrl!),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
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
