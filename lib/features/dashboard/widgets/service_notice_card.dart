import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../../core/theme/app_theme.dart';

class ServiceNoticeCard extends StatelessWidget {
  final DateTime? lastService;
  final int cycleDays;
  final VoidCallback onTap;
  final bool calendarStyle;

  const ServiceNoticeCard({
    super.key,
    required this.lastService,
    required this.cycleDays,
    required this.onTap,
    this.calendarStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final ls = lastService;
    final daysSince = ls == null ? null : now.difference(ls).inDays;
    final daysLeft = daysSince == null ? null : (cycleDays - daysSince);

    final expected = lastService?.add(Duration(days: cycleDays));
    final fmt = DateFormat('d MMMM yyyy');
    final isOverdue = daysLeft != null && daysLeft <= 0;
    final isNear = daysLeft != null && daysLeft > 0 && daysLeft <= 30;

    // ─── CALENDAR STYLE FOR DESKTOP REDESIGN (Per User Wireframe Sketch) ───
    if (calendarStyle) {
      final isLight = Theme.of(context).brightness == Brightness.light;
      final expectedMonth = expected != null ? DateFormat('MMM').format(expected).toUpperCase() : 'FEB';
      final expectedDay = expected != null ? DateFormat('dd').format(expected) : '03';

      return GestureDetector(
        onTap: onTap,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Mini Desk Calendar Graphic
                _DeskCalendarSheet(
                  month: expectedMonth,
                  day: expectedDay,
                  isOverdue: isOverdue,
                  isNear: isNear,
                ),
                const SizedBox(width: 18),

                // 2. Scheduled Maintenance Info Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Next Scheduled Maintenance',
                              style: TextStyle(
                                color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (daysLeft != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isOverdue || isNear)
                                    ? const Color(0xFFFF3B30).withValues(alpha: 0.15)
                                    : const Color(0xFF00C08B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: (isOverdue || isNear)
                                      ? const Color(0xFFFF3B30).withValues(alpha: 0.4)
                                      : const Color(0xFF00C08B).withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                isOverdue
                                    ? 'Overdue'
                                    : (isNear ? 'Near (${daysLeft}d left)' : 'Okay (${daysLeft}d left)'),
                                style: TextStyle(
                                  color: (isOverdue || isNear)
                                      ? const Color(0xFFFF6961)
                                      : const Color(0xFF00C08B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Last Service Line
                      Row(
                        children: [
                          Text(
                            'Last Service : ',
                            style: TextStyle(
                              color: isLight ? AppTheme.lightTextSecondary : Colors.white60,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            lastService == null ? '--' : fmt.format(lastService!),
                            style: TextStyle(
                              color: isLight ? AppTheme.lightTextPrimary : Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Expected Service Line
                      Row(
                        children: [
                          Text(
                            'Expected : ',
                            style: TextStyle(
                              color: isLight ? AppTheme.lightTextSecondary : Colors.white60,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            expected == null ? '--' : fmt.format(expected),
                            style: TextStyle(
                              color: (isOverdue || isNear)
                                  ? const Color(0xFFFF6961)
                                  : (isLight ? AppTheme.lightTextPrimary : const Color(0xFF00E5FF)),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
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

    final isLight = Theme.of(context).brightness == Brightness.light;
    final textPrimary =
        isLight ? const Color(0xFF0F172A) : Colors.white;
    final textSecondary = isLight
        ? const Color(0xFF64748B)
        : Colors.white.withValues(alpha: 0.65);
    final dividerColor = isLight
        ? const Color(0xFFE2E8F0)
        : Colors.white.withValues(alpha: 0.08);
    final double ringProgress = daysLeft == null || cycleDays <= 0
        ? 0.0
        : (daysLeft / cycleDays).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isLight ? Colors.white : const Color(0xFF141820),
          border: Border.all(
            color: isLight
                ? const Color(0xFFE2E8F0)
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.04 : 0.24),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Next Scheduled Maintenance',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Update',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: textSecondary,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: CustomPaint(
                    painter: _MaintenanceRingPainter(
                      progress: ringProgress,
                      isLight: isLight,
                      isOverdue: isOverdue,
                      isNear: isNear,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            daysLeft == null
                                ? '--'
                                : (isOverdue ? '0' : '$daysLeft'),
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'DAYS',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        daysLeft == null
                            ? '--'
                            : (isOverdue
                                ? 'Service Overdue'
                                : '$daysLeft days left'),
                        style: TextStyle(
                          color: (isOverdue || isNear)
                              ? const Color(0xFFEF4444)
                              : textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$cycleDays-day service window',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Divider(height: 1, thickness: 1, color: dividerColor),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last service',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          lastService == null ? '--' : fmt.format(lastService!),
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expected service',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          expected == null ? '--' : fmt.format(expected),
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceRingPainter extends CustomPainter {
  final double progress;
  final bool isLight;
  final bool isOverdue;
  final bool isNear;

  _MaintenanceRingPainter({
    required this.progress,
    required this.isLight,
    required this.isOverdue,
    required this.isNear,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 5;
    if (radius <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const double strokeW = 7.0;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..color = isLight
          ? const Color(0xFFE2E8F0)
          : Colors.white.withValues(alpha: 0.10);
    canvas.drawArc(rect, 0, 2 * pi, false, trackPaint);

    if (progress > 0) {
      final sweep = 2 * pi * progress.clamp(0.0, 1.0);
      final Color startColor = isOverdue
          ? const Color(0xFFEF4444)
          : (isNear ? const Color(0xFFF59E0B) : const Color(0xFF0EA5E9));
      final Color endColor = isOverdue
          ? const Color(0xFFF87171)
          : (isNear ? const Color(0xFFFBBF24) : const Color(0xFF10B981));

      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW + 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
        ..color = startColor.withValues(alpha: isLight ? 0.22 : 0.36);
      canvas.drawArc(rect, -pi / 2, sweep, false, glowPaint);

      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [startColor, endColor, startColor],
          stops: const [0.0, 0.75, 1.0],
          transform: const GradientRotation(-pi / 2),
        ).createShader(rect);
      canvas.drawArc(rect, -pi / 2, sweep, false, arcPaint);

      final capAngle = -pi / 2 + sweep;
      final cap = Offset(
        center.dx + radius * cos(capAngle),
        center.dy + radius * sin(capAngle),
      );
      canvas.drawCircle(cap, 2.8, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _MaintenanceRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isLight != isLight ||
        oldDelegate.isOverdue != isOverdue ||
        oldDelegate.isNear != isNear;
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

/// Mini desk calendar sheet graphic matching the user's wireframe sketch
class _DeskCalendarSheet extends StatelessWidget {
  final String month;
  final String day;
  final bool isOverdue;
  final bool isNear;

  const _DeskCalendarSheet({
    required this.month,
    required this.day,
    this.isOverdue = false,
    this.isNear = false,
  });

  @override
  Widget build(BuildContext context) {
    final bannerColor = (isOverdue || isNear)
        ? const Color(0xFFFF3B30)
        : const Color(0xFF00C08B);

    return Container(
      width: 72,
      height: 82,
      decoration: BoxDecoration(
        color: const Color(0xFF141D27),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bannerColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: bannerColor.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Top binder rings
          Positioned(
            top: -4,
            left: 14,
            child: Container(
              width: 6,
              height: 9,
              decoration: BoxDecoration(
                color: const Color(0xFF94A3B8),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.black, width: 1),
              ),
            ),
          ),
          Positioned(
            top: -4,
            right: 14,
            child: Container(
              width: 6,
              height: 9,
              decoration: BoxDecoration(
                color: const Color(0xFF94A3B8),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.black, width: 1),
              ),
            ),
          ),

          // Main Calendar Body
          Column(
            children: [
              // Month Header Bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: bannerColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: Text(
                  month,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              // Day Number
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        day,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Mini calendar dots representing calendar dates 2 3 4 5
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          4,
                          (index) => Container(
                            width: 3.5,
                            height: 3.5,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
