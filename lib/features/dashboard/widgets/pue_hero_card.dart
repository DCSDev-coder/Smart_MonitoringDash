import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/skeleton.dart';
import 'dashboard_typography.dart';

class PueHeroCard extends StatelessWidget {
  final double pue;
  final String? pueStatus; // ok | unavailable | error | down
  final double? totalEnergyKwh;
  final double? itEnergyKwh;
  final bool loading;

  const PueHeroCard({
    super.key,
    required this.pue,
    this.pueStatus,
    required this.totalEnergyKwh,
    required this.itEnergyKwh,
    required this.loading,
  });

  static const Color _idealGreen = Color.fromARGB(255, 0, 161, 116);

  Color _lightModeGaugeColor(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withSaturation((hsl.saturation + 0.10).clamp(0.0, 1.0))
        .withLightness((hsl.lightness * 0.68).clamp(0.20, 0.42))
        .toColor();
  }

  Color _lightModeCardTint(Color base) {
    return base;
  }

  double _pueProgress(double pue) {
    if (pue <= 0) {
      return 0.0;
    }
    if (pue <= 1.0) {
      return 0.98;
    }
    if (pue <= 1.5) {
      final t = (pue - 1.0) / 0.5;
      return (0.98 + ((0.58 - 0.98) * t)).clamp(0.58, 0.98);
    }
    if (pue <= 2.0) {
      final t = (pue - 1.5) / 0.5;
      return (0.58 + ((0.34 - 0.58) * t)).clamp(0.34, 0.58);
    }
    if (pue <= 3.0) {
      final t = (pue - 2.0) / 1.0;
      return (0.34 + ((0.24 - 0.34) * t)).clamp(0.24, 0.34);
    }
    return 0.24;
  }

  ({String label, Color color}) _pueStatus(double pue) {
    final status = (pueStatus ?? '').trim().toLowerCase();
    if (status == 'unavailable' || status == 'down') {
      return (label: 'DOWN', color: const Color(0xFF8A94A6));
    }
    // Heuristic buckets aligned with the copy in the info dialog:
    // IDEAL ~ near 1.0, AVERAGE ~ around 1.5, POOR ~ 2.0+.
    if (pue <= 0) {
      return (label: 'DOWN', color: const Color(0xFF8A94A6));
    }
    if (pue <= 1.2) {
      return (label: 'IDEAL', color: _idealGreen);
    }
    if (pue < 2.0) {
      return (label: 'AVERAGE', color: const Color(0xFFFF8A00));
    }
    return (label: 'POOR', color: const Color(0xFFFF3B30));
  }

  void _showPueInfo(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    showDialog(
      context: context,
      builder: (ctx) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PUE EXPLAINED',
                      style: bitcount(
                        context,
                        fontSize: 16,
                        color: AppTheme.accentGreen,
                        letterSpacing: 2,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: onSurface),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Power Usage Effectiveness (PUE) measures how efficiently a data center uses energy.',
                          style: TextStyle(
                              color: onSurface, fontSize: 14, height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        _infoRow(
                            context,
                            '1.0',
                            'IDEAL',
                            'Perfect efficiency. All power goes to IT.',
                            AppTheme.accentGreen),
                        const SizedBox(height: 12),
                        _infoRow(
                            context,
                            '1.5',
                            'AVERAGE',
                            'Moderate efficiency. Some power is used for cooling.',
                            Colors.orange),
                        const SizedBox(height: 12),
                        _infoRow(
                            context,
                            '2.0+',
                            'POOR',
                            'High energy waste. Most power goes to overhead.',
                            Colors.redAccent),
                        const SizedBox(height: 20),
                        Text(
                          'Your gauge is FULL when PUE is near 1.0, showing maximum green efficiency.',
                          style: TextStyle(
                            color: onSurface.withValues(alpha: 0.70),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _infoRow(BuildContext context, String val, String label, String desc,
      Color color) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 45,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            val,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1)),
              Text(
                desc,
                style: TextStyle(
                  color: onSurface.withValues(alpha: 0.70),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    final hasPue = !loading && pue > 0;
    final status = _pueStatus(hasPue ? pue : 0);
    final pueText = hasPue ? pue.toStringAsFixed(2) : '--';
    final totalText =
        totalEnergyKwh == null ? '--' : totalEnergyKwh!.toStringAsFixed(2);
    final itText =
        itEnergyKwh == null ? '--' : itEnergyKwh!.toStringAsFixed(2);

    final gaugeColor =
        isLight ? _lightModeGaugeColor(status.color) : status.color;
    final cardTint = isLight ? _lightModeCardTint(status.color) : null;

    return Card(
      color: cardTint,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, c) {
              const energyBarHeight = 88.0;
              const gap = 8.0;
              final maxH = c.maxHeight.isFinite ? c.maxHeight : 360.0;
              final gaugeH = (maxH - energyBarHeight - gap).clamp(200.0, 340.0);
              final gaugeScale = (gaugeH / 300.0).clamp(0.85, 1.15);

              final valueSize = 68.0 * gaugeScale;
              final labelSize = 20.0 * gaugeScale;

              if (loading) {
                final gaugeW = c.maxWidth.isFinite ? c.maxWidth : 360.0;
                final blobSize = min(gaugeW, gaugeH) * 0.86;
                return Column(
                  children: [
                    SizedBox(
                      height: gaugeH,
                      child: Center(
                        child: Skeleton(
                          width: blobSize,
                          height: blobSize * 0.62,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: gap),
                    SizedBox(
                      height: energyBarHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isLight
                              ? const Color(0xFF0B56D6)
                              : const Color(0xFF2A2A2A).withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: const Row(
                          children: [
                            Expanded(
                              child: Skeleton(
                                height: 12,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8)),
                              ),
                            ),
                            SizedBox(width: 16),
                            Skeleton(
                              width: 72,
                              height: 14,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  SizedBox(
                    height: gaugeH,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: TweenAnimationBuilder<double>(
                            tween:
                                Tween<double>(begin: 0, end: _pueProgress(pue)),
                            duration: const Duration(milliseconds: 1800),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => _PueHeroGauge(
                              progress: value,
                              glowColor: gaugeColor,
                              isLight: isLight,
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(0, 25 * gaugeScale),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                pueText,
                                style: hasPue
                                    ? bitcount(
                                        context,
                                        fontSize: valueSize,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      )
                                    : TextStyle(
                                        fontSize: valueSize,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        height: 1.0,
                                      ),
                              ),
                              SizedBox(height: 8 * gaugeScale),
                              Text(
                                'PUE',
                                style: bitcount(
                                  context,
                                  fontSize: labelSize,
                                  color: isLight
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : status.color,
                                  letterSpacing: 6,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (!hasPue)
                                Text(
                                  'DOWN',
                                  style: TextStyle(
                                    color: isLight
                                        ? Colors.white.withValues(alpha: 0.8)
                                        : Colors.white.withValues(alpha: 0.75),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: gap),
                  Container(
                    decoration: BoxDecoration(
                      color: isLight
                          ? gaugeColor
                          : const Color(0xFF0B0F14).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(18),
                      border: isLight
                          ? Border.all(color: Colors.black.withValues(alpha: 0.05))
                          : Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Monthly Energy Consumption',
                                    style: TextStyle(
                                      color: isLight
                                          ? Colors.white.withValues(alpha: 0.95)
                                          : Colors.white.withValues(alpha: 0.65),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '$totalText kWh',
                                  style: TextStyle(
                                    color: isLight ? Colors.white : Colors.white.withValues(alpha: 0.8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            Divider(
                              height: 24,
                              thickness: 1,
                              color: isLight
                                  ? Colors.white.withValues(alpha: 0.20)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'IT Energy Consumption',
                                    style: TextStyle(
                                      color: isLight
                                          ? Colors.white.withValues(alpha: 0.95)
                                          : Colors.white.withValues(alpha: 0.65),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '$itText kWh',
                                  style: TextStyle(
                                    color: isLight ? Colors.white : Colors.white.withValues(alpha: 0.8),
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
              );
            },
          ),
          Positioned(
            top: 4,
            right: 0,
            child: IconButton(
              icon: Icon(
                Icons.info_outline_rounded,
                color: Colors.white.withValues(alpha: 0.5),
                size: 20,
              ),
              onPressed: () => _showPueInfo(context),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _PueHeroGauge extends StatefulWidget {
  final double progress;
  final Color glowColor;
  final bool isLight;

  const _PueHeroGauge({
    required this.progress,
    required this.glowColor,
    required this.isLight,
  });

  @override
  State<_PueHeroGauge> createState() => _PueHeroGaugeStateV2();
}

class _PueHeroGaugeStateV2 extends State<_PueHeroGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _animController.repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return CustomPaint(
          painter: _PueHeroGaugePainter(
            progress: widget.progress.clamp(0.0, 1.0),
            glowColor: widget.glowColor,
            isLight: widget.isLight,
            rotation: _animController.value,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _PueHeroGaugePainter extends CustomPainter {
  final double progress;
  final Color glowColor;
  final bool isLight;
  final double rotation;

  _PueHeroGaugePainter({
    required this.progress,
    required this.glowColor,
    required this.isLight,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;
    final center = Offset(size.width / 2, size.height * 0.60);
    final radius = min(size.width, size.height) * 0.95;
    if (!radius.isFinite || radius <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final start = _degToRad(158);
    final sweep = _degToRad(225);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 38
      ..strokeCap = StrokeCap.round
      ..color = isLight
          ? const Color(0xFF2A3240).withValues(alpha: 0.28)
          : const Color(0xFF4A4A4A).withValues(alpha: 0.38);
    canvas.drawArc(rect, start, sweep, false, trackPaint);

    final prog = sweep * progress.clamp(0.0, 1.0);

    if (prog <= 0) {
      final shadow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 56
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF000000).withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
      canvas.drawArc(rect, start, sweep, false, shadow);

      final ghostRing = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 38
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFBDBDBD).withValues(alpha: 0.22);
      canvas.drawArc(rect, start, sweep, false, ghostRing);
    }

    if (prog > 0) {
      final highlightColor = Color.lerp(
            glowColor,
            Colors.white,
            isLight
                ? (progress <= 0.34 ? 0.10 : 0.22)
                : (progress <= 0.34 ? 0.18 : 0.45),
          ) ??
          Colors.white;
      final edgeColor = isLight
          ? (Color.lerp(glowColor, Colors.black, 0.18) ?? glowColor)
          : glowColor;

      final ambientGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 52
        ..strokeCap = StrokeCap.round
        ..color = glowColor.withValues(
          alpha: isLight
              ? (progress <= 0.34 ? 0.12 : 0.10)
              : (progress <= 0.34 ? 0.24 : 0.18),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
      canvas.drawArc(rect, start, prog, false, ambientGlow);

      final haloGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 44
        ..strokeCap = StrokeCap.round
        ..color = glowColor.withValues(
          alpha: isLight
              ? (progress <= 0.34 ? 0.26 : 0.22)
              : (progress <= 0.34 ? 0.44 : 0.35),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawArc(rect, start, prog, false, haloGlow);

      final coreGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 40
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: isLight ? 0.12 : 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawArc(rect, start, prog, false, coreGlow);

      final progPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 38
        ..strokeCap = StrokeCap.round;

      progPaint.shader = SweepGradient(
        colors: [
          edgeColor.withValues(alpha: 0.95),
          glowColor,
          highlightColor,
          glowColor,
          edgeColor.withValues(alpha: 0.95),
        ],
        stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
        transform: GradientRotation(rotation * 2 * pi),
      ).createShader(rect);

      canvas.drawArc(rect, start, prog, false, progPaint);
    }

    final capAngle = start + (prog > 0 ? prog : 0.0);
    final cap = Offset(
      center.dx + radius * cos(capAngle),
      center.dy + radius * sin(capAngle),
    );
    final capAlpha = prog > 0 ? 0.7 : 0.18;
    final sparkGlow = Paint()
      ..color = Colors.white.withValues(alpha: capAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(cap, 10, sparkGlow);
    canvas.drawCircle(
      cap,
      6,
      Paint()..color = Colors.white.withValues(alpha: prog > 0 ? 1.0 : 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant _PueHeroGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.isLight != isLight ||
        oldDelegate.rotation != rotation;
  }

  double _degToRad(double deg) => deg * pi / 180.0;
}
