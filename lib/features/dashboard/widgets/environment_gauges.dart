import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/utils/alarm_payload.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/skeleton.dart';
import 'dashboard_typography.dart';

enum EnvironmentGaugeStyle { arc, meter }

// Tunables: keep the mini cards readable on phones without feeling cramped.
const double _kMiniGaugeTitleFontSize = 11;

double? _tryReadNum(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

double? _extractThreshold(Map<String, dynamic>? m, List<String> keys) {
  if (m == null) return null;
  for (final k in keys) {
    if (!m.containsKey(k)) continue;
    final n = _tryReadNum(m[k]);
    if (n != null) return n;
  }
  return null;
}

class EnvironmentRow extends StatefulWidget {
  final List<Map<String, dynamic>> temperatures;
  final List<Map<String, dynamic>> humidities;
  final List<dynamic>? alarms;
  final EnvironmentGaugeStyle initialStyle;
  final double gaugeHeight;
  final bool loading;
  final bool minimalist;
  final bool isVertical;

  const EnvironmentRow({
    super.key,
    required this.temperatures,
    required this.humidities,
    this.alarms,
    this.initialStyle = EnvironmentGaugeStyle.arc,
    this.gaugeHeight = 210,
    this.loading = false,
    this.minimalist = false,
    this.isVertical = false,
  });

  @override
  State<EnvironmentRow> createState() => _EnvironmentRowState();
}

class _EnvironmentRowState extends State<EnvironmentRow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late EnvironmentGaugeStyle _style;

  @override
  void initState() {
    super.initState();
    _style = widget.initialStyle;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _cabinetKey(String rawName) {
    return rawName.replaceAll(RegExp(r'^\d+-'), '').trim();
  }

  Map<String, List<Map<String, dynamic>>> _groupByCabinet(
      List<Map<String, dynamic>> data) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in data) {
      final rawName = item['name']?.toString() ?? 'Unknown';
      final key = _cabinetKey(rawName);
      grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(item);
    }
    return grouped;
  }

  Map<String, dynamic>? _pickPrimary(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return null;
    final sorted = [...items];
    sorted.sort((a, b) {
      final aN = a['name']?.toString().toLowerCase() ?? '';
      final bN = b['name']?.toString().toLowerCase() ?? '';
      final aRank = aN.contains('front') ? 0 : 1;
      final bRank = bN.contains('front') ? 0 : 1;
      return aRank.compareTo(bRank);
    });
    return sorted.first;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Row(
        children: [
          Expanded(child: _EnvironmentGaugeSkeleton()),
          SizedBox(width: 12),
          Expanded(child: _EnvironmentGaugeSkeleton()),
        ],
      );
    }

    final showArrows = MediaQuery.of(context).size.width >= 900;
    final groupedTemps = _groupByCabinet(widget.temperatures);
    final groupedHums = _groupByCabinet(widget.humidities);
    final alarms = widget.alarms;
    final cabinetKeys =
        (groupedTemps.keys.toSet()..addAll(groupedHums.keys)).toList();

    cabinetKeys.sort((a, b) {
      final aNum = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999;
      final bNum = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999;
      if (aNum != bNum) return aNum.compareTo(bNum);

      final aLower = a.toLowerCase();
      final bLower = b.toLowerCase();
      if (aLower.contains('front') && bLower.contains('back')) return -1;
      if (aLower.contains('back') && bLower.contains('front')) return 1;
      return a.compareTo(b);
    });

    if (cabinetKeys.isEmpty) {
      return Column(
        children: [
          SizedBox(
            height: widget.gaugeHeight,
            child: Padding(
              padding: EdgeInsets.zero,
              child: Flex(
                direction: widget.isVertical ? Axis.vertical : Axis.horizontal,
                children: [
                  Expanded(
                    child: _MiniGaugeCard.placeholder(
                      title: 'TEMPERATURE',
                      accent: AppTheme.accentGreen,
                      minimalist: widget.minimalist,
                    ),
                  ),
                  SizedBox(
                    width: widget.isVertical ? 0 : 12,
                    height: widget.isVertical ? 12 : 0,
                  ),
                  Expanded(
                    child: _MiniGaugeCard.placeholder(
                      title: 'HUMIDITY',
                      accent: const Color(0xFF00A3FF),
                      minimalist: widget.minimalist,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _CabinetPager(
            label: 'Cabinet 1',
            count: 1,
            activeIndex: 0,
            showArrows: showArrows,
            trailing: _GaugeStyleSwitch(
              value: _style,
              onChanged: (v) => setState(() => _style = v),
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    final safeIndex = _currentPage.clamp(0, cabinetKeys.length - 1);

    return Column(
      children: [
        SizedBox(
          height: widget.gaugeHeight,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: cabinetKeys.length,
            itemBuilder: (context, index) {
              final cab = cabinetKeys[index];
              final temps = groupedTemps[cab] ?? const [];
              final hums = groupedHums[cab] ?? const [];

              final t = _pickPrimary(temps);
              final h = _pickPrimary(hums);
              final tempVal = t == null
                  ? 0.0
                  : (double.tryParse(t['value'].toString()) ?? 0.0);
              final humVal = h == null
                  ? 0.0
                  : (double.tryParse(h['value'].toString()) ?? 0.0);

              bool isAlert(Map<String, dynamic>? m) {
                if (m == null) return false;
                // Common patterns across our payloads:
                // - statusColor exists when an alarm is active
                // - status can be 0/1, "normal"/"secure" vs others
                final sc = m['statusColor'];
                if (sc != null && sc.toString().isNotEmpty) return true;
                final s = m['status']?.toString().toLowerCase();
                if (s == null || s.isEmpty) return false;
                return !(s == '1' || s == 'normal' || s == 'secure');
              }

              bool alarmMatches({
                required String cabLabel,
                required Map<String, dynamic>? reading,
                required bool isHumidity,
              }) {
                if (alarms == null || alarms.isEmpty) return false;
                final cabLower = cabLabel.toLowerCase();
                final rName = (reading?['name'] ?? reading?['nodeName'] ?? '')
                    .toString()
                    .toLowerCase()
                    .trim();

                // Infer side from reading name (best effort).
                final wantFront = rName.contains('front');
                final wantBack =
                    rName.contains('back') || rName.contains('rear');

                for (final a in alarms) {
                  final msg = alarmSearchText(a);

                  bool matchesSource = false;

                  // Check if alarm specifically names this sensor
                  if (rName.isNotEmpty && msg.contains(rName)) {
                    matchesSource = true;
                  } else if (msg.contains(cabLower)) {
                    // Or if it matches the cabinet, verify front/back constraints
                    bool frontBackMatch = true;
                    if (wantFront && !msg.contains('front')) {
                      frontBackMatch = false;
                    }
                    if (wantBack &&
                        !(msg.contains('back') || msg.contains('rear'))) {
                      frontBackMatch = false;
                    }
                    if (frontBackMatch) {
                      matchesSource = true;
                    }
                  }

                  if (!matchesSource) {
                    continue; // Alarm is for a different rack/sensor
                  }

                  // Now check if the alarm is specifically about Temp or Hum
                  bool hasHumKeyword = msg.contains('hum') ||
                      msg.contains('humid') ||
                      msg.contains('humd');
                  bool hasTempKeyword = msg.contains('temp');

                  if (isHumidity) {
                    // Turn red if explicitly humidity, OR if it's a generic sensor failure (no temp/hum keywords)
                    if (hasHumKeyword || (!hasHumKeyword && !hasTempKeyword)) {
                      return true;
                    }
                  } else {
                    // Turn red if explicitly temperature, OR if it's a generic sensor failure
                    if (hasTempKeyword || (!hasHumKeyword && !hasTempKeyword)) {
                      return true;
                    }
                  }
                }

                return false;
              }

              final tempIsAlert = isAlert(t) ||
                  alarmMatches(cabLabel: cab, reading: t, isHumidity: false);
              final humIsAlert = isAlert(h) ||
                  alarmMatches(cabLabel: cab, reading: h, isHumidity: true);

              // Optional warning thresholds (if backend provides them).
              // These keys are heuristic-based to support multiple payload shapes.
              final tempWarnHigh = _extractThreshold(t, const [
                'warnHigh',
                'highWarn',
                'highWarning',
                'alarmHigh',
                'highAlarm',
                'highLimit',
                'upperLimit',
                'maxAlarm',
                'maxLimit',
              ]);
              final tempWarnLow = _extractThreshold(t, const [
                'warnLow',
                'lowWarn',
                'lowWarning',
                'alarmLow',
                'lowAlarm',
                'lowLimit',
                'lowerLimit',
                'minAlarm',
                'minLimit',
              ]);

              final humWarnHigh = _extractThreshold(h, const [
                'warnHigh',
                'highWarn',
                'highWarning',
                'alarmHigh',
                'highAlarm',
                'highLimit',
                'upperLimit',
                'maxAlarm',
                'maxLimit',
              ]);
              final humWarnLow = _extractThreshold(h, const [
                'warnLow',
                'lowWarn',
                'lowWarning',
                'alarmLow',
                'lowAlarm',
                'lowLimit',
                'lowerLimit',
                'minAlarm',
                'minLimit',
              ]);

              const alertRed = Color(0xFFFF3B30);

              return Padding(
                // Add breathing room so when the user swipes between cabinets,
                // the adjacent pages don't visually "stick" together.
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Flex(
                  direction:
                      widget.isVertical ? Axis.vertical : Axis.horizontal,
                  children: [
                    Expanded(
                      child: _MiniGaugeCard(
                        title: 'TEMPERATURE',
                        iconAsset: 'assets/icons/thermometer.svg',
                        accent: tempIsAlert ? alertRed : AppTheme.accentGreen,
                        valueText: '${tempVal.toStringAsFixed(0)}\u00B0C',
                        progress: (tempVal / 50).clamp(0.0, 1.0),
                        warnLow: tempWarnLow,
                        warnHigh: tempWarnHigh,
                        maxScale: 50,
                        style: _style,
                        minimalist: widget.minimalist,
                      ),
                    ),
                    SizedBox(
                      width: widget.isVertical ? 0 : 12,
                      height: widget.isVertical ? 12 : 0,
                    ),
                    Expanded(
                      child: _MiniGaugeCard(
                        title: 'HUMIDITY',
                        iconAsset: 'assets/icons/droplet.svg',
                        // Light-mode dashboard spec: cards are cyan-blue, so keep the
                        // humidity arc distinct (aqua) for contrast.
                        accent: humIsAlert
                            ? alertRed
                            : (Theme.of(context).brightness == Brightness.light
                                ? const Color(0xFF00E5FF)
                                : const Color(0xFF00A3FF)),
                        valueText: '${humVal.toStringAsFixed(0)}%',
                        progress: (humVal / 100).clamp(0.0, 1.0),
                        warnLow: humWarnLow,
                        warnHigh: humWarnHigh,
                        maxScale: 100,
                        style: _style,
                        minimalist: widget.minimalist,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _CabinetPager(
          label: cabinetKeys[safeIndex],
          count: cabinetKeys.length,
          activeIndex: safeIndex,
          showArrows: showArrows,
          onPrev: cabinetKeys.length <= 1
              ? null
              : () {
                  final next = (safeIndex - 1).clamp(0, cabinetKeys.length - 1);
                  _pageController.animateToPage(
                    next,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                  );
                },
          onNext: cabinetKeys.length <= 1
              ? null
              : () {
                  final next = (safeIndex + 1).clamp(0, cabinetKeys.length - 1);
                  _pageController.animateToPage(
                    next,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                  );
                },
          onDotTap: (i) {
            _pageController.animateToPage(
              i,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
            );
          },
          trailing: _GaugeStyleSwitch(
            value: _style,
            onChanged: (v) => setState(() => _style = v),
          ),
        ),
      ],
    );
  }
}

class _EnvironmentGaugeSkeleton extends StatelessWidget {
  const _EnvironmentGaugeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Skeleton(
                    height: 14,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
                SizedBox(width: 8),
                Skeleton(
                  width: 14,
                  height: 14,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ],
            ),
            SizedBox(height: 14),
            AspectRatio(
              aspectRatio: 1.65,
              child: Center(
                child: Skeleton(
                  width: 160,
                  height: 90,
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
              ),
            ),
            SizedBox(height: 10),
            Skeleton(
              width: 120,
              height: 12,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniGaugeCard extends StatelessWidget {
  final String title;
  final String iconAsset;
  final Color accent;
  final String valueText;
  final double progress;
  final double? warnLow;
  final double? warnHigh;
  final double maxScale;
  final bool placeholder;
  final EnvironmentGaugeStyle style;
  final bool minimalist;

  const _MiniGaugeCard({
    required this.title,
    required this.iconAsset,
    required this.accent,
    required this.valueText,
    required this.progress,
    this.warnLow,
    this.warnHigh,
    required this.maxScale,
    required this.style,
    this.minimalist = false,
  }) : placeholder = false;

  const _MiniGaugeCard.placeholder({
    required this.title,
    required this.accent,
    this.minimalist = false,
  })  : iconAsset = '',
        valueText = '--',
        progress = 0,
        warnLow = null,
        warnHigh = null,
        maxScale = 1,
        style = EnvironmentGaugeStyle.arc,
        placeholder = true;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1100;
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final onSurface = theme.colorScheme.onSurface;

    // Light-mode: make Temperature and PUE "pop" with green, keep Humidity cyan-blue.
    final isTempCard = title.toUpperCase().contains('TEMP');
    final isAlertCard = accent.toARGB32() == const Color(0xFFFF3B30).toARGB32();
    final bgTint = isLight
        ? (isAlertCard
            ? const Color(0xFFFF3B30)
            : (isTempCard
                ? const Color.fromARGB(255, 0, 161, 116)
                : const Color(0xFF00A3FF)))
        : null;

    return Card(
      color: minimalist ? Colors.transparent : bgTint,
      elevation: minimalist ? 0 : null,
      margin: minimalist ? EdgeInsets.zero : null,
      child: Padding(
        padding: minimalist
            ? const EdgeInsets.all(10)
            : const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!minimalist) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isLight ? Colors.white : onSurface,
                        fontSize: _kMiniGaugeTitleFontSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (!placeholder)
                    SvgPicture.asset(
                      iconAsset,
                      width: 22,
                      height: 22,
                      colorFilter: ColorFilter.mode(
                          isLight ? Colors.white : accent, BlendMode.srcIn),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Convert absolute warning thresholds to 0..1 stops.
                      // Only render if they are within the scale.
                      //
                      // Example:
                      // Temp: warnHigh=28 (maxScale=50) => 0.56
                      // Hum: warnHigh=70 (maxScale=100) => 0.70
                      Positioned.fill(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          switchInCurve: Curves.easeOutBack,
                          switchOutCurve: Curves.easeInBack,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                  scale: animation, child: child),
                            );
                          },
                          child: style == EnvironmentGaugeStyle.meter
                              ? TweenAnimationBuilder<double>(
                                  key: const ValueKey(
                                      EnvironmentGaugeStyle.meter),
                                  tween: Tween<double>(
                                    begin: 0,
                                    end: placeholder ? 0.0 : progress,
                                  ),
                                  duration: const Duration(milliseconds: 1600),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, v, _) => _DialMeterGauge(
                                    progress: v,
                                    glowColor: accent,
                                    glowIntensity: minimalist ? 0.4 : 1.0,
                                    warningStops: [
                                      if (warnLow != null)
                                        (warnLow! / maxScale).clamp(0.0, 1.0),
                                      if (warnHigh != null)
                                        (warnHigh! / maxScale).clamp(0.0, 1.0),
                                    ],
                                  ),
                                )
                              : TweenAnimationBuilder<double>(
                                  key:
                                      const ValueKey(EnvironmentGaugeStyle.arc),
                                  tween: Tween<double>(
                                    begin: 0,
                                    end: placeholder ? 0.0 : progress,
                                  ),
                                  duration: const Duration(milliseconds: 1600),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, v, _) => ArcGauge(
                                    progress: v,
                                    glowColor: accent,
                                    baseColor: const Color(0xFF5A5A5A),
                                    strokeWidth: isWide ? 15 : 8,
                                    sweepDegrees: 255,
                                    startDegrees: 145,
                                    glowIntensity: minimalist ? 0.4 : 1.0,
                                    warningStops: [
                                      if (warnLow != null)
                                        (warnLow! / maxScale).clamp(0.0, 1.0),
                                      if (warnHigh != null)
                                        (warnHigh! / maxScale).clamp(0.0, 1.0),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: 0.6,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            valueText,
                            style: bitcount(
                              context,
                              fontSize: 36,
                              color: isLight
                                  ? AppTheme.lightTextPrimary
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CabinetPager extends StatelessWidget {
  final String label;
  final int count;
  final int activeIndex;
  final ValueChanged<int>? onDotTap;
  final Widget? trailing;
  final bool showArrows;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _CabinetPager({
    required this.label,
    required this.count,
    required this.activeIndex,
    this.onDotTap,
    this.trailing,
    this.showArrows = false,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final dots = count.clamp(1, 6);
    final active = activeIndex.clamp(0, dots - 1);
    return Column(
      children: [
        SizedBox(
          height: 28,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light
                        ? AppTheme.lightTextPrimary
                        : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null)
                Align(alignment: Alignment.centerRight, child: trailing!),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showArrows)
              _PagerArrow(
                icon: Icons.chevron_left_rounded,
                enabled: onPrev != null,
                onTap: onPrev,
              ),
            ...List.generate(dots, (i) {
              final isActive = i == active;
              return GestureDetector(
                onTap: onDotTap == null ? null : () => onDotTap!(i),
                child: Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? (Theme.of(context).brightness == Brightness.light
                            ? const Color(0xFF00A3FF)
                            : Colors.white)
                        : (Theme.of(context).brightness == Brightness.light
                            ? AppTheme.lightTextSecondary.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.22)),
                  ),
                ),
              );
            }),
            if (showArrows)
              _PagerArrow(
                icon: Icons.chevron_right_rounded,
                enabled: onNext != null,
                onTap: onNext,
              ),
          ],
        ),
      ],
    );
  }
}

class _PagerArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _PagerArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = enabled
        ? (Theme.of(context).brightness == Brightness.light
                ? AppTheme.lightTextPrimary
                : Colors.white)
            .withValues(alpha: 0.75)
        : (Theme.of(context).brightness == Brightness.light
                ? AppTheme.lightTextSecondary
                : Colors.white)
            .withValues(alpha: 0.18);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 28,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (Theme.of(context).brightness == Brightness.light
                    ? AppTheme.lightTextPrimary
                    : Colors.white)
                .withValues(alpha: enabled ? 0.06 : 0.03),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(icon, size: 20, color: c),
        ),
      ),
    );
  }
}

class ArcGauge extends StatelessWidget {
  final double progress;
  final Color glowColor;
  final Color baseColor;
  final double strokeWidth;
  final double sweepDegrees;
  final double startDegrees;
  final double glowIntensity;
  final List<double> warningStops;

  const ArcGauge({
    required this.progress,
    required this.glowColor,
    required this.baseColor,
    required this.strokeWidth,
    required this.sweepDegrees,
    required this.startDegrees,
    this.glowIntensity = 1.0,
    this.warningStops = const [],
  });

  @override
  Widget build(BuildContext context) {
    return _ArcGaugeV2(
      progress: progress,
      glowColor: glowColor,
      baseColor: baseColor,
      strokeWidth: strokeWidth,
      sweepDegrees: sweepDegrees,
      startDegrees: startDegrees,
      glowIntensity: glowIntensity,
      warningStops: warningStops,
    );
  }
}

class _ArcGaugeV2 extends StatefulWidget {
  final double progress;
  final Color glowColor;
  final Color baseColor;
  final double strokeWidth;
  final double sweepDegrees;
  final double startDegrees;
  final double glowIntensity;
  final List<double> warningStops;

  const _ArcGaugeV2({
    required this.progress,
    required this.glowColor,
    required this.baseColor,
    required this.strokeWidth,
    required this.sweepDegrees,
    required this.startDegrees,
    this.glowIntensity = 1.0,
    this.warningStops = const [],
  });

  @override
  State<_ArcGaugeV2> createState() => _ArcGaugeV2State();
}

class _ArcGaugeV2State extends State<_ArcGaugeV2>
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
        painter: _ArcGaugePainterV2(
          progress: widget.progress,
          glowColor: widget.glowColor,
          baseColor: widget.baseColor,
          strokeWidth: widget.strokeWidth,
          sweepDegrees: widget.sweepDegrees,
          startDegrees: widget.startDegrees,
          rotation: _controller.value,
          brightness: Theme.of(context).brightness,
          glowIntensity: widget.glowIntensity,
          warningStops: widget.warningStops,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ArcGaugePainterV2 extends CustomPainter {
  final double progress;
  final Color glowColor;
  final Color baseColor;
  final double strokeWidth;
  final double sweepDegrees;
  final double startDegrees;
  final double rotation;
  final Brightness brightness;
  final double glowIntensity;
  final List<double> warningStops;

  _ArcGaugePainterV2({
    required this.progress,
    required this.glowColor,
    required this.baseColor,
    required this.strokeWidth,
    required this.sweepDegrees,
    required this.startDegrees,
    required this.rotation,
    required this.brightness,
    required this.glowIntensity,
    required this.warningStops,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - strokeWidth / 2;
    if (!radius.isFinite || radius <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final start = _degToRad(startDegrees);
    final sweep = _degToRad(sweepDegrees);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = brightness == Brightness.light
          ? baseColor.withValues(alpha: 0.55)
          : baseColor.withValues(alpha: 0.20);
    canvas.drawArc(rect, start, sweep, false, trackPaint);

    // Draw warning markers (red) for configured thresholds.
    if (warningStops.isNotEmpty) {
      final warnPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFF3B30).withValues(alpha: 0.95);

      // Small arc segment (in radians) so it reads like a "line" on the track.
      const seg = 0.045; // ~2.6 degrees
      for (final s in warningStops) {
        final clamped = s.clamp(0.0, 1.0);
        final a = start + sweep * clamped;
        canvas.drawArc(rect, a - seg / 2, seg, false, warnPaint);
      }
    }

    final prog = sweep * progress.clamp(0.0, 1.0);
    final gi = glowIntensity.clamp(0.0, 1.0);

    if (prog <= 0) {
      final shadow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 18
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF000000).withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
      canvas.drawArc(rect, start, sweep, false, shadow);

      final ghostRing = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = baseColor.withValues(alpha: 0.32);
      canvas.drawArc(rect, start, sweep, false, ghostRing);
    }

    if (prog > 0 && gi > 0) {
      final ambientGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 16
        ..strokeCap = StrokeCap.round
        ..color = glowColor.withValues(alpha: 0.16 * gi)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 26 * gi);
      canvas.drawArc(rect, start, prog, false, ambientGlow);

      final haloGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 10
        ..strokeCap = StrokeCap.round
        ..color = glowColor.withValues(alpha: 0.34 * gi)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16 * gi);
      canvas.drawArc(rect, start, prog, false, haloGlow);

      final coreGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 4
        ..strokeCap = StrokeCap.round
        ..color = (brightness == Brightness.light
            ? AppTheme.lightTextSecondary.withValues(alpha: 0.4 * gi)
            : Colors.white.withValues(alpha: 0.22 * gi))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * gi);
      canvas.drawArc(rect, start, prog, false, coreGlow);
    }

    if (prog > 0) {
      final progPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      progPaint.shader = SweepGradient(
        colors: [
          glowColor.withValues(alpha: 0.80),
          glowColor,
          const Color(0xFFD4FFDC),
          glowColor,
          glowColor.withValues(alpha: 0.80),
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
    if (gi > 0) {
      final sparkGlow = Paint()
        ..color = (brightness == Brightness.light
                ? AppTheme.lightTextPrimary
                : Colors.white)
            .withValues(alpha: capAlpha * gi)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * gi);
      canvas.drawCircle(cap, 7, sparkGlow);
    }
    canvas.drawCircle(
      cap,
      4,
      Paint()
        ..color = (brightness == Brightness.light
                ? AppTheme.lightTextPrimary
                : Colors.white)
            .withValues(alpha: prog > 0 ? 1.0 : 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant _ArcGaugePainterV2 oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.sweepDegrees != sweepDegrees ||
        oldDelegate.startDegrees != startDegrees ||
        oldDelegate.rotation != rotation;
  }

  double _degToRad(double deg) => deg * pi / 180.0;
}

class _DialMeterGauge extends StatefulWidget {
  final double progress;
  final Color glowColor;
  final double glowIntensity;
  final List<double> warningStops;

  const _DialMeterGauge({
    required this.progress,
    required this.glowColor,
    this.glowIntensity = 1.0,
    this.warningStops = const [],
  });

  @override
  State<_DialMeterGauge> createState() => _DialMeterGaugeState();
}

class _DialMeterGaugeState extends State<_DialMeterGauge>
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
        painter: _DialMeterGaugePainter(
          progress: widget.progress,
          glowColor: widget.glowColor,
          rotation: _controller.value,
          brightness: Theme.of(context).brightness,
          glowIntensity: widget.glowIntensity,
          warningStops: widget.warningStops,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DialMeterGaugePainter extends CustomPainter {
  final double progress;
  final Color glowColor;
  final double rotation;
  final Brightness brightness;
  final double glowIntensity;
  final List<double> warningStops;

  _DialMeterGaugePainter({
    required this.progress,
    required this.glowColor,
    required this.rotation,
    required this.brightness,
    required this.glowIntensity,
    required this.warningStops,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;
    final p = progress.clamp(0.0, 1.0);
    final gi = glowIntensity.clamp(0.0, 1.0);

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.44;
    if (!radius.isFinite || radius <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const startDeg = 120.0;
    const sweepDeg = 300.0;
    final start = _degToRad(startDeg);
    final sweep = _degToRad(sweepDeg);
    final prog = sweep * p;

    // Warning marker lines (red) for configured thresholds.
    if (warningStops.isNotEmpty) {
      final warnPaint = Paint()
        ..color = const Color(0xFFFF3B30).withValues(alpha: 0.95)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final inner = radius + 6;
      final outer = inner + radius * 0.22;
      for (final s in warningStops) {
        final clamped = s.clamp(0.0, 1.0);
        final a = start + sweep * clamped;
        final p1 =
            Offset(center.dx + inner * cos(a), center.dy + inner * sin(a));
        final p2 =
            Offset(center.dx + outer * cos(a), center.dy + outer * sin(a));
        canvas.drawLine(p1, p2, warnPaint);
      }
    }

    const tickCount = 60;
    for (var i = 0; i <= tickCount; i++) {
      final t = i / tickCount;
      final a = start + sweep * t;
      final isMajor = i % 5 == 0;
      final len = isMajor ? radius * 0.18 : radius * 0.10;
      final inner = radius + 8;
      final outer = inner + len;

      final active = a <= start + prog + 0.0001;
      final c = active
          ? glowColor.withValues(alpha: isMajor ? 0.95 : 0.78)
          : (brightness == Brightness.light
              ? AppTheme.lightTextSecondary
                  .withValues(alpha: isMajor ? 0.38 : 0.24)
              : Colors.white.withValues(alpha: isMajor ? 0.18 : 0.12));

      final paint = Paint()
        ..color = c
        ..strokeWidth = isMajor ? 2 : 1
        ..strokeCap = StrokeCap.round;
      final p1 = Offset(center.dx + inner * cos(a), center.dy + inner * sin(a));
      final p2 = Offset(center.dx + outer * cos(a), center.dy + outer * sin(a));
      canvas.drawLine(p1, p2, paint);
    }

    if (prog > 0 && gi > 0) {
      final ambientGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..color = glowColor.withValues(alpha: 0.16 * gi)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 26 * gi);
      canvas.drawArc(rect, start, prog, false, ambientGlow);

      final haloGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..color = glowColor.withValues(alpha: 0.34 * gi)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16 * gi);
      canvas.drawArc(rect, start, prog, false, haloGlow);

      final coreGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..color = (brightness == Brightness.light
            ? AppTheme.lightTextSecondary.withValues(alpha: 0.4 * gi)
            : Colors.white.withValues(alpha: 0.22 * gi))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * gi);
      canvas.drawArc(rect, start, prog, false, coreGlow);

      final progPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;
      progPaint.shader = SweepGradient(
        colors: [
          glowColor.withValues(alpha: 0.80),
          glowColor,
          const Color(0xFFD4FFDC),
          glowColor,
          glowColor.withValues(alpha: 0.80),
        ],
        stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
        transform: GradientRotation(rotation * 2 * pi),
      ).createShader(rect);
      canvas.drawArc(rect, start, prog, false, progPaint);

      final endAngle = start + prog;
      final end = Offset(
        center.dx + radius * cos(endAngle),
        center.dy + radius * sin(endAngle),
      );
      if (gi > 0) {
        final sparkGlow = Paint()
          ..color = (brightness == Brightness.light
                  ? AppTheme.lightTextPrimary
                  : Colors.white)
              .withValues(alpha: 0.7 * gi)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * gi);
        canvas.drawCircle(end, 7, sparkGlow);
      }
      canvas.drawCircle(
        end,
        4,
        Paint()
          ..color = brightness == Brightness.light
              ? AppTheme.lightTextPrimary
              : Colors.white,
      );
    }

    // Keep the center fully transparent so the value text doesn't look
    // "backlit" in either theme. (We still keep the arc/meter indicator glow.)
  }

  @override
  bool shouldRepaint(covariant _DialMeterGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.rotation != rotation;
  }

  double _degToRad(double deg) => deg * pi / 180.0;
}

class _GaugeStyleSwitch extends StatelessWidget {
  final EnvironmentGaugeStyle value;
  final ValueChanged<EnvironmentGaugeStyle> onChanged;

  const _GaugeStyleSwitch({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isMeter = value == EnvironmentGaugeStyle.meter;
    final isLight = Theme.of(context).brightness == Brightness.light;

    const activeColor = AppTheme.accentGreen;
    final inactiveBorder = isLight ? AppTheme.lightTextPrimary : Colors.white;
    final inactiveKnob = (isLight ? AppTheme.lightTextPrimary : Colors.white)
        .withValues(alpha: 0.85);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(
            isMeter ? EnvironmentGaugeStyle.arc : EnvironmentGaugeStyle.meter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: const Cubic(0.34, 1.56, 0.64, 1.0),
          width: 44,
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMeter ? activeColor : inactiveBorder,
              width: 1.5,
            ),
            color: Colors.transparent,
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 400),
            curve: const Cubic(0.34, 1.56, 0.64, 1.0),
            alignment: isMeter ? Alignment.centerRight : Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: const Cubic(0.34, 1.56, 0.64, 1.0),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isMeter ? activeColor : inactiveKnob,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
