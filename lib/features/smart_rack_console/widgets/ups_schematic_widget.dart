import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../models/smart_rack_console_snapshot.dart';

class UpsSchematicWidget extends StatefulWidget {
  const UpsSchematicWidget({
    super.key,
    required this.snapshot,
    this.showLabels = false,
  });

  final SmartRackConsoleSnapshot snapshot;
  final bool showLabels;

  @override
  State<UpsSchematicWidget> createState() => _UpsSchematicWidgetState();
}

class _UpsSchematicWidgetState extends State<UpsSchematicWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  final UpsPathCache _pathCache = UpsPathCache();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Speed of electricity flow
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
              painter: UpsSchematicPainter(
                animationValue: _controller.value,
                pathCache: _pathCache,
                showLabels: widget.showLabels,
              ),
            );
          },
        );
      },
    );
  }
}

class UpsPathCache {
  Size? _lastSize;

  late Path bypassPath;
  late Path inputPath;
  late Path batteryPath;
  late Path dashedRepairPath;

  ui.PathMetric? bypassMetric;
  ui.PathMetric? inputMetric;

  void update(Size size) {
    if (_lastSize == size) return;
    _lastSize = size;

    final double w = size.width;
    final double h = size.height;
    final Rect b = Rect.fromLTRB(w * 0.1, h * 0.1, w * 0.9, h * 0.9);

    // 1. Repair Path (Dashed)
    final double repairY = b.top - 30;
    final Path repairPath = Path();
    repairPath.moveTo(b.left + 80, b.top + 30);
    repairPath.lineTo(b.left + 80, repairY);
    repairPath.lineTo(b.right - 40, repairY);
    repairPath.lineTo(b.right - 40, b.top + 30);

    final ui.PathMetrics metrics = repairPath.computeMetrics();
    final ui.PathMetric? metric =
        metrics.iterator.moveNext() ? metrics.iterator.current : null;
    dashedRepairPath = Path();
    if (metric != null) {
      double distance = 0;
      while (distance < metric.length) {
        dashedRepairPath.addPath(
            metric.extractPath(distance, distance + 10), Offset.zero);
        distance += 20;
      }
    }

    // 2. Bypass Path
    bypassPath = Path();
    bypassPath.moveTo(b.left, b.top + 30);
    bypassPath.lineTo(b.right, b.top + 30);

    final bypassMetrics = bypassPath.computeMetrics();
    bypassMetric = bypassMetrics.iterator.moveNext()
        ? bypassMetrics.iterator.current
        : null;

    // 3. Input Path
    inputPath = Path();
    inputPath.moveTo(b.left, b.bottom - 60);
    inputPath.lineTo(b.right - 60, b.bottom - 60);
    inputPath.lineTo(b.right - 60, b.top + 30);

    final inputMetrics = inputPath.computeMetrics();
    inputMetric =
        inputMetrics.iterator.moveNext() ? inputMetrics.iterator.current : null;

    // 4. Battery Path
    batteryPath = Path();
    batteryPath.moveTo(b.center.dx, b.bottom - 60);
    batteryPath.lineTo(b.center.dx, b.bottom - 20);
  }
}

class UpsSchematicPainter extends CustomPainter {
  UpsSchematicPainter({
    required this.animationValue,
    required this.pathCache,
    required this.showLabels,
  });

  final double animationValue;
  final UpsPathCache pathCache;
  final bool showLabels;

  @override
  void paint(Canvas canvas, Size size) {
    pathCache.update(size);

    final double w = size.width;
    final double h = size.height;
    final Rect b = Rect.fromLTRB(w * 0.1, h * 0.1, w * 0.9, h * 0.9);

    // 1. Draw Static Paths
    _drawPaths(canvas, b);

    // 2. Draw Moving Electricity Dots
    _drawElectricity(canvas, b);

    // 3. Draw Nodes (Switches, Rectifier, Inverter, Battery)
    _drawNodes(canvas, b);
  }

  void _drawPaths(Canvas canvas, Rect b) {
    // Paint for normal lines (Cyan)
    final Paint linePaint = Paint()
      ..color = const Color(0xFF06B6D4) // Cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Paint for repair line (Red/Orange)
    final Paint redPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawPath(pathCache.bypassPath, linePaint);
    canvas.drawPath(pathCache.inputPath, linePaint);
    canvas.drawPath(pathCache.batteryPath, linePaint);
    canvas.drawPath(pathCache.dashedRepairPath, redPaint);
  }

  void _drawElectricity(Canvas canvas, Rect b) {
    final Paint dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..maskFilter = AppConfig.isRackConsoleBuild
          ? null
          : const MaskFilter.blur(BlurStyle.solid, 3); // Glow effect

    _animateDotsOnPath(canvas, pathCache.bypassMetric, dotPaint, 8);
    _animateDotsOnPath(canvas, pathCache.inputMetric, dotPaint, 12);
  }

  void _animateDotsOnPath(
      Canvas canvas, ui.PathMetric? metric, Paint paint, int dotCount) {
    if (metric == null) return;

    final double length = metric.length;
    final double spacing = length / dotCount;

    for (int i = 0; i < dotCount; i++) {
      double distance = (i * spacing + animationValue * spacing) % length;
      final ui.Tangent? tangent = metric.getTangentForOffset(distance);
      if (tangent != null) {
        canvas.drawCircle(tangent.position, 4, paint);
      }
    }
  }

  void _drawNodes(Canvas canvas, Rect b) {
    // Text style
    const TextStyle textStyle = TextStyle(
        color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold);

    // Input/Output Nodes
    _drawInputNode(canvas, Offset(b.left, b.top + 30));
    _drawInputNode(canvas, Offset(b.left, b.bottom - 60));
    _drawOutputNode(canvas, Offset(b.right, b.top + 30));

    // Switches
    _drawSwitch(
        canvas, Offset(b.left + 120, b.top - 30), 'Repair Bypass Switch',
        isVertical: false);
    _drawSwitch(canvas, Offset(b.left + 100, b.top + 30), 'Bypass Switch',
        isVertical: false);
    _drawSwitch(canvas, Offset(b.left + 100, b.bottom - 60), 'Input Switch',
        isVertical: false);

    // Labels for inputs
    if (showLabels) {
      _drawLabel(
          canvas, Offset(b.left + 30, b.top + 10), 'Bypass Mains', textStyle);
      _drawLabel(canvas, Offset(b.left + 30, b.bottom - 80), 'Bypass Mains',
          textStyle);
    }

    // Components (Rectifier, Inverter, Static Switch, Battery)
    _drawStaticSwitch(canvas, Offset(b.center.dx, b.top + 30));
    _drawRectifier(canvas, Offset(b.center.dx - 50, b.bottom - 60));
    _drawInverter(canvas, Offset(b.center.dx + 50, b.bottom - 60));
    _drawBattery(canvas, Offset(b.center.dx, b.bottom - 20));
  }

  void _drawInputNode(Canvas canvas, Offset center) {
    final Paint stroke = Paint()
      ..color = const Color(0xFF93C5FD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 8, stroke);
    canvas.drawCircle(center, 3, stroke);
  }

  void _drawOutputNode(Canvas canvas, Offset center) {
    final Paint stroke = Paint()
      ..color = const Color(0xFF93C5FD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(Rect.fromCircle(center: center, radius: 8), -math.pi / 2,
        math.pi, false, stroke);
    canvas.drawLine(Offset(center.dx - 10, center.dy),
        Offset(center.dx, center.dy), stroke);
  }

  void _drawSwitch(Canvas canvas, Offset center, String label,
      {bool isVertical = false}) {
    final Paint bgPaint = Paint()
      ..color = const Color(0xFF071B3A); // match panel bg to cut the line
    final Paint borderPaint = Paint()
      ..color = const Color(0xFF93C5FD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(
        Rect.fromCenter(center: center, width: 20, height: 10), bgPaint);
    canvas.drawLine(Offset(center.dx - 10, center.dy),
        Offset(center.dx + 8, center.dy - 10), borderPaint);
    canvas.drawCircle(
        Offset(center.dx - 10, center.dy), 3, Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset(center.dx + 10, center.dy), 3, Paint()..color = Colors.white);

    if (showLabels) {
      _drawLabel(
          canvas,
          Offset(center.dx, center.dy - 20),
          label,
          const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold));
    }
  }

  void _drawStaticSwitch(Canvas canvas, Offset center) {
    final Paint fill = Paint()
      ..color = const Color(0xFF3B82F6).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    final Paint border = Paint()
      ..color = const Color(0xFF93C5FD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final Rect box = Rect.fromCenter(center: center, width: 60, height: 30);
    canvas.drawRect(box, fill);
    canvas.drawRect(box, border);

    // Diode symbols on top and bottom
    _drawDiode(canvas, Offset(center.dx, center.dy - 15), isUp: true);
    _drawDiode(canvas, Offset(center.dx, center.dy + 15), isUp: false);

    if (showLabels) {
      _drawLabel(
          canvas,
          Offset(center.dx, center.dy - 25),
          'Static Switch',
          const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold));
    }
  }

  void _drawDiode(Canvas canvas, Offset center, {required bool isUp}) {
    final Paint stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final int dir = isUp ? -1 : 1;

    // Circle
    canvas.drawCircle(Offset(center.dx, center.dy + (6 * dir)), 3, stroke);
    // Triangle
    final Path triangle = Path();
    triangle.moveTo(center.dx - 5, center.dy);
    triangle.lineTo(center.dx + 5, center.dy);
    triangle.lineTo(center.dx, center.dy - (6 * dir));
    triangle.close();
    canvas.drawPath(triangle, stroke);
  }

  void _drawRectifier(Canvas canvas, Offset center) {
    _drawPowerBox(canvas, center, 'Rectifier', '~', '=');
  }

  void _drawInverter(Canvas canvas, Offset center) {
    _drawPowerBox(canvas, center, 'Inverter', '=', '~');
  }

  void _drawPowerBox(Canvas canvas, Offset center, String label,
      String topSymbol, String bottomSymbol) {
    final Paint fill = Paint()
      ..color = const Color(0xFF3B82F6).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    final Paint border = Paint()
      ..color = const Color(0xFF93C5FD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final Rect box = Rect.fromCenter(center: center, width: 60, height: 30);
    canvas.drawRect(box, fill);
    canvas.drawRect(box, border);
    canvas.drawLine(box.bottomLeft, box.topRight, border);

    _drawLabel(
        canvas,
        Offset(center.dx - 12, center.dy - 5),
        topSymbol,
        const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold));
    _drawLabel(
        canvas,
        Offset(center.dx + 12, center.dy + 5),
        bottomSymbol,
        const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold));

    if (showLabels) {
      _drawLabel(
          canvas,
          Offset(center.dx, center.dy - 25),
          label,
          const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold));
    }
  }

  void _drawBattery(Canvas canvas, Offset center) {
    final Paint fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final Paint border = Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final Rect box = Rect.fromCenter(center: center, width: 50, height: 24);
    canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(4)), fill);
    canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(4)), border);

    if (showLabels) {
      _drawLabel(
          canvas,
          center,
          'Battery',
          const TextStyle(
              color: Color(0xFF22C55E),
              fontSize: 10,
              fontWeight: FontWeight.bold));
    }
  }

  void _drawLabel(Canvas canvas, Offset center, String text, TextStyle style) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tp.layout();
    tp.paint(
        canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant UpsSchematicPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
