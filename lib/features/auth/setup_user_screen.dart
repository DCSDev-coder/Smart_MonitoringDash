import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/network/cpanel_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/utils/global_video_background.dart';
import '../../shared/widgets/animated_dcs_logo.dart';
import '../../shared/widgets/fade_in_slide.dart';
import 'auth_screen.dart';
import '../../shared/utils/app_toast.dart';

class SetupUserScreen extends StatefulWidget {
  const SetupUserScreen({super.key});

  @override
  State<SetupUserScreen> createState() => _SetupUserScreenState();
}

class _SetupUserScreenState extends State<SetupUserScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _suppressLogoHero = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  TextStyle get _authFieldLabelStyle => GoogleFonts.manrope(
        color: Colors.white70,
        fontSize: 16,
        letterSpacing: 0.4,
      );

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

  void _goToSignIn() {
    setState(() => _suppressLogoHero = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 1100),
          reverseTransitionDuration: const Duration(milliseconds: 1100),
          pageBuilder: (_, __, ___) => const AuthScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (username.isEmpty || password.isEmpty) {
      AppToast.showError(context, 'Please enter both username and password.');
      return;
    }

    setState(() => _submitting = true);
    final res = await CpanelApiService.instance.setupFirstPassword(
      username: username,
      newPassword: password,
    );

    if (!mounted) return;

    final status = res?['status']?.toString();
    if (status == 'success') {
      AppToast.showSuccess(context, 'Password created successfully. You can now log in.');
      _goToSignIn();
    } else {
      setState(() => _submitting = false);
      final msg = res?['message']?.toString() ?? 'Failed to setup password.';
      AppToast.showError(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = GlobalVideoBackground.auth;
    return PopScope(
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
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF060B11).withValues(alpha: 0.70),
                ),
              ),

              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 768;
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: IntrinsicHeight(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                const SizedBox(height: 40),
                                SizedBox(
                                  height: 160,
                                  child: Center(
                                    child: HeroMode(
                                      enabled: !_suppressLogoHero,
                                      child: Hero(
                                        tag: 'logo',
                                        transitionOnUserGestures: true,
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
                                    'NEW USER SETUP',
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
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 560),
                                  child: FadeInSlide(
                                    delay: const Duration(milliseconds: 220),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        _buildAuthFieldBlock(
                                          delay: const Duration(milliseconds: 200),
                                          label: 'Assigned Username :',
                                          child: _buildGlassTextField(
                                            controller: _usernameCtrl,
                                            focusNode: _usernameFocus,
                                            enabled: !_submitting,
                                            action: TextInputAction.next,
                                            onSubmitted: (_) =>
                                                _passwordFocus.requestFocus(),
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        _buildAuthFieldBlock(
                                          delay: const Duration(milliseconds: 400),
                                          label: 'New Password :',
                                          child: _buildGlassTextField(
                                            controller: _passwordCtrl,
                                            focusNode: _passwordFocus,
                                            enabled: !_submitting,
                                            isPassword: true,
                                            onSubmitted: (_) => _submit(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: isWide ? 72 : 52),
                                FadeInSlide(
                                  delay: const Duration(milliseconds: 650),
                                  child: Container(
                                    width: double.infinity,
                                    constraints: const BoxConstraints(maxWidth: 600),
                                    margin: const EdgeInsets.only(bottom: 20),
                                    child: isWide
                                        ? Row(
                                            children: [
                                              Expanded(
                                                child: _buildSignInButton(),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: _buildSetPasswordButton(),
                                              ),
                                            ],
                                          )
                                        : Column(
                                            children: [
                                              _buildSetPasswordButton(),
                                              const SizedBox(height: 16),
                                              _buildSignInButton(),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
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
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    bool enabled = true,
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
          enabled: enabled,
          obscureText: isPassword ? _obscurePassword : false,
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
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white70,
                    ),
                    onPressed: enabled ? () => setState(() => _obscurePassword = !_obscurePassword) : null,
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

  Widget _buildSetPasswordButton() {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentGreen,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppTheme.accentGreen.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _submitting
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                'SET PASSWORD',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
      ),
    );
  }

  Widget _buildSignInButton() {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _goToSignIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5588AA),
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: const Color(0xFF5588AA).withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(
          'SIGN IN',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}
