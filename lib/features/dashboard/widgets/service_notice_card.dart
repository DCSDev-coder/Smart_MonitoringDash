import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dashboard_typography.dart';
import '../../../core/theme/app_theme.dart';

class ServiceNoticeCard extends StatelessWidget {
  final DateTime? lastService;
  final int cycleDays;
  final VoidCallback onTap;

  const ServiceNoticeCard({
    super.key,
    required this.lastService,
    required this.cycleDays,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final ls = lastService;
    final daysSince = ls == null ? null : now.difference(ls).inDays;
    final daysLeft = daysSince == null ? null : (cycleDays - daysSince);
    final clampedLeft = daysLeft?.clamp(0, cycleDays);

    final expected = lastService?.add(Duration(days: cycleDays));
    final fmt = DateFormat('d MMMM yyyy');

    final ringProgress = ((clampedLeft ?? 0) / cycleDays).clamp(0.0, 1.0);
    final ringText = clampedLeft?.toString() ?? '--';
    const ringA = Color(0xFFFF8A1F); // orange
    const ringB = Color(0xFF2D7DFF); // blue

    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, outerConstraints) {
              final isBounded = outerConstraints.maxHeight != double.infinity;
              
              Widget gaugeWidget = LayoutBuilder(
                builder: (context, constraints) {
                  // If bounded, it will dynamically fill space. If unbounded, we cap it nicely.
                  final maxAvailableH = constraints.maxHeight == double.infinity ? 180.0 : constraints.maxHeight;
                  final size = min(constraints.maxWidth, maxAvailableH);
                  
                  return SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: ringProgress),
                            duration: const Duration(milliseconds: 1600),
                            curve: Curves.easeOutCubic,
                            builder: (context, v, _) => _RingGauge(
                              progress: v,
                              glowA: ringA,
                              glowB: ringB,
                              strokeWidth: max(12.0, size * 0.08),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ringText,
                              style: bitcount(
                                context,
                                fontSize: max(24.0, size * 0.25),
                                color: Theme.of(context).brightness == Brightness.light ? AppTheme.lightTextPrimary : Colors.white,
                              ),
                            ),
                            Text(
                              'DAYS',
                              style: bitcount(
                                context,
                                fontSize: max(10.0, size * 0.08),
                                color: (Theme.of(context).brightness == Brightness.light ? AppTheme.lightTextSecondary : Colors.white).withValues(alpha: 0.65),
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );

              return Column(
                mainAxisSize: isBounded ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: isBounded ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
                children: [
                  Text(
                    'Next Scheduled Maintenance',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light ? AppTheme.lightTextPrimary : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (isBounded) ...[
                    const SizedBox(height: 16),
                    Expanded(child: gaugeWidget),
                    const SizedBox(height: 16),
                  ] else ...[
                    const SizedBox(height: 24),
                    gaugeWidget,
                    const SizedBox(height: 24),
                  ],
                  Divider(
                    color: Theme.of(context).brightness == Brightness.light ? AppTheme.lightStroke.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
                  ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'LAST SERVICE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.light ? AppTheme.lightTextSecondary : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          lastService == null ? '--' : fmt.format(lastService!),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.light ? AppTheme.lightTextPrimary : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'EXPECTED SERVICE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.light ? AppTheme.lightTextSecondary : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          expected == null ? '--' : fmt.format(expected),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.light ? AppTheme.lightTextPrimary : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  ),
);
  }
}

class _RingGauge extends StatefulWidget {
  final double progress;
  final Color glowA;
  final Color glowB;
  final double strokeWidth;

  const _RingGauge({
    required this.progress,
    required this.glowA,
    required this.glowB,
    required this.strokeWidth,
  });

  @override
  State<_RingGauge> createState() => _RingGaugeState();
}

class _RingGaugeState extends State<_RingGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _RingGaugePainter(
          progress: widget.progress,
          glowA: widget.glowA,
          glowB: widget.glowB,
          strokeWidth: widget.strokeWidth,
          rotation: _controller.value,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RingGaugePainter extends CustomPainter {
  final double progress;
  final Color glowA;
  final Color glowB;
  final double strokeWidth;
  final double rotation;

  _RingGaugePainter({
    required this.progress,
    required this.glowA,
    required this.glowB,
    required this.strokeWidth,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - strokeWidth / 2;
    if (!radius.isFinite || radius <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawArc(rect, -pi / 2, 2 * pi, false, basePaint);

    final sweep = 2 * pi * progress.clamp(0.0, 1.0);
    if (sweep <= 0) return;

    // Triple-layer glow (same vibe as PUE gauge)
    final glowMid = Color.lerp(glowA, glowB, 0.5)!;
    final ambientGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 18
      ..strokeCap = StrokeCap.round
      ..color = glowMid.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
    canvas.drawArc(rect, -pi / 2, sweep, false, ambientGlow);

    final haloGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 12
      ..strokeCap = StrokeCap.round
      ..color = glowMid.withValues(alpha: 0.34)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawArc(rect, -pi / 2, sweep, false, haloGlow);

    final coreGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 6
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(rect, -pi / 2, sweep, false, coreGlow);

    final progPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    progPaint.shader = SweepGradient(
      colors: [
        glowA.withValues(alpha: 0.82),
        glowA,
        glowB,
        glowB.withValues(alpha: 0.82),
        glowA.withValues(alpha: 0.82),
      ],
      stops: const [0.0, 0.28, 0.52, 0.76, 1.0],
      transform: GradientRotation(rotation * 2 * pi),
    ).createShader(rect);
    canvas.drawArc(rect, -pi / 2, sweep, false, progPaint);

    final endAngle = (-pi / 2) + sweep;
    final end = Offset(
      center.dx + radius * cos(endAngle),
      center.dy + radius * sin(endAngle),
    );
    final sparkGlow = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(end, 7, sparkGlow);
    canvas.drawCircle(end, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RingGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.glowA != glowA ||
        oldDelegate.glowB != glowB ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.rotation != rotation;
  }
}
