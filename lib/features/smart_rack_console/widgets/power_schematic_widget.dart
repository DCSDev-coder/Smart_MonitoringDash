import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../models/smart_rack_console_snapshot.dart';

class PowerSchematicWidget extends StatefulWidget {
  const PowerSchematicWidget({
    super.key,
    required this.snapshot,
    this.showLabels = false,
  });

  final SmartRackConsoleSnapshot snapshot;
  final bool showLabels;

  @override
  State<PowerSchematicWidget> createState() => _PowerSchematicWidgetState();
}

class _PowerSchematicWidgetState extends State<PowerSchematicWidget> {
  final PowerPathCache _pathCache = PowerPathCache();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLight = Theme.of(context).brightness == Brightness.light;
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: PowerSchematicPainter(
            pathCache: _pathCache,
            showLabels: widget.showLabels,
            isLight: isLight,
          ),
        );
      },
    );
  }
}

class PowerPathCache {
  Size? _lastSize;

  late Path circuitPath;

  void update(Size size) {
    if (_lastSize == size) return;
    _lastSize = size;

    final double w = size.width;
    final double h = size.height;
    final Rect b = Rect.fromLTRB(w * 0.05, h * 0.05, w * 0.95, h * 0.95);

    circuitPath = Path();

    // The central spine x-coordinate
    final double spineX = b.left + w * 0.25;

    // Main input line
    final double mainY = b.top + h * 0.25; // 25% down
    circuitPath.moveTo(b.left + 20, mainY);
    circuitPath.lineTo(spineX, mainY);

    // Left Vertical Spine (7 branches)
    final double branchSpacing = (h * 0.8) / 6;
    final double topY = b.top + h * 0.1;
    final double bottomY = topY + branchSpacing * 6;

    circuitPath.moveTo(spineX, topY);
    circuitPath.lineTo(spineX, bottomY);

    // Branch 1: UPS (Top)
    final double y1 = topY;
    circuitPath.moveTo(spineX, y1);
    circuitPath.lineTo(spineX + w * 0.35, y1);

    // Branch 2: Locking device
    final double y2 = topY + branchSpacing * 1;
    circuitPath.moveTo(spineX, y2);
    circuitPath.lineTo(spineX + w * 0.15, y2);

    // Branch 3: PDU1S
    final double y3 = topY + branchSpacing * 2;
    circuitPath.moveTo(spineX, y3);
    circuitPath.lineTo(spineX + w * 0.25, y3);

    // Branch 4: PDUnS
    final double y4 = topY + branchSpacing * 3;
    circuitPath.moveTo(spineX, y4);
    circuitPath.lineTo(spineX + w * 0.25, y4);

    // Branch 5: Aircon1
    final double y5 = topY + branchSpacing * 4;
    circuitPath.moveTo(spineX, y5);
    circuitPath.lineTo(spineX + w * 0.25, y5);

    // Branch 6: Aircon2
    final double y6 = topY + branchSpacing * 5;
    circuitPath.moveTo(spineX, y6);
    circuitPath.lineTo(spineX + w * 0.25, y6);

    // Branch 7: Lightning protection
    final double y7 = bottomY;
    circuitPath.moveTo(spineX, y7);
    circuitPath.lineTo(spineX + w * 0.15, y7);

    // UPS Sub-Branches (Right Side)
    final double subSpineX = spineX + w * 0.35;
    final double subTopY = topY;
    final double subBottomY = topY + branchSpacing * 2.5;

    circuitPath.moveTo(subSpineX, subTopY);
    circuitPath.lineTo(subSpineX, subBottomY);

    // Sub-Branch 1.1: PDU1U
    circuitPath.moveTo(subSpineX, subTopY);
    circuitPath.lineTo(subSpineX + w * 0.2, subTopY);

    // Sub-Branch 1.2: PDUnU
    final double subY2 = topY + branchSpacing * 1;
    circuitPath.moveTo(subSpineX, subY2);
    circuitPath.lineTo(subSpineX + w * 0.2, subY2);

    // Sub-Branch 1.3: Fan/Lighting Hub
    final double subY3 = topY + branchSpacing * 2.5;
    circuitPath.moveTo(subSpineX, subY3);
    circuitPath.lineTo(subSpineX + w * 0.1, subY3);

    // Hub splits into 4 (Fan1, Fan2, Lighting1, Lighting2)
    final double hubSpineX = subSpineX + w * 0.1;
    final double hubTopY = subY3 - branchSpacing * 0.6;
    final double hubBottomY = subY3 + branchSpacing * 1.2;

    circuitPath.moveTo(hubSpineX, hubTopY);
    circuitPath.lineTo(hubSpineX, hubBottomY);

    // Fan1
    circuitPath.moveTo(hubSpineX, hubTopY);
    circuitPath.lineTo(hubSpineX + w * 0.1, hubTopY);

    // Fan2
    final double hubY2 = hubTopY + branchSpacing * 0.6;
    circuitPath.moveTo(hubSpineX, hubY2);
    circuitPath.lineTo(hubSpineX + w * 0.1, hubY2);

    // Lighting1
    final double hubY3 = hubTopY + branchSpacing * 1.2;
    circuitPath.moveTo(hubSpineX, hubY3);
    circuitPath.lineTo(hubSpineX + w * 0.1, hubY3);

    // Lighting2
    final double hubY4 = hubBottomY;
    circuitPath.moveTo(hubSpineX, hubY4);
    circuitPath.lineTo(hubSpineX + w * 0.1, hubY4);

    // Ground line from Lightning Protection
    circuitPath.moveTo(spineX + w * 0.15 + 40, y7);
    circuitPath.lineTo(spineX + w * 0.15 + 40, y7 + 20);
  }
}

class PowerSchematicPainter extends CustomPainter {
  PowerSchematicPainter({
    required this.pathCache,
    required this.showLabels,
    required this.isLight,
  });

  final PowerPathCache pathCache;
  final bool showLabels;
  final bool isLight;

  @override
  void paint(Canvas canvas, Size size) {
    pathCache.update(size);

    final double w = size.width;
    final double h = size.height;
    final Rect b = Rect.fromLTRB(w * 0.05, h * 0.05, w * 0.95, h * 0.95);

    if (!AppConfig.isRackConsoleBuild) {
      // Base background gradient like other schematics
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height / 2),
          size.width * 0.8,
          [
            const Color(0xFF1E3A8A).withValues(alpha: 0.2),
            Colors.transparent,
          ],
        );
      canvas.drawRect(Offset.zero & size, paint);
    }

    // Draw the cyan circuit lines
    final Paint linePaint = Paint()
      ..color = isLight ? const Color(0xFF0284C7) : const Color(0xFF67E8F9) // Bright cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppConfig.isRackConsoleBuild ? 2 : 3;
    final Paint glowPaint = Paint()
      ..color = const Color(0xFF06B6D4).withValues(
        alpha: AppConfig.isRackConsoleBuild ? 0.16 : 0.4,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppConfig.isRackConsoleBuild ? 0 : 8;

    if (!AppConfig.isRackConsoleBuild) {
      canvas.drawPath(pathCache.circuitPath, glowPaint);
    }
    canvas.drawPath(pathCache.circuitPath, linePaint);

    _drawComponents(canvas, w, h, b);
  }

  void _drawComponents(Canvas canvas, double w, double h, Rect b) {
    final TextStyle textStyle = TextStyle(
      color: isLight ? const Color(0xFF183153) : Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    final double spineX = b.left + w * 0.25;
    final double branchSpacing = (h * 0.8) / 6;
    final double topY = b.top + h * 0.1;
    final double mainY = b.top + h * 0.25;

    // Main Input Node
    _drawNode(canvas, Offset(b.left + 20, mainY));
    if (showLabels) {
      _drawLabel(
          canvas, Offset(b.left + 20, mainY - 20), 'Main input', textStyle);
    }
    _drawSwitch(canvas, Offset(b.left + 20 + w * 0.08, mainY), '');

    // Branch 1: UPS
    final double y1 = topY;
    _drawSwitch(canvas, Offset(spineX + 20, y1), showLabels ? '1QF1' : '');
    _drawUPSBlock(canvas, Offset(spineX + w * 0.15, y1));
    _drawSwitch(canvas, Offset(spineX + w * 0.25, y1), showLabels ? '2QF' : '');

    // Branch 2: Locking device
    final double y2 = topY + branchSpacing * 1;
    _drawSwitch(canvas, Offset(spineX + 20, y2), showLabels ? '1QF2' : '');
    if (showLabels) {
      _drawLabel(canvas, Offset(spineX + w * 0.15 + 40, y2), 'Locking device',
          textStyle);
    }

    // Branch 3: PDU1S
    final double y3 = topY + branchSpacing * 2;
    _drawSwitch(canvas, Offset(spineX + 20, y3), showLabels ? '1QF3' : '');
    _drawNode(canvas, Offset(spineX + w * 0.25, y3));
    if (showLabels) {
      _drawLabel(
          canvas, Offset(spineX + w * 0.25 + 30, y3), 'PDU1S', textStyle);
      _drawLabel(canvas, Offset(spineX + 40, y3 + branchSpacing * 0.5),
          '......', textStyle);
      _drawLabel(
          canvas,
          Offset(spineX + w * 0.25 + 20, y3 + branchSpacing * 0.5),
          '......',
          textStyle);
    }

    // Branch 4: PDUnS
    final double y4 = topY + branchSpacing * 3;
    _drawSwitch(canvas, Offset(spineX + 20, y4), showLabels ? '1QFn' : '');
    _drawNode(canvas, Offset(spineX + w * 0.25, y4));
    if (showLabels) {
      _drawLabel(
          canvas, Offset(spineX + w * 0.25 + 30, y4), 'PDUnS', textStyle);
    }

    // Branch 5: Aircon1
    final double y5 = topY + branchSpacing * 4;
    _drawSwitch(canvas, Offset(spineX + 20, y5), showLabels ? '1QFn' : '');
    _drawNode(canvas, Offset(spineX + w * 0.25, y5));
    if (showLabels) {
      _drawLabel(
          canvas, Offset(spineX + w * 0.25 + 30, y5), 'Aircon1', textStyle);
      _drawLabel(canvas, Offset(spineX + 40, y5 + branchSpacing * 0.5),
          '......', textStyle);
      _drawLabel(
          canvas,
          Offset(spineX + w * 0.25 + 20, y5 + branchSpacing * 0.5),
          '......',
          textStyle);
    }

    // Branch 6: Aircon2
    final double y6 = topY + branchSpacing * 5;
    _drawSwitch(canvas, Offset(spineX + 20, y6), showLabels ? '1QFn' : '');
    _drawNode(canvas, Offset(spineX + w * 0.25, y6));
    if (showLabels) {
      _drawLabel(
          canvas, Offset(spineX + w * 0.25 + 30, y6), 'Aircon2', textStyle);
    }

    // Branch 7: Lightning protection
    final double y7 = topY + branchSpacing * 6;
    _drawLightningModule(canvas, Offset(spineX + w * 0.15, y7));
    if (showLabels) {
      _drawLabel(canvas, Offset(spineX + w * 0.15, y7 + 25),
          'Lightning protection module', textStyle);
    }
    _drawGround(canvas, Offset(spineX + w * 0.15 + 40, y7 + 20));

    // SUB-BRANCHES (Right Side)
    final double subSpineX = spineX + w * 0.35;
    final double subTopY = topY;

    // Sub 1.1: PDU1U
    _drawSwitch(
        canvas, Offset(subSpineX + 20, subTopY), showLabels ? '2QF1' : '');
    _drawNode(canvas, Offset(subSpineX + w * 0.2, subTopY));
    if (showLabels) {
      _drawLabel(canvas, Offset(subSpineX + w * 0.2 + 30, subTopY), 'PDU1U',
          textStyle);
      _drawLabel(canvas, Offset(subSpineX + 40, subTopY + branchSpacing * 0.5),
          '......', textStyle);
      _drawLabel(
          canvas,
          Offset(subSpineX + w * 0.2 + 20, subTopY + branchSpacing * 0.5),
          '......',
          textStyle);
    }

    // Sub 1.2: PDUnU
    final double subY2 = topY + branchSpacing * 1;
    _drawSwitch(
        canvas, Offset(subSpineX + 20, subY2), showLabels ? '2QFn' : '');
    _drawNode(canvas, Offset(subSpineX + w * 0.2, subY2));
    if (showLabels) {
      _drawLabel(
          canvas, Offset(subSpineX + w * 0.2 + 30, subY2), 'PDUnU', textStyle);
    }

    // Sub 1.3 Hub
    final double subY3 = topY + branchSpacing * 2.5;
    _drawSwitch(
        canvas, Offset(subSpineX + 20, subY3), showLabels ? '2QF4' : '');

    final double hubSpineX = subSpineX + w * 0.1;
    final double hubTopY = subY3 - branchSpacing * 0.6;
    final double hubBottomY = subY3 + branchSpacing * 1.2;

    // Fan1
    _drawSwitch(
        canvas, Offset(hubSpineX + 20, hubTopY), showLabels ? 'KA1' : '');
    _drawNode(canvas, Offset(hubSpineX + w * 0.1, hubTopY));
    if (showLabels) {
      _drawLabel(
          canvas, Offset(hubSpineX + w * 0.1 + 30, hubTopY), 'Fan1', textStyle);
    }

    // Fan2
    final double hubY2 = hubTopY + branchSpacing * 0.6;
    _drawSwitch(canvas, Offset(hubSpineX + 20, hubY2), showLabels ? 'KA2' : '');
    _drawNode(canvas, Offset(hubSpineX + w * 0.1, hubY2));
    if (showLabels) {
      _drawLabel(
          canvas, Offset(hubSpineX + w * 0.1 + 30, hubY2), 'Fan2', textStyle);
    }

    // Lighting1
    final double hubY3 = hubTopY + branchSpacing * 1.2;
    if (showLabels) {
      _drawLabel(canvas, Offset(hubSpineX + 20, hubY3 - 15), 'D11', textStyle);
    }
    _drawNode(canvas, Offset(hubSpineX + w * 0.1, hubY3));
    if (showLabels) {
      _drawLabel(canvas, Offset(hubSpineX + w * 0.1 + 30, hubY3), 'Lighting1',
          textStyle);
    }

    // Lighting2
    final double hubY4 = hubBottomY;
    _drawNode(canvas, Offset(hubSpineX + w * 0.1, hubY4));
    if (showLabels) {
      _drawLabel(canvas, Offset(hubSpineX + w * 0.1 + 30, hubY4), 'Lighting2',
          textStyle);
    }
  }

  void _drawUPSBlock(Canvas canvas, Offset center) {
    final Paint fill = Paint()
      ..color = const Color(0xFF3B82F6).withValues(alpha: 0.8);
    final Paint border = Paint()
      ..color = isLight ? const Color(0xFF1E3A8A) : const Color(0xFF93C5FD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final Rect box = Rect.fromCenter(center: center, width: 40, height: 20);
    canvas.drawRect(box, fill);
    canvas.drawRect(box, border);

    if (showLabels) {
      _drawLabel(
          canvas,
          center,
          'UPS',
          const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold));
    }
  }

  void _drawLightningModule(Canvas canvas, Offset center) {
    final Paint fill = Paint()
      ..color = isLight
          ? const Color(0xFF1E90FF).withValues(alpha: 0.25)
          : const Color(0xFF3B82F6).withValues(alpha: 0.5);
    final Paint border = Paint()
      ..color = isLight ? const Color(0xFF1E3A8A) : const Color(0xFF93C5FD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final Rect box = Rect.fromCenter(center: center, width: 40, height: 20);
    canvas.drawRect(box, fill);
    canvas.drawRect(box, border);

    // Draw triangle pointing right
    final Path tri = Path();
    tri.moveTo(center.dx - 10, center.dy - 6);
    tri.lineTo(center.dx + 10, center.dy);
    tri.lineTo(center.dx - 10, center.dy + 6);
    tri.close();
    canvas.drawPath(tri, Paint()..color = isLight ? const Color(0xFF1E3A8A) : const Color(0xFF93C5FD));
  }

  void _drawGround(Canvas canvas, Offset center) {
    final Paint paint = Paint()
      ..color = isLight ? const Color(0xFF1E3A8A) : const Color(0xFF93C5FD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawLine(Offset(center.dx - 10, center.dy),
        Offset(center.dx + 10, center.dy), paint);
    canvas.drawLine(Offset(center.dx - 6, center.dy + 4),
        Offset(center.dx + 6, center.dy + 4), paint);
    canvas.drawLine(Offset(center.dx - 2, center.dy + 8),
        Offset(center.dx + 2, center.dy + 8), paint);
  }

  void _drawNode(Canvas canvas, Offset center) {
    final Color nodeColor = isLight ? const Color(0xFF0EA5E9) : const Color(0xFF06B6D4);
    final Paint paint = Paint()..color = nodeColor;
    canvas.drawCircle(center, 4, paint);
    canvas.drawCircle(
        center,
        8,
        Paint()
          ..color = nodeColor.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  void _drawSwitch(Canvas canvas, Offset center, String label) {
    final Color switchColor = isLight ? const Color(0xFF1E3A8A) : Colors.white;
    final Paint paint = Paint()
      ..color = switchColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw the switch diagonal line
    canvas.drawLine(Offset(center.dx - 6, center.dy),
        Offset(center.dx + 6, center.dy - 8), paint);
    canvas.drawCircle(
        Offset(center.dx - 6, center.dy), 2, Paint()..color = switchColor);
    canvas.drawCircle(
        Offset(center.dx + 6, center.dy), 2, Paint()..color = switchColor);

    if (showLabels && label.isNotEmpty) {
      _drawLabel(
          canvas,
          Offset(center.dx, center.dy - 15),
          label,
          TextStyle(
              color: isLight ? const Color(0xFF183153) : Colors.white,
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
  bool shouldRepaint(covariant PowerSchematicPainter oldDelegate) {
    return oldDelegate.showLabels != showLabels;
  }
}
