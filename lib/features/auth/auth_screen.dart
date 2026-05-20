import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/network/api_service.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/auth/remember_me_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_log.dart';

import '../../shared/widgets/animated_dcs_logo.dart';
import '../../shared/widgets/fade_in_slide.dart';
import '../../shared/utils/global_video_background.dart';
import 'register_info_screen.dart';

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

  TextStyle get _authFieldLabelStyle => GoogleFonts.manrope(
        color: Colors.white70,
        fontSize: 16,
        letterSpacing: 0.4,
      );

  void _goToIntro() {
    var found = false;
    Navigator.of(context).popUntil((route) {
      if (route.settings.name == '/welcome') {
        found = true;
        return true;
      }
      return false;
    });
    if (!found) {
      Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (r) => false);
    }
  }

  @override
  void initState() {
    super.initState();
    GlobalVideoBackground.auth.player?.play();
    _tryAutoLogin();
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
      final authRes = await CpanelApiService.instance.authMe(token: token);
      if (authRes == null || authRes['status'] != 'success') {
        throw 'Session expired. Please sign in again.';
      }

      final sites = authRes['sites'];
      if (sites is! List || sites.isEmpty) {
        throw 'No Racks found for this account. Please contact support.';
      }

      final firstSite = sites[0] as Map<String, dynamic>;
      CpanelApiService.instance.currentSite = await CpanelApiService.instance
          .mergeCurrentMemberPermissions(Map<String, dynamic>.from(firstSite));
      await PushNotificationService.instance.syncTokenWithBackendIfPossible();

      final targetIp = CpanelApiService.instance.currentSite?['open_ip'];
      final siteUser =
          CpanelApiService.instance.currentSite?['site_user'] ?? 'admin';
      final sitePass =
          (CpanelApiService.instance.currentSite?['site_pass'] ?? '').toString();
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

      final ok = await ApiService.instance.login(
        siteUser,
        sitePass,
        ip: targetIp,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (ok) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        throw 'Connection to Rack failed at $targetIp. Verify your phone is on the Office Wi-Fi and that the Rack login matches.';
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString()), backgroundColor: AppTheme.statusError),
      );
      if (isAuto) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter your username and password.')),
      );
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
      CpanelApiService.instance.currentSite = await CpanelApiService.instance
          .mergeCurrentMemberPermissions(Map<String, dynamic>.from(firstSite));
      await PushNotificationService.instance.syncTokenWithBackendIfPossible();

      final targetIp = CpanelApiService.instance.currentSite?['open_ip'];
      final siteUser =
          CpanelApiService.instance.currentSite?['site_user'] ?? 'admin';
      final sitePass =
          (CpanelApiService.instance.currentSite?['site_pass'] ?? '').toString();
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

      final ok = await ApiService.instance.login(
        siteUser,
        sitePass,
        ip: targetIp,
      );

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
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        throw 'Connection to Rack failed at $targetIp. Verify your phone is on the Office Wi-Fi and that the Rack login matches.';
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString()), backgroundColor: AppTheme.statusError),
      );
      if (isAuto) {
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
        pageBuilder: (_, __, ___) => const RegisterInfoScreen(),
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
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _goToIntro();
        },
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
                          ),
                        ),
                ),

                // 2. Dark Overlay for glassmorphism contrast
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF060B11).withValues(alpha: 0.70),
                  ),
                ),

                // Back button only on wide layouts (tablet/PC).
                if (MediaQuery.of(context).size.width >= 768)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 10,
                    child: BackButton(
                      color: Colors.white,
                      onPressed: _goToIntro,
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
                                            final isReversing = animation.status ==
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
                                          placeholderBuilder: (context, _, child) {
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
                                    constraints: const BoxConstraints(maxWidth: 560),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                      _buildAuthFieldBlock(
                                        delay: const Duration(milliseconds: 200),
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
                                        delay: const Duration(milliseconds: 400),
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
                                          delay: const Duration(milliseconds: 450),
                                          child: CheckboxListTile(
                                            value: _rememberMe,
                                            controlAffinity:
                                                ListTileControlAffinity.leading,
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            activeColor: const Color(0xFF00BD10),
                                            checkColor: Colors.white,
                                            side: const BorderSide(
                                                color: Colors.white54),
                                            title: Text(
                                              'Remember Me',
                                              style: GoogleFonts.manrope(
                                                color: Colors.white70,
                                                fontSize: 14,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                            onChanged: (val) => setState(
                                                () => _rememberMe = val == true),
                                          ),
                                        ),

                                        if (kDebugMode)
                                          Builder(
                                            builder: (context) {
                                              final token = CpanelApiService
                                                  .instance
                                                  .getAuthTokenInMemory();
                                              if (token == null ||
                                                  token.isEmpty) {
                                                return const SizedBox.shrink();
                                              }
                                              final prefix =
                                                  token.length <= 16
                                                      ? token
                                                      : token.substring(0, 16);
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.only(top: 8),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Portal token: $prefix… (${token.length})',
                                                        style: GoogleFonts.manrope(
                                                          color: Colors.white54,
                                                          fontSize: 12,
                                                        ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () async {
                                                        await Clipboard.setData(
                                                          ClipboardData(
                                                              text: token),
                                                        );
                                                        if (!context.mounted) {
                                                          return;
                                                        }
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                                'Portal token copied to clipboard.'),
                                                          ),
                                                        );
                                                      },
                                                      child: const Text('Copy'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
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
                                      constraints: const BoxConstraints(maxWidth: 600),
                                      margin: const EdgeInsets.only(bottom: 20),
                                      child: _loading
                                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00BD10)))
                                          : (isWide
                                              ? Row(
                                                  children: [
                                                    Expanded(
                                                      child: _buildButton(
                                                        label: 'SIGN IN',
                                                        color: const Color(0xFF5588AA),
                                                        onPressed: _signIn,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: _buildButton(
                                                        label: 'REQUEST ACCESS',
                                                        color: const Color(0xFF00BD10),
                                                        onPressed: _openRequestAccess,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : Column(
                                                  children: [
                                                    _buildButton(
                                                      label: 'SIGN IN',
                                                      color: const Color(0xFF5588AA),
                                                      onPressed: _signIn,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    _buildButton(
                                                      label: 'REQUEST ACCESS',
                                                      color: const Color(0xFF00BD10),
                                                      onPressed: _openRequestAccess,
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
    required VoidCallback onPressed,
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
