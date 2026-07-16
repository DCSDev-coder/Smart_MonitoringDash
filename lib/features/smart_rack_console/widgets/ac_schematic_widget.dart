import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../models/smart_rack_console_snapshot.dart';

class AcSchematicWidget extends StatefulWidget {
  const AcSchematicWidget({
    super.key,
    required this.snapshot,
    this.showLabels = false,
  });

  final SmartRackConsoleSnapshot snapshot;
  final bool showLabels;

  @override
  State<AcSchematicWidget> createState() => _AcSchematicWidgetState();
}

class _AcSchematicWidgetState extends State<AcSchematicWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  final AcPathCache _pathCache = AcPathCache();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // Fan rotation & airflow speed
    )..repeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: RefrigerationCyclePainter(
                animationValue: _controller.value,
                snapshot: widget.snapshot,
                showLabels: widget.showLabels,
                pathCache: _pathCache,
              ),
            );
          },
        );
      },
    );
  }
}

class AcPathCache {
  Size? _lastSize;

  late Path highPath;
  late Path lowPath;
  ui.PathMetric? fullPathMetric;

  void update(Size size) {
    if (_lastSize == size) return;
    _lastSize = size;

    final double w = size.width;
    final double h = size.height;
    final Rect rect = Rect.fromLTRB(w * 0.15, h * 0.15, w * 0.85, h * 0.85);

    const double cornerRadius = 20.0;

    highPath = Path();
    highPath.moveTo(rect.center.dx, rect.top);
    highPath.lineTo(rect.right - cornerRadius, rect.top);
    highPath.quadraticBezierTo(
        rect.right, rect.top, rect.right, rect.top + cornerRadius);
    highPath.lineTo(rect.right, rect.bottom - cornerRadius);
    highPath.quadraticBezierTo(
        rect.right, rect.bottom, rect.right - cornerRadius, rect.bottom);
    highPath.lineTo(rect.center.dx, rect.bottom);

    lowPath = Path();
    lowPath.moveTo(rect.center.dx, rect.bottom);
    lowPath.lineTo(rect.left + cornerRadius, rect.bottom);
    lowPath.quadraticBezierTo(
        rect.left, rect.bottom, rect.left, rect.bottom - cornerRadius);
    lowPath.lineTo(rect.left, rect.top + cornerRadius);
    lowPath.quadraticBezierTo(
        rect.left, rect.top, rect.left + cornerRadius, rect.top);
    lowPath.lineTo(rect.center.dx, rect.top);

    final Path fullPath = Path();
    fullPath.moveTo(rect.center.dx, rect.top); // Start at top center
    fullPath.lineTo(rect.right - cornerRadius, rect.top);
    fullPath.quadraticBezierTo(
        rect.right, rect.top, rect.right, rect.top + cornerRadius);
    fullPath.lineTo(rect.right, rect.bottom - cornerRadius);
    fullPath.quadraticBezierTo(
        rect.right, rect.bottom, rect.right - cornerRadius, rect.bottom);
    fullPath.lineTo(rect.left + cornerRadius, rect.bottom);
    fullPath.quadraticBezierTo(
        rect.left, rect.bottom, rect.left, rect.bottom - cornerRadius);
    fullPath.lineTo(rect.left, rect.top + cornerRadius);
    fullPath.quadraticBezierTo(
        rect.left, rect.top, rect.left + cornerRadius, rect.top);
    fullPath.close();

    final ui.PathMetrics metrics = fullPath.computeMetrics();
    fullPathMetric =
        metrics.iterator.moveNext() ? metrics.iterator.current : null;
  }
}

class RefrigerationCyclePainter extends CustomPainter {
  RefrigerationCyclePainter({
    required this.animationValue,
    required this.snapshot,
    required this.showLabels,
    required this.pathCache,
  });

  final double animationValue;
  final SmartRackConsoleSnapshot snapshot;
  final bool showLabels;
  final AcPathCache pathCache;

  @override
  void paint(Canvas canvas, Size size) {
    pathCache.update(size);

    final double w = size.width;
    final double h = size.height;

    // We define the main rectangular loop bounds
    // Leaving room for labels on the outside
    final rect = Rect.fromLTRB(w * 0.15, h * 0.15, w * 0.85, h * 0.85);

    // 1. Draw Background Grid/Pattern (optional, subtle)
    _drawBackground(canvas, size);

    // 2. Draw Pipes (Red/Orange for High Pressure, Cyan for Low Pressure)
    _drawPipes(canvas, rect);

    // 3. Draw Flow Arrows moving along the pipes
    _drawFlowArrows(canvas, rect);

    // 4. Draw Main Components (Compressor, Condenser, Evaporator, Expansion Valve)
    _drawComponents(canvas, rect);

    // 5. Draw Sensors and Switches with Labels
    _drawSensorsAndLabels(canvas, rect);
  }

  void _drawBackground(Canvas canvas, Size size) {
    if (AppConfig.isRackConsoleBuild) {
      return;
    }
    // Subtle gradient matching the image's deep blue background
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width / 2, size.height / 2),
        size.width * 0.8,
        [
          const Color(0xFF1E3A8A).withValues(alpha: 0.2), // Dark blue center
          Colors.transparent,
        ],
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _drawPipes(Canvas canvas, Rect rect) {
    final bool lite = AppConfig.isRackConsoleBuild;
    final Paint highCore = Paint()
      ..color = const Color(0xFFFCA5A5) // Light red core
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final Paint lowCore = Paint()
      ..color = const Color(0xFF67E8F9) // Light cyan core
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    if (!lite) {
      final Paint highGlow = Paint()
        ..color = const Color(0xFFEF4444).withValues(alpha: 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(pathCache.highPath, highGlow);
    }
    canvas.drawPath(pathCache.highPath, highCore);

    if (!lite) {
      final Paint lowGlow = Paint()
        ..color = const Color(0xFF06B6D4).withValues(alpha: 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(pathCache.lowPath, lowGlow);
    }
    canvas.drawPath(pathCache.lowPath, lowCore);
  }

  void _drawFlowArrows(Canvas canvas, Rect rect) {
    final ui.PathMetric? metric = pathCache.fullPathMetric;
    if (metric == null) return;

    final double pathLength = metric.length;

    // Number of arrows
    final int arrowCount = AppConfig.isRackConsoleBuild ? 8 : 12;
    final double spacing = pathLength / arrowCount;

    final Paint arrowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < arrowCount; i++) {
      // Calculate position with animation offset
      double distance = (i * spacing + animationValue * spacing) % pathLength;

      final ui.Tangent? tangent = metric.getTangentForOffset(distance);
      if (tangent != null) {
        canvas.save();
        canvas.translate(tangent.position.dx, tangent.position.dy);
        // Angle of the tangent vector
        final double angle = math.atan2(tangent.vector.dy, tangent.vector.dx);
        canvas.rotate(angle);

        // Draw a triangle arrow head pointing right (along the tangent)
        final Path arrowHead = Path();
        arrowHead.moveTo(6, 0);
        arrowHead.lineTo(-6, 5);
        arrowHead.lineTo(-6, -5);
        arrowHead.close();

        canvas.drawPath(arrowHead, arrowPaint);
        canvas.restore();
      }
    }
  }

  void _drawComponents(Canvas canvas, Rect rect) {
    // 1. Compressor (Top Center)
    _drawCompressor(canvas, Offset(rect.center.dx, rect.top));

    // 2. Condenser (Right Center)
    _drawHeatExchanger(canvas, Offset(rect.right, rect.center.dy), 'Condenser');

    // 3. Evaporator (Left Center)
    _drawHeatExchanger(canvas, Offset(rect.left, rect.center.dy), 'Evaporator');

    // 4. Expansion Valve (Bottom Center)
    _drawExpansionValve(canvas, Offset(rect.center.dx, rect.bottom));
  }

  void _drawCompressor(Canvas canvas, Offset center) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    final Paint paint = Paint()
      ..color = const Color(0xFF3B82F6) // Bright blue
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = const Color(0xFF93C5FD) // Light blue border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // A detailed compressor shape: a central cylinder with a domed top and wider base
    final Rect baseRect =
        Rect.fromCenter(center: const Offset(0, 30), width: 60, height: 10);
    canvas.drawRRect(
        RRect.fromRectAndRadius(baseRect, const Radius.circular(2)), paint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(baseRect, const Radius.circular(2)),
        borderPaint);

    final Rect bodyRect =
        Rect.fromCenter(center: const Offset(0, 0), width: 40, height: 60);
    canvas.drawRect(bodyRect, paint);
    canvas.drawRect(bodyRect, borderPaint);

    // Domed top
    final Path dome = Path();
    dome.moveTo(-20, -30);
    dome.quadraticBezierTo(0, -50, 20, -30);
    dome.close();
    canvas.drawPath(dome, paint);
    canvas.drawPath(dome, borderPaint);

    // Internal motor detail (white block)
    final Paint detailPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawRect(
        Rect.fromCenter(center: const Offset(0, -20), width: 20, height: 10),
        detailPaint);
    // Internal shaft
    canvas.drawRect(
        Rect.fromCenter(center: const Offset(0, 10), width: 6, height: 30),
        detailPaint);

    if (showLabels) {
      _drawText(canvas, 'Compressor', const Offset(0, 45));
    }

    canvas.restore();
  }

  void _drawHeatExchanger(Canvas canvas, Offset center, String label) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    final bool isEvap = label == 'Evaporator';
    final Paint paint = Paint()
      ..color = const Color(0xFF0EA5E9)
          .withValues(alpha: 0.6) // Cyan transparent block
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = const Color(0xFF7DD3FC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw the box
    final Rect box =
        Rect.fromCenter(center: Offset.zero, width: 80, height: 80);
    canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(8)), paint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(8)), borderPaint);

    // Draw a spinning fan inside
    const double fanRadius = 25.0;

    // Draw fan ring
    canvas.drawCircle(
        Offset.zero,
        fanRadius + 5,
        Paint()
          ..color = Colors.white24
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    // Spinning blades
    canvas.save();
    // Keep animation, but reduce the spin density on rack-console builds.
    canvas.rotate(
        animationValue * 2 * math.pi * (AppConfig.isRackConsoleBuild ? 4 : 10));
    final Paint bladePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final Path blade = Path();
      blade.moveTo(0, -2);
      blade.quadraticBezierTo(
          fanRadius * 0.5, -fanRadius * 0.8, fanRadius * 0.9, 0);
      blade.quadraticBezierTo(fanRadius * 0.5, fanRadius * 0.3, 0, 2);
      blade.close();
      canvas.drawPath(blade, bladePaint);
      canvas.rotate(math.pi / 2);
    }
    canvas.restore();

    // Central hub
    canvas.drawCircle(Offset.zero, 6, Paint()..color = Colors.white);

    // Label Text (offset differently based on left/right side)
    if (showLabels) {
      final textOffset = isEvap ? const Offset(50, 0) : const Offset(-50, 0);
      _drawText(canvas, label, textOffset,
          align: isEvap ? TextAlign.left : TextAlign.right);
    }

    canvas.restore();
  }

  void _drawExpansionValve(Canvas canvas, Offset center) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    final Paint paint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Hourglass shape (two facing triangles)
    final Path hourglass = Path();
    hourglass.moveTo(-15, -10);
    hourglass.lineTo(15, 10);
    hourglass.lineTo(15, -10);
    hourglass.lineTo(-15, 10);
    hourglass.close();

    canvas.drawPath(hourglass, paint);
    canvas.drawPath(hourglass, borderPaint);

    // Small actuator on top
    canvas.drawRect(
        Rect.fromCenter(center: const Offset(0, -12), width: 10, height: 8),
        paint);
    canvas.drawRect(
        Rect.fromCenter(center: const Offset(0, -12), width: 10, height: 8),
        borderPaint);

    if (showLabels) {
      _drawText(canvas, 'Expansion Valve Liquid Tube Ball Valve',
          const Offset(0, 25));
    }

    canvas.restore();
  }

  void _drawSensorsAndLabels(Canvas canvas, Rect rect) {
    // We draw little cyan squares along the pipes with labels

    // Low Voltage Switch (Top Left)
    _drawSensor(canvas, Offset(rect.left + rect.width * 0.25, rect.top),
        'Low Voltage Switch', const Offset(0, -25));

    // High Voltage Switch (Top Right)
    _drawSensor(canvas, Offset(rect.right - rect.width * 0.25, rect.top),
        'High Voltage Switch', const Offset(0, -25));

    // Return Air Temperature Sensor (Left, above Evaporator)
    _drawSensor(canvas, Offset(rect.left, rect.top + rect.height * 0.25),
        'Return Air Temperature Sensor', const Offset(-15, -15),
        align: TextAlign.right);

    // Supply Air Temperature Sensor (Left, below Evaporator)
    _drawSensor(canvas, Offset(rect.left, rect.bottom - rect.height * 0.25),
        'Supply Air Temperature Sensor', const Offset(-15, -15),
        align: TextAlign.right);

    // Condensing Fan Speed Control Unit (Right, above Expansion valve side)
    _drawSensor(canvas, Offset(rect.right, rect.bottom - rect.height * 0.35),
        'Condensing Fan Speed Control Unit', const Offset(15, -15),
        align: TextAlign.left);

    // High Pressure Sensor (Right, below fan speed unit)
    _drawSensor(canvas, Offset(rect.right, rect.bottom - rect.height * 0.15),
        'High Pressure Sensor', const Offset(15, -15),
        align: TextAlign.left);
  }

  void _drawSensor(
      Canvas canvas, Offset center, String label, Offset textOffset,
      {TextAlign align = TextAlign.center}) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    final Paint paint = Paint()
      ..color = const Color(0xFF60A5FA) // Light blue box
      ..style = PaintingStyle.fill;
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Small square body
    final Rect box =
        Rect.fromCenter(center: Offset.zero, width: 12, height: 12);
    canvas.drawRect(box, paint);
    canvas.drawRect(box, borderPaint);

    // Little line connecting to pipe
    canvas.drawLine(const Offset(0, 6), const Offset(0, 10), borderPaint);

    if (showLabels) {
      _drawText(canvas, label, textOffset, align: align);
    }

    canvas.restore();
  }

  void _drawText(Canvas canvas, String text, Offset center,
      {TextAlign align = TextAlign.center}) {
    final TextSpan span = TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 1)),
        ],
      ),
    );
    final TextPainter tp = TextPainter(
      text: span,
      textAlign: align,
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: 120); // Keep labels somewhat constrained

    double dx = center.dx;
    if (align == TextAlign.center) {
      dx -= tp.width / 2;
    } else if (align == TextAlign.right) {
      dx -= tp.width;
    } // if left, dx is fine

    final double dy = center.dy - tp.height / 2;

    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant RefrigerationCyclePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
