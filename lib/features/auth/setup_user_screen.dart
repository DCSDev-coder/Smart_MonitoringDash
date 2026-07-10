import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/network/cpanel_api_service.dart';
import '../../shared/utils/global_video_background.dart';
import '../../shared/widgets/animated_dcs_logo.dart';
import '../../shared/widgets/fade_in_slide.dart';
import 'widgets/animated_auth_field.dart';
import 'auth_screen.dart';
import '../../shared/utils/app_toast.dart';

enum SetupUserMode {
  newUser,
  resetPassword,
}

class SetupUserScreen extends StatefulWidget {
  final SetupUserMode mode;

  const SetupUserScreen({
    super.key,
    this.mode = SetupUserMode.newUser,
  });

  @override
  State<SetupUserScreen> createState() => _SetupUserScreenState();
}

class _SetupUserScreenState extends State<SetupUserScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _userFieldKey = GlobalKey<AnimatedAuthFieldState>();
  final _passFieldKey = GlobalKey<AnimatedAuthFieldState>();
  bool _submitting = false;
  bool _suppressLogoHero = false;

  bool get _isResetMode => widget.mode == SetupUserMode.resetPassword;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
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

  String _friendlySetupError(Map<String, dynamic>? res) {
    final raw = res?['message']?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return _isResetMode
          ? 'Failed to reset password.'
          : 'Failed to set up password.';
    }

    final lower = raw.toLowerCase();
    if (lower.contains('invalid json body')) {
      return _isResetMode
          ? 'The server rejected the password reset request. Please verify the username and try again.'
          : 'The server rejected the account setup request. If this account may already be activated, try signing in or use Reset Password.';
    }
    if (lower.contains('already been set') || lower.contains('already activated')) {
      return 'This account has already been activated. Please sign in or use Reset Password.';
    }
    if (lower.contains('user not found')) {
      return 'The username was not found. Please check it and try again.';
    }
    if (lower.contains('password') && lower.contains('weak')) {
      return 'Choose a stronger password and try again.';
    }

    return raw;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (username.isEmpty) {
      _userFieldKey.currentState?.showError('Please enter a username.');
    }
    if (password.isEmpty) {
      _passFieldKey.currentState?.showError(
          _isResetMode ? 'Please enter a new password.' : 'Please enter a password.');
    }
    if (username.isEmpty || password.isEmpty) return;

    setState(() => _submitting = true);
    final res = _isResetMode
        ? await CpanelApiService.instance.resetPasswordByUsername(
            username: username,
            newPassword: password,
          )
        : await CpanelApiService.instance.setupFirstPassword(
            username: username,
            newPassword: password,
          );

    if (!mounted) return;

    final status = res?['status']?.toString();
    if (status == 'success') {
      AppToast.showSuccess(
        context,
        _isResetMode
            ? 'Password reset successfully. You can now log in.'
            : 'Password created successfully. You can now log in.',
      );
      _goToSignIn();
    } else {
      setState(() => _submitting = false);
      final msg = _friendlySetupError(res);
      final lowerMsg = msg.toLowerCase();
      if (lowerMsg.contains('password') || lowerMsg.contains('weak')) {
        _passFieldKey.currentState?.showError(msg);
      } else if (lowerMsg.contains('user') || lowerMsg.contains('account')) {
        _userFieldKey.currentState?.showError(msg);
      } else {
        _userFieldKey.currentState?.showError(msg);
        _passFieldKey.currentState?.showError(msg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = GlobalVideoBackground.auth;
    return PopScope(
      canPop: false,
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
                          wakelock: false,
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
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
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
                                      child: const Hero(
                                        tag: 'logo',
                                        transitionOnUserGestures: true,
                                        child: SizedBox(
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
                                    _isResetMode
                                        ? 'RESET PASSWORD'
                                        : 'SIGN UP',
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
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      FadeInSlide(
                                        delay: const Duration(milliseconds: 200),
                                        child: AnimatedAuthField(
                                          key: _userFieldKey,
                                          controller: _usernameCtrl,
                                          focusNode: _usernameFocus,
                                          label: 'Username',
                                          action: TextInputAction.next,
                                          onSubmitted: (_) => _passwordFocus.requestFocus(),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      FadeInSlide(
                                        delay: const Duration(milliseconds: 400),
                                        child: AnimatedAuthField(
                                          key: _passFieldKey,
                                          controller: _passwordCtrl,
                                          focusNode: _passwordFocus,
                                          label: 'New Password',
                                          isPassword: true,
                                          onSubmitted: (_) => _submit(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: isWide ? 72 : 52),
                                FadeInSlide(
                                  delay: const Duration(milliseconds: 650),
                                  child: Container(
                                    width: double.infinity,
                                    constraints:
                                        const BoxConstraints(maxWidth: 600),
                                    margin: const EdgeInsets.only(bottom: 20),
                                    child: _buildSetPasswordButton(),
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
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
                    onPressed: _goToSignIn,
                    tooltip: 'Back to Sign In',
                  ),
                ),
              ),
            ],
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
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
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
                _isResetMode ? 'RESET PASSWORD' : 'SIGN UP',
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
