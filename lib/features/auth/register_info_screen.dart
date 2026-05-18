import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../shared/utils/global_video_background.dart';
import '../../shared/widgets/animated_dcs_logo.dart';
import '../../shared/widgets/fade_in_slide.dart';
import 'auth_screen.dart';

class RegisterInfoScreen extends StatefulWidget {
  const RegisterInfoScreen({super.key});

  @override
  State<RegisterInfoScreen> createState() => _RegisterInfoScreenState();
}

class _RegisterInfoScreenState extends State<RegisterInfoScreen> {
  static const _supportEmail = 'support@dcstack.my';
  bool _suppressLogoHero = false;

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

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied')),
    );
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
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
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
                                    placeholderBuilder: (context, _, __) {
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
                                'REQUEST',
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
                                    delay: const Duration(milliseconds: 220),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Email Support',
                                          style: GoogleFonts.manrope(
                                            color: Colors.white70,
                                            fontSize: 16,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        _buildGlassOutputBox(
                                          value: _supportEmail,
                                          onCopy: () => _copy(_supportEmail),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  // WhatsApp support removed per UX request.
                                ],
                              ),
                            ),
                            const Spacer(flex: 2),
                            FadeInSlide(
                              delay: const Duration(milliseconds: 650),
                              child: Container(
                                width: double.infinity,
                                constraints: const BoxConstraints(maxWidth: 600),
                                margin: const EdgeInsets.only(bottom: 20),
                                child: ElevatedButton(
                                  onPressed: _goToSignIn,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF5588AA),
                                    foregroundColor: Colors.white,
                                    elevation: 4,
                                    shadowColor:
                                        const Color(0xFF5588AA).withValues(
                                      alpha: 0.5,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                    child: Text(
                                      'SIGN IN',
                                      style: GoogleFonts.manrope(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
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

  Widget _buildGlassOutputBox({
    required String value,
    required VoidCallback onCopy,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              IconButton(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded),
                color: Colors.white70,
                tooltip: 'Copy',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
