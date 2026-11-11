import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dashboard_typography.dart';
import '../../../core/theme/app_theme.dart';

class ServiceNoticeCard extends StatelessWidget {
  final DateTime? lastService;
  final int cycleDays;
  final VoidCallback onTap;
  final bool horizontalCalendarMode;

  const ServiceNoticeCard({
    super.key,
    required this.lastService,
    required this.cycleDays,
    required this.onTap,
    this.horizontalCalendarMode = false,
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

    final isLight = Theme.of(context).brightness == Brightness.light;
    final isAlert = (clampedLeft ?? 90) <= 30;

    // Horizontal Desk Calendar Mode for Desktop Redesign
    if (horizontalCalendarMode) {
      return GestureDetector(
        onTap: onTap,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Mini Desk Calendar Sheet
                _DeskCalendarSheet(
                  month: expected != null
                      ? DateFormat('MMM').format(expected).toUpperCase()
                      : 'FEB',
                  day: expected != null ? DateFormat('dd').format(expected) : '03',
                  year: expected != null
                      ? DateFormat('yyyy').format(expected)
                      : '2027',
                  isAlert: isAlert,
                ),
                const SizedBox(width: 18),
                // 2. Schedule Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Next Scheduled Maintenance',
                            style: TextStyle(
                              color: isLight
                                  ? AppTheme.lightTextPrimary
                                  : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          // Days Left Countdown Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isAlert
                                      ? const Color(0xFFFF3B30)
                                      : const Color(0xFF00C08B))
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (isAlert
                                        ? const Color(0xFFFF3B30)
                                        : const Color(0xFF00C08B))
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              '$ringText DAYS LEFT',
                              style: TextStyle(
                                color: isAlert
                                    ? const Color(0xFFFF6961)
                                    : const Color(0xFF00C08B),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            'Last Service: ',
                            style: TextStyle(
                              color: isLight
                                  ? AppTheme.lightTextSecondary
                                  : Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            lastService == null ? '--' : fmt.format(lastService!),
                            style: TextStyle(
                              color: isLight
                                  ? AppTheme.lightTextPrimary
                                  : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Expected: ',
                            style: TextStyle(
                              color: isLight
                                  ? AppTheme.lightTextSecondary
                                  : Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            expected == null ? '--' : fmt.format(expected),
                            style: TextStyle(
                              color: isAlert
                                  ? const Color(0xFFFF6961)
                                  : const Color(0xFF00C08B),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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

class _DeskCalendarSheet extends StatelessWidget {
  final String month;
  final String day;
  final String year;
  final bool isAlert;

  const _DeskCalendarSheet({
    required this.month,
    required this.day,
    required this.year,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final accentColor =
        isAlert ? const Color(0xFFFF3B30) : const Color(0xFF00C08B);

    return Container(
      width: 66,
      height: 74,
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF141D27),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.15),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          // Spiral / Binder rings indicator & Month Banner
          Container(
            height: 22,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            alignment: Alignment.center,
            child: Text(
              month,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
          // Day number
          Expanded(
            child: Center(
              child: Text(
                day,
                style: TextStyle(
                  color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          // Year
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              year,
              style: TextStyle(
                color: (isLight
                        ? AppTheme.lightTextSecondary
                        : Colors.white)
                    .withValues(alpha: 0.4),
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
