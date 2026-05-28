import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'dart:ui' show lerpDouble;

class FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final List<IconData> icons;
  final List<String> labels;
  final ValueChanged<int> onTap;
  final Color activeColor;
  final Color barColor;
  final Color inactiveIconColor;

  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.icons,
    required this.labels,
    required this.onTap,
    this.activeColor = const Color(0xFFFF8A00), // Defaulting to the new orange
    this.barColor = Colors.white,
    this.inactiveIconColor = const Color(0xFF888888),
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isGlass = barColor.a < 1.0;
    
    // Original Mission control multi-color palette (for Dark Mode)
    final gradientColors = [
      const Color(0xFF00C08B), // Green
      const Color(0xFF2D7DFF), // Blue
      const Color(0xFFFF8A00), // Orange
      const Color(0xFF00C08B), // Loop back to Green
    ];

    final content = SizedBox(
      height: 70,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemW = (constraints.maxWidth - 32) / icons.length;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(icons.length, (index) {
              final isSelected = index == selectedIndex;
              // Unified pop-up height
              const dyValue = -26.0;
              
              return SizedBox(
                width: itemW,
                height: 70,
                child: GestureDetector(
                  onTap: () => onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: isSelected ? dyValue : 0),
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutBack,
                        builder: (context, dy, child) {
                          return Transform.translate(
                            offset: Offset(0, dy),
                            child: child,
                          );
                        },
                        child: _NavCircle(
                          isSelected: isSelected,
                          icon: icons[index],
                          activeColor: activeColor,
                          inactiveIconColor: inactiveIconColor,
                          barColor: barColor,
                          gradientColors: gradientColors,
                          isLight: isLight,
                        ),
                      ),

                      if (isSelected)
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                labels[index],
                                style: TextStyle(
                                  color: isLight ? activeColor : const Color(0xFFFF8A00),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ); 
        },
      ),
    );

    // Unified border radius
    final borderRadius = BorderRadius.circular(40);
    final shadowDecoration = BoxDecoration(
      borderRadius: borderRadius,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isGlass ? 0.30 : 0.08),
          blurRadius: isGlass ? 28 : 20,
          offset: const Offset(0, 8),
        ),
      ],
    );


    return SizedBox(
      height: 70,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: shadowDecoration.copyWith(
                color: isGlass ? const Color(0xFF0B0F14) : barColor,
                // Border removed per user request for both modes
              ),
            ),
          ),
          Positioned.fill(child: content),
        ],
      ),
    );
  }
}

class _NavCircle extends StatefulWidget {
  final bool isSelected;
  final IconData icon;
  final Color activeColor;
  final Color inactiveIconColor;
  final Color barColor;
  final List<Color> gradientColors;
  final bool isLight;

  const _NavCircle({
    required this.isSelected,
    required this.icon,
    required this.activeColor,
    required this.inactiveIconColor,
    required this.barColor,
    required this.gradientColors,
    required this.isLight,
  });

  @override
  State<_NavCircle> createState() => _NavCircleState();
}

class _NavCircleState extends State<_NavCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.isSelected ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, tRaw, child) {
        final t = tRaw.clamp(0.0, 1.0);
        // Unified sizes
        const size = 52.0;
        final currentSize = lerpDouble(40, size, t)!;
        final iconSize = lerpDouble(24, 26, t)!;

        final glowBlur = 24 * t;
        final glowSpread = 2 * t;

        return Container(
          width: currentSize,
          height: currentSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isLight 
                ? Color.lerp(Colors.transparent, widget.activeColor, t)
                : Colors.transparent,
            boxShadow: (glowBlur <= 0.001)
                ? null
                : [
                    BoxShadow(
                      color: (widget.isLight ? widget.activeColor : const Color(0xFFFF8A00))
                          .withValues(alpha: 0.35 * t),
                      blurRadius: glowBlur,
                      spreadRadius: glowSpread,
                    ),
                  ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (t > 0.1 && !widget.isLight)
                Opacity(
                  opacity: t,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: widget.gradientColors,
                            transform: GradientRotation(_controller.value * 2 * math.pi),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Center(
                child: Icon(
                  widget.icon,
                  color: t >= 0.5 ? Colors.white : widget.inactiveIconColor,
                  size: iconSize,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
