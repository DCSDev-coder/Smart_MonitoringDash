import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/animated_dcs_logo.dart';
import '../../shared/utils/global_video_background.dart';
import 'auth_screen.dart';
import 'setup_user_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _introController;
  late Animation<double> _introFade;
  late Animation<Offset> _introSlide;

  @override
  void initState() {
    super.initState();
    // Pre-warm and start the auth background video
    GlobalVideoBackground.auth.player?.play();

    // Faster intro: title + buttons appear together.
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _introFade = CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic);
    _introSlide = Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
    );

    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted) _introController.forward();
    });
  }

  @override
  void dispose() {
    _introController.dispose();
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
      child: Scaffold(
        backgroundColor: const Color(0xFF060B11), // Deep navy from prototype
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

          // 2. Dark Overlay to ensure text readability
          Positioned.fill(
            child: Container(
              color: const Color(0xFF060B11)
                  .withValues(alpha: 0.65), // Semi-transparent overlay
            ),
          ),

          // 3. Main Content
          SafeArea(
            child: LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 768;
              return CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                    // Keep the logo in a fixed \"band\" so the Hero doesn't jump
                    // when transitioning to AuthScreen.
                    const SizedBox(height: 40),
                    SizedBox(
                      height: 160,
                      child: Center(
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
                            // Drive the \"C\" rotation during the Hero flight so it
                            // starts immediately on tap.
                            final curved = CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeInOutSine,
                            );
                            final isReversing =
                                animation.status == AnimationStatus.reverse;
                            final a = flightDirection == HeroFlightDirection.pop
                                // We want progress 1->0. If the hero animation is
                                // already reversing, use it as-is; otherwise reverse it.
                                ? (isReversing
                                    ? curved
                                    : ReverseAnimation(curved))
                                // We want progress 0->1. If the hero animation is
                                // reversing for some reason, flip it back.
                                : (isReversing
                                    ? ReverseAnimation(curved)
                                    : curved);
                            return Material(
                              type: MaterialType.transparency,
                              child: RepaintBoundary(
                                child: AnimatedDcsLogo.flight(animation: a),
                              ),
                            );
                          },
                          placeholderBuilder: (context, _, child) {
                            // Keep layout stable but avoid flashing the static logo
                            // behind the Hero flight.
                            return const SizedBox(
                              width: 250,
                              height: 120,
                            );
                          },
                          child: const SizedBox(
                            height: 120,
                            child: AnimatedDcsLogo.intro(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Typography
                    SlideTransition(
                      position: _introSlide,
                      child: FadeTransition(
                        opacity: _introFade,
                        child: Column(
                          children: [
                            Text(
                              'SMART RACK',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: _getResponsiveFontSize(constraints.maxWidth, 18, 26),
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.92),
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'MONITORING',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: _getResponsiveFontSize(constraints.maxWidth, 24, 40),
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 1),

                    // Buttons
                    SlideTransition(
                      position: _introSlide,
                      child: FadeTransition(
                        opacity: _introFade,
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 600),
                          margin: const EdgeInsets.only(bottom: 20),
                          child: isWide
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: _buildButton(
                                        label: 'SIGN IN',
                                        color: const Color(0xFF5588AA),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                              transitionDuration: const Duration(
                                                  milliseconds: 1100),
                                              reverseTransitionDuration:
                                                  const Duration(
                                                      milliseconds: 1100),
                                              pageBuilder: (_, __, ___) =>
                                                  const AuthScreen(),
                                              transitionsBuilder:
                                                  (_, animation, __, child) {
                                                return FadeTransition(
                                                    opacity: animation,
                                                    child: child);
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildButton(
                                        label: 'SIGN UP',
                                        color: const Color(0xFF00BD10),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                              transitionDuration: const Duration(
                                                  milliseconds: 1100),
                                              reverseTransitionDuration:
                                                  const Duration(
                                                      milliseconds: 1100),
                                              pageBuilder: (_, __, ___) =>
                                                  const SetupUserScreen(),
                                              transitionsBuilder:
                                                  (_, animation, __, child) {
                                                return FadeTransition(
                                                    opacity: animation,
                                                    child: child);
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _buildButton(
                                      label: 'SIGN IN',
                                      color: const Color(0xFF5588AA),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          PageRouteBuilder(
                                            transitionDuration:
                                                const Duration(milliseconds: 1100),
                                            reverseTransitionDuration:
                                                const Duration(milliseconds: 1100),
                                            pageBuilder: (_, __, ___) =>
                                                const AuthScreen(),
                                            transitionsBuilder:
                                                (_, animation, __, child) {
                                              return FadeTransition(
                                                  opacity: animation,
                                                  child: child);
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    _buildButton(
                                      label: 'SIGN UP',
                                      color: const Color(0xFF00BD10),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          PageRouteBuilder(
                                            transitionDuration:
                                                const Duration(milliseconds: 1100),
                                            reverseTransitionDuration:
                                                const Duration(milliseconds: 1100),
                                            pageBuilder: (_, __, ___) =>
                                                const SetupUserScreen(),
                                            transitionsBuilder:
                                                (_, animation, __, child) {
                                              return FadeTransition(
                                                  opacity: animation,
                                                  child: child);
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
          ],
        ),
      ),
    ),
  );
}

  double _getResponsiveFontSize(double width, double minSize, double maxSize) {
    // Mimics clamp(minpx, 8vw, maxpx)
    double calculated = width * 0.08;
    if (calculated < minSize) return minSize;
    if (calculated > maxSize) return maxSize;
    return calculated;
  }

  Widget _buildButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: color.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

// ─── Custom Typewriter Widget ───────────────────────────────────────────────
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle textStyle;
  final Duration startDelay;
  final Duration typingDuration;
  final Duration? cursorDisappearsAfter;
  final bool keepCursor;
  final double cursorHeight;
  final double cursorWidth;

  const TypewriterText({
    super.key,
    required this.text,
    required this.textStyle,
    required this.startDelay,
    required this.typingDuration,
    this.cursorDisappearsAfter,
    this.keepCursor = false,
    this.cursorHeight = 32,
    this.cursorWidth = 3,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with TickerProviderStateMixin {
  late AnimationController _typeController;
  late Animation<int> _charCount;
  late AnimationController _cursorController;
  bool _showCursor = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();

    _typeController =
        AnimationController(vsync: this, duration: widget.typingDuration);
    _charCount =
        StepTween(begin: 0, end: widget.text.length).animate(_typeController);

    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat(reverse: true);

    _startSequence();
  }

  void _startSequence() async {
    await Future.delayed(widget.startDelay);
    if (!mounted) return;
    setState(() {
      _showCursor = true;
      _started = true;
    });

    await _typeController.forward();

    if (!widget.keepCursor && widget.cursorDisappearsAfter != null) {
      // Calculate remaining time for cursor to blink after typing is done
      final remainingDelay = widget.cursorDisappearsAfter! -
          widget.typingDuration -
          widget.startDelay;
      if (remainingDelay.isNegative) {
        if (mounted) setState(() => _showCursor = false);
      } else {
        await Future.delayed(remainingDelay);
        if (mounted) setState(() => _showCursor = false);
      }
    } else if (!widget.keepCursor) {
      if (mounted) setState(() => _showCursor = false);
    }
  }

  @override
  void dispose() {
    _typeController.dispose();
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      return const SizedBox.shrink(); // Hide completely before start delay
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_typeController, _cursorController]),
      builder: (context, child) {
        String visibleText = widget.text.substring(0, _charCount.value);
        bool cursorVisible = _showCursor && _cursorController.value > 0.5;

        return Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                visibleText,
                style: widget.textStyle,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
              ),
            ),
            SizedBox(
              width: widget.cursorWidth,
              height: widget.cursorHeight,
              child: ColoredBox(
                color:
                    cursorVisible ? Theme.of(context).colorScheme.primary : Colors.transparent,
              ),
            ),
          ],
        );
      },
    );
  }
}
