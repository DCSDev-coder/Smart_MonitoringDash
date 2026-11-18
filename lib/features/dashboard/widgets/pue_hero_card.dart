import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../shared/widgets/skeleton.dart';
import 'dashboard_typography.dart';
import 'pue_history_dialog.dart';

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

  double _pueProgress(double pue) {
    if (pue <= 0) return 0.0;
    if (pue <= 1.0) return 0.98;
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
    if (pueStatus == 'down' ||
        pueStatus == 'unavailable' ||
        pueStatus == 'error') {
      return (label: 'DOWN', color: const Color(0xFF8A94A6));
    }

    if (pue <= 0) {
      return (label: 'DOWN', color: const Color(0xFF8A94A6));
    }
    if (pue <= 1.2) {
      return (label: 'Optimal Range', color: _idealGreen);
    }
    if (pue < 2.0) {
      return (label: 'Average Range', color: const Color(0xFFFF8A00));
    }
    return (label: 'High Usage', color: const Color(0xFFFF4D4F));
  }

  void _showPueInfo(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      barrierDismissible: true,
      barrierLabel: 'PUE Info',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: 8,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
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
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.primary,
                              letterSpacing: 2.5,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: onSurface.withValues(alpha: 0.05),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.close_rounded, color: onSurface, size: 20),
                              onPressed: () => Navigator.pop(ctx),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Power Usage Effectiveness (PUE) measures how efficiently a data center uses energy.',
                                style: TextStyle(
                                    color: onSurface, fontSize: 14, height: 1.5),
                              ),
                              const SizedBox(height: 28),
                              _infoRow(
                                  context,
                                  '1.0',
                                  'IDEAL',
                                  'Perfect efficiency. All power goes to IT.',
                                  Theme.of(context).colorScheme.primary),
                              const SizedBox(height: 20),
                              _infoRow(
                                  context,
                                  '1.5',
                                  'AVERAGE',
                                  'Moderate efficiency. Some power is used for cooling.',
                                  Colors.orange),
                              const SizedBox(height: 20),
                              _infoRow(
                                  context,
                                  '2.0+',
                                  'POOR',
                                  'High energy waste. Most power goes to overhead.',
                                  Colors.redAccent),
                              const SizedBox(height: 32),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.info_outline_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        'Your gauge is FULL when PUE is near 1.0, showing maximum green efficiency.',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontSize: 13,
                                          fontStyle: FontStyle.italic,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
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
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12 * anim1.value, sigmaY: 12 * anim1.value),
          child: Transform.scale(
            scale: 0.8 + (0.2 * curve.value),
            child: FadeTransition(
              opacity: anim1,
              child: child,
            ),
          ),
        );
      },
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

    final hasPue = pue > 0;
    final status = _pueStatus(hasPue ? pue : 0);

    final pueText = hasPue ? pue.toStringAsFixed(2) : '--';
    final totalText =
        totalEnergyKwh == null ? '--' : totalEnergyKwh!.toStringAsFixed(2);
    final itText =
        itEnergyKwh == null ? '--' : itEnergyKwh!.toStringAsFixed(2);

    if (loading && pue <= 0) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: isLight ? Colors.white : const Color(0xFF101829),
          border: Border.all(
            color: isLight
                ? const Color(0xFFD5E2F2)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(height: 28, width: 180, borderRadius: BorderRadius.all(Radius.circular(8))),
            SizedBox(height: 22),
            Skeleton(height: 110, borderRadius: BorderRadius.all(Radius.circular(18))),
            SizedBox(height: 18),
            Skeleton(height: 76, borderRadius: BorderRadius.all(Radius.circular(18))),
          ],
        ),
      );
    }

    final textPrimary = isLight ? const Color(0xFF0F172A) : Colors.white;
    final textSecondary =
        isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.68);
    final gaugeColor =
        isLight ? _lightModeGaugeColor(status.color) : status.color;

    final double? overheadKwh = (totalEnergyKwh != null && itEnergyKwh != null)
        ? (totalEnergyKwh! - itEnergyKwh!).clamp(0.0, double.infinity)
        : null;
    final String overheadText =
        overheadKwh == null ? '--' : overheadKwh.toStringAsFixed(2);
    final double itRatio =
        (totalEnergyKwh != null && totalEnergyKwh! > 0 && itEnergyKwh != null)
            ? (itEnergyKwh! / totalEnergyKwh!).clamp(0.0, 1.0)
            : 0.0;
    final int itPct = (itRatio * 100).round();
    final Color itBlue =
        isLight ? const Color(0xFF0095E8) : const Color(0xFF38BDF8);
    final Color dividerColor = isLight
        ? const Color(0xFFE2E8F0)
        : Colors.white.withValues(alpha: 0.08);

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Power Efficiency',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Live facility PUE & metered consumption',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => showPueHistoryDialog(context),
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.history_rounded,
                    color: textSecondary.withValues(alpha: 0.8),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _showPueInfo(context),
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: textSecondary.withValues(alpha: 0.8),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => showPueHistoryDialog(context),
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: _pueProgress(pue)),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: _PueHeroGauge(
                              progress: value,
                              glowColor: gaugeColor,
                              isLight: isLight,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  pueText,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 44,
                                    fontWeight: FontWeight.w800,
                                    height: 1.0,
                                    letterSpacing: -1.4,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'PUE · ',
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      TextSpan(
                                        text: status.label,
                                        style: TextStyle(
                                          color: isLight
                                              ? status.color
                                              : (Color.lerp(status.color,
                                                      Colors.white, 0.2) ??
                                                  status.color),
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: dividerColor),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Energy',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: totalText,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          TextSpan(
                            text: '  kWh',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'IT Load · $itPct%',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: itText,
                            style: TextStyle(
                              color: itBlue,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          TextSpan(
                            text: '  kWh',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cooling & facility overhead',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: overheadText,
                      style: TextStyle(
                        color: textSecondary.withValues(
                            alpha: isLight ? 0.95 : 0.85),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    TextSpan(
                      text: ' kWh',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
    final center = Offset(size.width * 0.50, size.height * 0.56);
    final radius = min(size.width * 0.42, size.height * 0.45);
    if (!radius.isFinite || radius <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const double strokeW = 14;
    const double start = 148 * pi / 180.0;
    const double sweep = 244 * pi / 180.0;
    final double prog = sweep * progress.clamp(0.0, 1.0);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..color = isLight ? const Color(0xFFE2E8F0) : const Color(0xFF232834);
    canvas.drawArc(rect, start, sweep, false, trackPaint);

    if (prog > 0) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW + 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = glowColor.withValues(alpha: isLight ? 0.25 : 0.42);
      canvas.drawArc(rect, start, prog, false, glowPaint);

      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round
        ..color = glowColor;
      canvas.drawArc(rect, start, prog, false, arcPaint);

      final capAngle = start + prog;
      final cap = Offset(
        center.dx + radius * cos(capAngle),
        center.dy + radius * sin(capAngle),
      );
      canvas.drawCircle(cap, 4.0, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _PueHeroGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.isLight != isLight ||
        oldDelegate.rotation != rotation;
  }
}
