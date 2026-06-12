import 'package:flutter/material.dart';
import 'dart:math' as math;

/// DCS logo with the "C" segment that can rotate from UP (-90deg) to RIGHT (0deg).
///
/// We keep this widget animation-driven (via an [Animation<double>]) so we can
/// hook it into the Hero flight and start rotating immediately when navigating.
class AnimatedDcsLogo extends StatelessWidget {
  /// Progress 0..1. Use this for static states (intro/login) without animation.
  final double? progress;

  /// Provide an animation (0..1) to drive rotation/offset/subtitle fade.
  final Animation<double>? animation;

  const AnimatedDcsLogo._({super.key, this.progress, this.animation})
      : assert((progress == null) != (animation == null),
            'Provide either progress or animation, not both.');

  const AnimatedDcsLogo.intro({Key? key}) : this._(key: key, progress: 0);
  const AnimatedDcsLogo.login({Key? key}) : this._(key: key, progress: 1);
  const AnimatedDcsLogo.flight({
    Key? key,
    required Animation<double> animation,
  }) : this._(key: key, animation: animation);

  @override
  Widget build(BuildContext context) {
    final anim = animation ?? AlwaysStoppedAnimation<double>(progress ?? 0);

    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        final t = anim.value.clamp(0.0, 1.0);
        final angle = (-math.pi / 2) + ((math.pi / 2) * t);
        final off = Offset.lerp(
              const Offset(10, -8),
              const Offset(3, 2),
              t,
            ) ??
            Offset.zero;

        return SizedBox(
          width: 250, // Slightly wider to accommodate offsets
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. DATA CENTER SPECIALISTS (The Text)
              // Linked directly to the controller for a smooth fade-in reveal
              Opacity(
                opacity: t,
                child: Image.asset(
                  'assets/DCS_Logo/DATA_CENTER_SPECIALISTS.png',
                ),
              ),

              // 2. D (Static)
              Image.asset('assets/DCS_Logo/D.png'),

              // 3. S (Static)
              Image.asset('assets/DCS_Logo/S.png'),

              // Registered Trademark (Static)
              Image.asset('assets/DCS_Logo/R-01 (1).png'),

              // 4. THE SPINNING "C" GROUP
              Transform.translate(
                offset: off,
                child: Transform.rotate(
                  angle: angle,
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset('assets/DCS_Logo/C.png'),
                      Image.asset('assets/DCS_Logo/GREEN_LINE.png'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
