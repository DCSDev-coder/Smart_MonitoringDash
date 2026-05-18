import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import 'dashboard_glass.dart';
import '../../features/dashboard/widgets/dashboard_typography.dart';

class NotificationsOverlay {
  static Future<void> show(
    BuildContext context, {
    required List<dynamic> alarms,
  }) {
    return Navigator.of(context).push<void>(
      _NotificationsOverlayRoute(alarms: alarms),
    );
  }
}

class _NotificationsOverlayRoute extends PopupRoute<void> {
  final List<dynamic> alarms;

  _NotificationsOverlayRoute({required this.alarms});

  @override
  Color get barrierColor => Colors.black.withValues(alpha: 0.65);

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => 'ALERTS';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 420);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _NotificationsOverlayPage(alarms: alarms);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved =
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    final scale = Tween<double>(begin: 0.96, end: 1.0).animate(curved);
    final slide =
        Tween<Offset>(begin: const Offset(0.0, -0.05), end: Offset.zero)
            .animate(curved);

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: ScaleTransition(
          scale: scale,
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
    );
  }
}

class _NotificationsOverlayPage extends StatefulWidget {
  final List<dynamic> alarms;

  const _NotificationsOverlayPage({required this.alarms});

  @override
  State<_NotificationsOverlayPage> createState() =>
      _NotificationsOverlayPageState();
}

class _NotificationsOverlayPageState extends State<_NotificationsOverlayPage> {
  final Set<int> _expanded = <int>{};

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final pad = media.padding;
    final isLight = Theme.of(context).brightness == Brightness.light;

    final maxW = (size.width - 32).clamp(280.0, 460.0);
    final maxH = (size.height - pad.vertical - 32).clamp(460.0, 820.0);

    final alarms = widget.alarms.whereType<Map>().toList()
      ..sort(
          (a, b) => _AlarmCard.timeEpoch(b).compareTo(_AlarmCard.timeEpoch(a)));

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 20), // Offset from the header
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
              child: DashboardGlass(
                radius: 30,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                tint: isLight
                    ? Colors.white
                    : const Color(0xFF0B0F14).withValues(alpha: 0.96),
                borderColor: isLight ? AppTheme.lightStroke : null,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.chevron_left_rounded,
                            color: isLight
                                ? AppTheme.lightTextPrimary
                                : Colors.white,
                            size: 34,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Notification',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: isLight
                                    ? AppTheme.lightTextPrimary
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (alarms.isEmpty)
                      const SizedBox(height: 140, child: _EmptyState())
                    else
                      // Always scroll: when many alerts are expanded, content can exceed
                      // maxHeight and would otherwise overflow.
                      Expanded(
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: alarms.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final a = alarms[i];
                            final open = _expanded.contains(i);
                            return _AlarmCard(
                              alarm: a,
                              expanded: open,
                              onToggle: () {
                                setState(() {
                                  if (open) {
                                    _expanded.remove(i);
                                  } else {
                                    _expanded.add(i);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Center(
      child: Text(
        'No Notification',
        style: TextStyle(
          color: isLight
              ? AppTheme.lightTextSecondary
              : Colors.white.withValues(alpha: 0.65),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeText({
    required this.text,
    required this.style,
  });

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  double _lastMaxWidth = -1;
  double _textWidth = 0;

  static const double _velocityPxPerSecond = 36;
  static const Duration _pause = Duration(milliseconds: 900);

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _configure(double maxWidth) {
    if (maxWidth <= 0) return;

    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      ellipsis: '…',
    )..layout();
    _textWidth = tp.width;

    final needsScroll = _textWidth > maxWidth + 1;
    if (!needsScroll) {
      _controller?.stop();
      return;
    }

    final distance = (_textWidth - maxWidth).clamp(0.0, double.infinity);
    final moveMs =
        ((distance / _velocityPxPerSecond) * 1000).round().clamp(600, 8000);
    final pauseMs = _pause.inMilliseconds.clamp(0, 4000);
    final totalMs = pauseMs + moveMs + pauseMs;

    if (_controller == null ||
        _controller!.duration?.inMilliseconds != totalMs) {
      _controller?.dispose();
      _controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: totalMs),
      )..repeat();
    } else if (!_controller!.isAnimating) {
      _controller!.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        if (maxW.isFinite && (maxW - _lastMaxWidth).abs() > 0.5) {
          _lastMaxWidth = maxW;
          _configure(maxW);
        }

        // If it fits, render as a normal single-line title.
        if (!maxW.isFinite || _textWidth <= maxW + 1) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        final controller = _controller;
        if (controller == null) {
          // Fallback while controller config catches up.
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        final distance = (_textWidth - maxW).clamp(0.0, double.infinity);
        final pauseMs = _pause.inMilliseconds.toDouble();
        final moveMs = (controller.duration!.inMilliseconds - pauseMs * 2);

        return ClipRect(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final t = controller.value * controller.duration!.inMilliseconds;
              double x = 0;
              if (t <= pauseMs) {
                x = 0;
              } else if (t >= pauseMs + moveMs) {
                x = -distance;
              } else {
                final u = (t - pauseMs) / moveMs;
                x = -distance *
                    Curves.easeInOutSine.transform(u.clamp(0.0, 1.0));
              }
              return Transform.translate(
                offset: Offset(x, 0),
                child: Text(widget.text, style: widget.style, maxLines: 1),
              );
            },
          ),
        );
      },
    );
  }
}

class _AlarmCard extends StatelessWidget {
  final Map alarm;
  final bool expanded;
  final VoidCallback onToggle;

  const _AlarmCard({
    required this.alarm,
    required this.expanded,
    required this.onToggle,
  });

  static Color _levelColor(String level) {
    final s = level.trim().toLowerCase();
    if (s.isEmpty) {
      return const Color.fromARGB(255, 28, 78, 159); // info default
    }
    if (s.contains('info')) {
      return const Color.fromARGB(255, 34, 94, 190);
    }
    if (s.contains('good') || s.contains('normal') || s.contains('ok')) {
      return const Color.fromARGB(255, 0, 153, 36);
    }
    if (s.contains('moderate') ||
        s.contains('warning') ||
        s.contains('minor')) {
      return const Color.fromARGB(255, 146, 122, 42);
    }
    if (s.contains('critical') || s.contains('major')) {
      return const Color.fromARGB(255, 145, 79, 25);
    }
    if (s.contains('red') || s.contains('emergency') || s.contains('severe')) {
      return const Color.fromARGB(255, 155, 33, 26);
    }
    return const Color(0xFF2D7DFF);
  }

  static IconData _alarmIcon(String itemOrTitle) {
    final t = itemOrTitle.toUpperCase();
    if (t.contains('TEMP')) {
      return Icons.thermostat_rounded;
    }
    if (t.contains('HUM')) {
      return Icons.water_drop_rounded;
    }
    if (t.contains('SMOKE') || t.contains('FIRE')) {
      return Icons.local_fire_department_rounded;
    }
    if (t.contains('FLOOD') || t.contains('LEAK') || t.contains('WATER')) {
      return Icons.water_damage_rounded;
    }
    if (t.contains('UPS') || t.contains('BAT')) {
      return Icons.battery_alert_rounded;
    }
    if (t.contains('PDU') || t.contains('POWER')) {
      return Icons.bolt_rounded;
    }
    if (t.contains('AC')) {
      return Icons.ac_unit_rounded;
    }
    return Icons.notifications_rounded;
  }

  static String _title(Map a) {
    final node = (a['collectControlNodeName'] ?? '').toString().trim();
    final content = (a['content'] ?? '').toString().trim();
    final candidate = node.isNotEmpty ? node : content;
    if (candidate.isEmpty) {
      return 'ALARM';
    }

    // Keep the title short like the mock (no location).
    final upper = candidate.toUpperCase();
    if (upper.contains('TEMP') && upper.contains('HUM')) {
      return 'TEMP/HUM ISSUE';
    }
    if (upper.contains('TEMP')) {
      return 'TEMP ISSUE';
    }
    if (upper.contains('HUM')) {
      return 'HUMIDITY ISSUE';
    }
    if (upper.contains('SMOKE')) {
      return 'SMOKE ALERT';
    }
    if (upper.contains('FLOOD') || upper.contains('LEAK')) {
      return 'LEAK ALERT';
    }
    if (upper.contains('UPS')) {
      return 'UPS ISSUE';
    }
    if (upper.contains('PDU')) {
      return 'PDU ISSUE';
    }
    return candidate.length > 22
        ? '${candidate.substring(0, 22)}...'
        : candidate;
  }

  static String _alarmLevel(Map a) {
    final v =
        (a['alarmLevelLevel'] ?? a['alarmLevel'] ?? a['level'] ?? a['severity'])
            ?.toString();
    return (v ?? '').trim();
  }

  static String _alarmType(Map a) {
    final v =
        (a['alarmTypeType'] ?? a['alarmType'] ?? a['type'] ?? a['alarmItem'])
            ?.toString();
    final s = (v ?? '').trim();
    if (s.isEmpty) {
      return 'Alarm';
    }
    return s;
  }

  static String? _alarmSource(Map a) {
    final raw = (a['collectControlNodeName'] ??
            a['cabinetName'] ??
            a['nodeName'] ??
            a['node'] ??
            '')
        .toString()
        .trim();
    if (raw.isEmpty) return null;

    // We don't show "Location:" phrasing; keep it short like the mock.
    var s = raw.replaceAll(
        RegExp(r'^\s*location\s*:\s*', caseSensitive: false), '');
    // Trim "Cabinet " prefix if present so it reads like "Front 1".
    s = s.replaceAll(RegExp(r'^\s*cabinet\s+', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return null;
    return s.length > 40 ? '${s.substring(0, 40)}...' : s;
  }

  static String _valueWithUnit(Map a) {
    final v = _alarmValue(a);
    if (v == '--') return v;

    // If the backend already includes a unit, don't add one.
    final upper = v.toUpperCase();
    if (upper.contains('%') ||
        upper.contains('C') ||
        upper.contains('V') ||
        upper.contains('A') ||
        upper.contains('W')) {
      return v;
    }

    final item = _alarmItem(a);
    if (item == 'TEMPERATURE') return '$v C';
    if (item == 'HUMIDITY') return '$v %';
    return v;
  }

  static List<String> _commaBulletLines(Map a) {
    final out = <String>[];

    // 1) Start with the most "numeric" signal if we have it.
    final v = _valueWithUnit(a);
    if (v != '--') {
      out.add(v);
    }

    // 2) Then split the backend content into readable bullets.
    // The old behavior treated commas as "next point".
    final raw =
        (a['content'] ?? a['alarmMsg'] ?? a['message'] ?? '').toString().trim();
    if (raw.isNotEmpty) {
      final cleaned = raw
          .replaceAll(
            RegExp(r'[, ]*Alarm\s*Value\s*:\s*[^,]+', caseSensitive: false),
            '',
          )
          .replaceAll(
            RegExp(r'[, ]*Alarm\s*Type\s*:\s*[^,]+', caseSensitive: false),
            '',
          )
          .replaceAll(
            RegExp(r'[, ]*Alarm\s*Level\s*:\s*[^,]+', caseSensitive: false),
            '',
          )
          .trim();

      final parts = cleaned
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      for (final p in parts) {
        final s = p.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (s.isEmpty) continue;
        if (!out.any((x) => x.toLowerCase() == s.toLowerCase())) {
          out.add(s);
        }
      }
    }

    // 3) Add source (cabinet/node) if it's not already in the bullets.
    final src = _alarmSource(a);
    if (src != null && !out.any((x) => x.toLowerCase() == src.toLowerCase())) {
      out.add(src);
    }

    // 4) Time last (keep the list scannable).
    final time = _timeText(a);
    if (time != '--' && !out.contains(time)) {
      out.add(time);
    }

    // If everything is empty, keep at least one placeholder.
    if (out.isEmpty) {
      out.add('--');
    }
    return out;
  }

  static DateTime? _parseTime(dynamic raw) {
    if (raw is int) {
      // Heuristic: treat large values as millis.
      return raw > 2000000000
          ? DateTime.fromMillisecondsSinceEpoch(raw)
          : DateTime.fromMillisecondsSinceEpoch(raw * 1000);
    }
    if (raw is num) {
      final v = raw.toInt();
      return v > 2000000000
          ? DateTime.fromMillisecondsSinceEpoch(v)
          : DateTime.fromMillisecondsSinceEpoch(v * 1000);
    }
    if (raw == null) {
      return null;
    }

    final s = raw.toString().trim();
    if (s.isEmpty) {
      return null;
    }

    // Common backend formats:
    // - "2026-03-01 11:02:03"
    // - "2026-03-01T11:02:03"
    // - "2026-03-01T11:02:03.123Z"
    final normalized =
        s.contains(' ') && !s.contains('T') ? s.replaceFirst(' ', 'T') : s;
    return DateTime.tryParse(normalized) ?? DateTime.tryParse(s);
  }

  static int timeEpoch(Map a) {
    final dynamic raw = a['occurrenceTime'] ??
        a['occurrence_time'] ??
        a['createTime'] ??
        a['time'] ??
        a['timestamp'];
    final dt = _parseTime(raw);
    if (dt != null) {
      return dt.millisecondsSinceEpoch;
    }
    return 0;
  }

  static String _alarmValue(Map a) {
    final dynamic v = a['alarmValueValue'] ??
        a['alarmValue'] ??
        a['value'] ??
        a['alarm_value'];
    if (v == null) {
      return '--';
    }
    final s = v.toString().trim();
    return s.isEmpty ? '--' : s;
  }

  static String _alarmItem(Map a) {
    // "Alarm Item" is the displayed item header above the bullets.
    final content = (a['content'] ?? '').toString().trim().toUpperCase();
    if (content.contains('TEMP') && content.contains('HUM')) {
      return 'TEMP/HUM';
    }
    if (content.contains('TEMP')) {
      return 'TEMPERATURE';
    }
    if (content.contains('HUM')) {
      return 'HUMIDITY';
    }
    if (content.contains('SMOKE')) {
      return 'SMOKE';
    }
    if (content.contains('FLOOD') ||
        content.contains('LEAK') ||
        content.contains('WATER')) {
      return 'LEAK';
    }
    if (content.contains('UPS')) {
      return 'UPS';
    }
    if (content.contains('PDU')) {
      return 'PDU';
    }
    return _alarmType(a).toUpperCase();
  }

  static String _timeText(Map a) {
    final dynamic raw = a['occurrenceTime'] ??
        a['occurrence_time'] ??
        a['createTime'] ??
        a['time'] ??
        a['timestamp'];
    final dt = _parseTime(raw);
    if (dt == null) {
      return '--';
    }
    return DateFormat('dd/MM/yyyy hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final title = _title(alarm);
    final level = _alarmLevel(alarm);
    final color = _levelColor(level);
    final icon = _alarmIcon(title);
    final item = expanded ? _alarmItem(alarm) : 'ALARM';
    final value = expanded ? _valueWithUnit(alarm) : '--';
    final time = _timeText(alarm);
    final bulletLines = _commaBulletLines(alarm);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isResolved = level.trim().toLowerCase().contains('resolved');
    final cardColor = isLight
        ? (isResolved ? const Color(0xFF2A6EEB) : const Color(0xFFF36A2B))
        : color.withValues(alpha: expanded ? 0.22 : 0.18);
    final borderColor = isLight
        ? (isResolved ? const Color(0xFF004DFF) : const Color(0xFFFF3A30))
        : color.withValues(alpha: 0.45);
    final accentColor = isLight
        ? (isResolved ? const Color(0xFF1E2FFF) : const Color(0xFFFF402F))
        : color;
    final shadowColor = isLight
        ? borderColor.withValues(alpha: 0.35)
        : color.withValues(alpha: 0.18);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onToggle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isLight
                            ? const Color(0x26FFFFFF)
                            : accentColor.withValues(alpha: 0.30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: const Color(0xFFFFFFFF),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: expanded
                          ? Text(
                              title,
                              style: bitcount(
                                context,
                                fontSize: 16,
                                color: Colors.white,
                                letterSpacing: 0.4,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : _MarqueeText(
                              text: title,
                              style: bitcount(
                                context,
                                fontSize: 16,
                                color: Colors.white,
                                letterSpacing: 0.4,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.chevron_right_rounded,
                      color: const Color(0xFFFFFFFF),
                      size: 30,
                    ),
                  ],
                ),
                if (!expanded) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0x33000000),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                    [
                      item,
                      value == '--' ? null : value,
                      time == '--' ? null : time,
                    ].whereType<String>().join('  •  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
                if (expanded) ...[
                  const SizedBox(height: 10),
                  for (final line in bulletLines)
                    _Bullet(
                      text: line,
                      lightMode: isLight,
                    ),
                ],
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: borderColor,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: isLight ? 14 : 22,
                    spreadRadius: isLight ? 0 : 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  final bool lightMode;

  const _Bullet({
    required this.text,
    required this.lightMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: lightMode ? 0.92 : 0.85),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
