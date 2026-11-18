import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/utils/alarm_payload.dart';

class MobileEnvironmentCards extends StatefulWidget {
  final List<dynamic> temperatures;
  final List<dynamic> humidities;
  final List<dynamic>? alarms;
  final bool loading;
  final List<Map<String, dynamic>> doors;
  final bool doorsLoading;
  final bool canUnlockDoors;
  final Future<bool> Function(int id, String name)? onUnlockDoor;

  const MobileEnvironmentCards({
    super.key,
    required this.temperatures,
    required this.humidities,
    this.alarms,
    this.loading = false,
    this.doors = const [],
    this.doorsLoading = false,
    this.canUnlockDoors = false,
    this.onUnlockDoor,
  });

  @override
  State<MobileEnvironmentCards> createState() => _MobileEnvironmentCardsState();
}

enum _EnvStyle { arc, meter }

class _MobileEnvironmentCardsState extends State<MobileEnvironmentCards> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;
  _EnvStyle? _style;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _cabinetKey(String rawName) {
    final cleaned = rawName.replaceAll(RegExp(r'^\d+-'), '').trim();
    return cleaned.isEmpty ? 'Cabinet 1' : cleaned;
  }

  int? _extractCabinetNumber(String name) {
    final m = RegExp(r'(?:cabinet\s*)?(\d+)', caseSensitive: false)
        .firstMatch(name);
    if (m == null) return null;
    return int.tryParse(m.group(1) ?? '');
  }

  String _extractSide(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('back') || lower.contains('rear')) return 'Back';
    return 'Front';
  }

  List<({int cab, String side, String key})> _buildPages() {
    final seen = <String, ({int cab, String side, String key})>{};
    for (final raw in [...widget.temperatures, ...widget.humidities]) {
      if (raw is! Map) continue;
      final name = _cabinetKey((raw['name'] ??
              raw['cabinetName'] ??
              raw['cabinetCode'] ??
              raw['cabinet'] ??
              raw['rackName'] ??
              '')
          .toString());
      final cabRe = RegExp(r'cabinet\s*(\d+)', caseSensitive: false);
      final cab = int.tryParse(cabRe.firstMatch(name)?.group(1) ?? '') ??
          _extractCabinetNumber(name) ??
          1;
      final side = _extractSide(name);
      final k = '$cab-$side';
      seen.putIfAbsent(k, () => (cab: cab, side: side, key: name));
    }
    if (seen.isEmpty) {
      return const [(cab: 1, side: 'Front', key: 'Cabinet 1 Front')];
    }
    final list = seen.values.toList()
      ..sort((a, b) {
        final cmp = a.cab.compareTo(b.cab);
        if (cmp != 0) return cmp;
        final aFront = a.side == 'Front' ? 0 : 1;
        final bFront = b.side == 'Front' ? 0 : 1;
        return aFront.compareTo(bFront);
      });
    return list;
  }

  Map<String, dynamic>? _findReading(
      List<dynamic> list, int cabinet, String side) {
    Map<String, dynamic>? cabMatch;
    Map<String, dynamic>? fallback;
    for (final raw in list) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      fallback ??= m;
      final name = _cabinetKey((m['name'] ??
              m['cabinetName'] ??
              m['cabinetCode'] ??
              m['cabinet'] ??
              m['rackName'] ??
              '')
          .toString());
      final cabRe = RegExp(r'cabinet\s*(\d+)', caseSensitive: false);
      final cabNum = int.tryParse(cabRe.firstMatch(name)?.group(1) ?? '');
      if (cabNum == cabinet) {
        cabMatch ??= m;
        if (_extractSide(name).toLowerCase() == side.toLowerCase()) {
          return m;
        }
      }
    }
    return cabMatch ?? fallback;
  }

  double? _parseNum(Map<String, dynamic>? m) {
    if (m == null) return null;
    final v = m['value'];
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  bool _isAlertReading(Map<String, dynamic>? m) {
    if (m == null) return false;
    final status = (m['status'] ?? '').toString().toLowerCase();
    final alarm = m['alarm'] == true || m['isAlarm'] == true;
    return alarm || status.contains('alarm') || status.contains('alert');
  }

  bool _alarmMatches({
    required String cabLabel,
    required Map<String, dynamic>? reading,
    required bool isHumidity,
  }) {
    final alarms = widget.alarms;
    if (alarms == null || alarms.isEmpty) return false;
    final cab = cabLabel.toLowerCase();
    final metric = isHumidity ? 'humid' : 'temp';
    final name = (reading?['name'] ?? '').toString().toLowerCase();
    for (final a in alarms) {
      final msg = alarmSearchText(a);
      if ((msg.contains(cab) || (name.isNotEmpty && msg.contains(name))) &&
          msg.contains(metric)) {
        return true;
      }
    }
    return false;
  }

  List<Map<String, dynamic>> _doorsForPage(int cabinet, String side) {
    final effective = widget.doors.isNotEmpty
        ? widget.doors
        : const [
            {'id': 1, 'name': 'Front 1', 'side': 'Front', 'isOpen': false},
            {'id': 2, 'name': 'Back 1', 'side': 'Back', 'isOpen': false},
          ];
    final sideLower = side.toLowerCase();
    bool matchesSide(Map<String, dynamic> d) {
      final dSide = (d['side'] ?? '').toString().toLowerCase();
      final dName = (d['name'] ?? '').toString().toLowerCase();
      if (sideLower == 'back') {
        return dSide.contains('back') ||
            dName.contains('back') ||
            dName.contains('rear');
      }
      return dSide.contains('front') || dName.contains('front');
    }

    final exact = effective.where((d) {
      final n = _extractCabinetNumber((d['name'] ?? '').toString());
      return n == cabinet && matchesSide(d);
    }).toList();
    if (exact.isNotEmpty) return exact;

    final bySide = effective.where(matchesSide).toList();
    if (bySide.isNotEmpty) return [bySide.first];

    final byCab = effective.where((d) {
      final n = _extractCabinetNumber((d['name'] ?? '').toString());
      return n == cabinet;
    }).toList();
    if (byCab.isNotEmpty) return [byCab.first];

    return [effective.first];
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textPrimary = isLight ? const Color(0xFF0F172A) : Colors.white;
    final textSecondary = isLight
        ? const Color(0xFF64748B)
        : Colors.white.withValues(alpha: 0.65);

    final pages = _buildPages();
    final safeIdx = _pageIndex.clamp(0, pages.length - 1);
    final activePage = pages[safeIdx];
    final cabinetDoors = _doorsForPage(activePage.cab, activePage.side);

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
                      'Cabinet ${activePage.cab} \u00B7 ${activePage.side}',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Temperature, humidity & door locks',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _MobileStyleSwitch(
                style: _style ?? _EnvStyle.arc,
                onChanged: (next) => setState(() => _style = next),
                isLight: isLight,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 158,
            child: PageView.builder(
              controller: _pageController,
              itemCount: pages.length,
              onPageChanged: (idx) => setState(() => _pageIndex = idx),
              itemBuilder: (context, idx) {
                final pg = pages[idx];
                final cabLabel = 'Cabinet ${pg.cab} ${pg.side}';
                final t = _findReading(widget.temperatures, pg.cab, pg.side);
                final h = _findReading(widget.humidities, pg.cab, pg.side);
                final tempVal = _parseNum(t);
                final humVal = _parseNum(h);

                final tempAlert = _isAlertReading(t) ||
                    _alarmMatches(
                        cabLabel: cabLabel, reading: t, isHumidity: false);
                final humAlert = _isAlertReading(h) ||
                    _alarmMatches(
                        cabLabel: cabLabel, reading: h, isHumidity: true);

                final Color tempColor = tempAlert
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF22C55E);

                final Color humColor = humAlert
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF3B82F6);

                return Row(
                  children: [
                    Expanded(
                      child: _ClimateMetricTile(
                        label: 'Temperature',
                        icon: Icons.thermostat_rounded,
                        valueText: tempVal == null
                            ? '--'
                            : '${tempVal.toStringAsFixed(1)}\u00B0C',
                        accentColor: tempColor,
                        progress: tempVal == null
                            ? 0.0
                            : (tempVal / 50.0).clamp(0.0, 1.0),
                        loading: widget.loading && tempVal == null,
                        isLight: isLight,
                        style: _style ?? _EnvStyle.arc,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ClimateMetricTile(
                        label: 'Humidity',
                        icon: Icons.water_drop_outlined,
                        valueText: humVal == null
                            ? '--'
                            : '${humVal.toStringAsFixed(1)}%',
                        accentColor: humColor,
                        progress: humVal == null
                            ? 0.0
                            : (humVal / 100.0).clamp(0.0, 1.0),
                        loading: widget.loading && humVal == null,
                        isLight: isLight,
                        style: _style ?? _EnvStyle.arc,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (pages.length > 1) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pages.length, (i) {
                final active = i == safeIdx;
                return GestureDetector(
                  onTap: () => _pageController.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: active ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: active
                          ? const Color(0xFF0EA5E9)
                          : (isLight
                              ? const Color(0xFFCBD5E1)
                              : Colors.white.withValues(alpha: 0.22)),
                    ),
                  ),
                );
              }),
            ),
          ],
          if (cabinetDoors.isNotEmpty) ...[
            const SizedBox(height: 14),
            if (cabinetDoors.length == 1)
              _CabinetDoorTile(
                door: cabinetDoors.first,
                canUnlock: widget.canUnlockDoors,
                onUnlock: widget.onUnlockDoor,
                compactRow: true,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _CabinetDoorTile(
                      door: cabinetDoors[0],
                      canUnlock: widget.canUnlockDoors,
                      onUnlock: widget.onUnlockDoor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CabinetDoorTile(
                      door: cabinetDoors[1],
                      canUnlock: widget.canUnlockDoors,
                      onUnlock: widget.onUnlockDoor,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _MobileStyleSwitch extends StatelessWidget {
  final _EnvStyle style;
  final ValueChanged<_EnvStyle> onChanged;
  final bool isLight;

  const _MobileStyleSwitch({
    required this.style,
    required this.onChanged,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    final isMeter = style == _EnvStyle.meter;
    const activeColor = Color(0xFF00B87C);
    final borderColor = isMeter
        ? activeColor
        : (isLight
            ? const Color(0xFFD1D5DB)
            : Colors.white.withValues(alpha: 0.72));
    final knobColor = isMeter
        ? activeColor
        : (isLight
            ? const Color(0xFF9CA3AF)
            : Colors.white.withValues(alpha: 0.8));

    return GestureDetector(
      onTap: () => onChanged(isMeter ? _EnvStyle.arc : _EnvStyle.meter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: isLight ? const Color(0xFFF3F4F6) : Colors.transparent,
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: isMeter ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: knobColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClimateMetricTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final String valueText;
  final Color accentColor;
  final double progress;
  final bool loading;
  final bool isLight;
  final _EnvStyle style;

  const _ClimateMetricTile({
    required this.label,
    required this.icon,
    required this.valueText,
    required this.accentColor,
    required this.progress,
    required this.loading,
    required this.isLight,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isLight ? const Color(0xFF0F172A) : Colors.white;
    final textSecondary = isLight
        ? const Color(0xFF64748B)
        : Colors.white.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF1A1F29),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLight
              ? const Color(0xFFE5E7EB)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(icon, size: 17, color: accentColor),
            ],
          ),
          const SizedBox(height: 10),
          if (style == _EnvStyle.arc)
            SizedBox(
              width: 108,
              height: 92,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, animProg, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _EnvArcGaugePainter(
                          progress: animProg,
                          color: accentColor,
                          isLight: isLight,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: loading ? 0.45 : 1.0,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            valueText,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: textPrimary,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, animProg, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 108,
                    height: 68,
                    child: CustomPaint(
                      painter: _EnvMeterGaugePainter(
                        progress: animProg,
                        color: accentColor,
                        isLight: isLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: loading ? 0.45 : 1.0,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        valueText,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EnvArcGaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isLight;

  _EnvArcGaugePainter({
    required this.progress,
    required this.color,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.56);
    final radius = min(size.width, size.height) * 0.44;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const start = 140 * pi / 180.0;
    const sweep = 260 * pi / 180.0;
    const double strokeW = 7.0;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..color = isLight
          ? const Color(0xFFE2E8F0)
          : Colors.white.withValues(alpha: 0.12);
    canvas.drawArc(rect, start, sweep, false, trackPaint);

    final prog = sweep * progress.clamp(0.0, 1.0);
    if (prog > 0) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW + 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..color = color.withValues(alpha: isLight ? 0.22 : 0.36);
      canvas.drawArc(rect, start, prog, false, glowPaint);

      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(rect, start, prog, false, arcPaint);

      final capAngle = start + prog;
      final cap = Offset(
        center.dx + radius * cos(capAngle),
        center.dy + radius * sin(capAngle),
      );
      canvas.drawCircle(cap, 3.2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _EnvArcGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.isLight != isLight;
  }
}

class _EnvMeterGaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isLight;

  _EnvMeterGaugePainter({
    required this.progress,
    required this.color,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.66);
    final outerRadius = min(size.width, size.height) * 0.56;
    const start = 140 * pi / 180.0;
    const sweep = 260 * pi / 180.0;
    final clamped = progress.clamp(0.0, 1.0);
    const ticks = 24;
    final activeTicks = (ticks * clamped).round();
    final inactiveColor = isLight
        ? const Color(0xFFE2E8F0)
        : Colors.white.withValues(alpha: 0.14);

    for (int i = 0; i <= ticks; i++) {
      final t = i / ticks;
      final angle = start + sweep * t;
      final isMajor = i % 6 == 0;
      final len = isMajor ? 8.5 : 5.5;
      final p1 = Offset(
        center.dx + (outerRadius - len) * cos(angle),
        center.dy + (outerRadius - len) * sin(angle),
      );
      final p2 = Offset(
        center.dx + outerRadius * cos(angle),
        center.dy + outerRadius * sin(angle),
      );
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = i <= activeTicks ? color : inactiveColor
          ..strokeWidth = isMajor ? 2.0 : 1.3
          ..strokeCap = StrokeCap.round,
      );
    }

    final needleAngle = start + sweep * clamped;
    final needleTip = Offset(
      center.dx + (outerRadius - 11) * cos(needleAngle),
      center.dy + (outerRadius - 11) * sin(needleAngle),
    );
    canvas.drawLine(
      center,
      needleTip,
      Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 4.2, Paint()..color = color);
    canvas.drawCircle(
      center,
      2.0,
      Paint()..color = isLight ? Colors.white : const Color(0xFF141820),
    );
  }

  @override
  bool shouldRepaint(covariant _EnvMeterGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.isLight != isLight;
  }
}

class _CabinetDoorTile extends StatefulWidget {
  final Map<String, dynamic> door;
  final bool canUnlock;
  final Future<bool> Function(int id, String name)? onUnlock;
  final bool compactRow;

  const _CabinetDoorTile({
    required this.door,
    required this.canUnlock,
    required this.onUnlock,
    this.compactRow = false,
  });

  @override
  State<_CabinetDoorTile> createState() => _CabinetDoorTileState();
}

class _CabinetDoorTileState extends State<_CabinetDoorTile> {
  bool _localUnlocked = false;
  bool _isUnlocking = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _doUnlock(int id, String rawName) async {
    if (_isUnlocking || widget.onUnlock == null) return;
    setState(() => _isUnlocking = true);
    try {
      final success = await widget.onUnlock!(id, rawName);
      if (success == true && mounted) {
        setState(() => _localUnlocked = true);
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _localUnlocked = false);
        });
      }
    } finally {
      if (mounted) setState(() => _isUnlocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final rawName = widget.door['name']?.toString() ?? 'Door';
    final id = int.tryParse(widget.door['id']?.toString() ?? '') ?? 0;
    final rawOpen = widget.door['isOpen'];
    final doorIsOpen = rawOpen == true ||
        rawOpen == 1 ||
        rawOpen?.toString().trim().toLowerCase() == 'true';
    final isUnlocked = _localUnlocked || doorIsOpen;
    final enabled =
        widget.canUnlock && !isUnlocked && !_isUnlocking && id != 0;

    final textPrimary = isLight ? const Color(0xFF0F172A) : Colors.white;
    final textSecondary = isLight
        ? const Color(0xFF64748B)
        : Colors.white.withValues(alpha: 0.6);

    final Color lockAccent = isUnlocked
        ? const Color(0xFF10B981)
        : (widget.canUnlock
            ? const Color(0xFF0EA5E9)
            : const Color(0xFF64748B));
    final Color iconBg =
        lockAccent.withValues(alpha: isLight ? 0.12 : 0.18);
    final Color iconFg = isLight
        ? (isUnlocked
            ? const Color(0xFF059669)
            : (widget.canUnlock
                ? const Color(0xFF0284C7)
                : const Color(0xFF475569)))
        : (Color.lerp(lockAccent, Colors.white, 0.25) ?? lockAccent);

    final String buttonLabel = _isUnlocking
        ? 'Unlocking...'
        : isUnlocked
            ? 'Unlocked'
            : (widget.canUnlock ? 'Unlock' : 'No Access');

    final Color buttonBg = isUnlocked
        ? const Color(0xFF10B981).withValues(alpha: isLight ? 0.14 : 0.20)
        : enabled
            ? (isLight ? const Color(0xFF0F172A) : const Color(0xFF2563EB))
            : (isLight
                ? const Color(0xFFE2E8F0)
                : Colors.white.withValues(alpha: 0.08));
    final Color buttonFg = isUnlocked
        ? (isLight ? const Color(0xFF059669) : const Color(0xFF34D399))
        : enabled
            ? Colors.white
            : (isLight
                ? const Color(0xFF94A3B8)
                : Colors.white.withValues(alpha: 0.4));

    return Container(
      padding: EdgeInsets.all(widget.compactRow ? 12 : 14),
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF1A1F29),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnlocked
              ? const Color(0xFF10B981).withValues(alpha: 0.35)
              : (isLight
                  ? const Color(0xFFE5E7EB)
                  : Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: widget.compactRow
          ? Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: iconBg,
                  ),
                  child: Icon(
                    isUnlocked
                        ? Icons.lock_open_rounded
                        : Icons.lock_outline_rounded,
                    size: 18,
                    color: iconFg,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rawName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isUnlocked ? 'Unlocked' : 'Secured',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isUnlocked
                              ? (isLight
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF34D399))
                              : textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 40,
                  child: Material(
                    color: buttonBg,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: enabled ? () => _doUnlock(id, rawName) : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Center(
                          child: Text(
                            buttonLabel,
                            style: TextStyle(
                              color: buttonFg,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rawName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isUnlocked ? 'Unlocked' : 'Secured',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isUnlocked
                            ? (isLight
                                ? const Color(0xFF059669)
                                : const Color(0xFF34D399))
                            : textSecondary,
                        fontWeight: FontWeight.w500,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: iconBg,
                ),
                child: Icon(
                  isUnlocked
                      ? Icons.lock_open_rounded
                      : Icons.lock_outline_rounded,
                  size: 18,
                  color: iconFg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: Material(
              color: buttonBg,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: enabled ? () => _doUnlock(id, rawName) : null,
                borderRadius: BorderRadius.circular(14),
                child: Center(
                  child: Text(
                    buttonLabel,
                    style: TextStyle(
                      color: buttonFg,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
