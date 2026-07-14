import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config/site_runtime_config.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/utils/app_log.dart';
import '../dashboard/widgets/door_control_section.dart';
import 'models/smart_rack_console_snapshot.dart';
import 'theme/console_theme.dart';
import 'widgets/console_section_card.dart';

class DoorConsoleScreen extends StatefulWidget {
  const DoorConsoleScreen({
    super.key,
    required this.snapshot,
  });

  final SmartRackConsoleSnapshot snapshot;

  @override
  State<DoorConsoleScreen> createState() => _DoorConsoleScreenState();
}

class _DoorConsoleScreenState extends State<DoorConsoleScreen> {
  final Map<int, Timer> _unlockTimers = <int, Timer>{};
  final Set<int> _localUnlocked = <int>{};
  final Set<int> _unlockingDoors = <int>{};

  List<Map<String, dynamic>> get _doors => widget.snapshot.doors;

  @override
  void dispose() {
    for (final timer in _unlockTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  Map<String, dynamic>? _doorBySemanticName(List<String> keywords) {
    for (final door in _doors) {
      final name =
          (door['accessName'] ?? door['name'] ?? '').toString().toLowerCase();
      if (keywords.any(name.contains)) {
        return door;
      }
    }
    return null;
  }

  Map<String, dynamic>? _doorByFallbackIndex(int index) {
    if (_doors.isEmpty) return null;
    if (index < _doors.length) return _doors[index];
    return _doors.last;
  }

  String _doorLabel(Map<String, dynamic>? door, String fallback) {
    if (door == null) return fallback;
    final name = (door['accessName'] ?? door['name'] ?? '').toString().trim();
    if (name.isEmpty) return fallback;

    final lower = name.toLowerCase();
    if (lower.contains('front')) return 'Front Door';
    if (lower.contains('rear') || lower.contains('back')) return 'Back Door';
    return name;
  }

  String _doorPosition(Map<String, dynamic>? door, String fallback) {
    final label = _doorLabel(door, fallback).toLowerCase();
    if (label.contains('front')) return 'Front';
    if (label.contains('back') || label.contains('rear')) return 'Back';
    return fallback;
  }

  int _doorId(Map<String, dynamic>? door) {
    if (door == null) return 0;
    final dynamic idRaw = door['id'] ?? door['accessId'] ?? door['access_id'];
    if (idRaw is num) return idRaw.toInt();
    return int.tryParse(idRaw?.toString() ?? '') ?? 0;
  }

  bool _isDoorUnlocked(Map<String, dynamic>? door) {
    final id = _doorId(door);
    if (id != 0 && _localUnlocked.contains(id)) return true;
    return door?['isOpen'] == true;
  }

  Future<void> _unlockDoor(
      Map<String, dynamic>? door, String fallbackLabel) async {
    final id = _doorId(door);
    final name = _doorLabel(door, fallbackLabel);
    if (id == 0) return;
    if (_unlockingDoors.contains(id)) return;

    AppLog.d(
      'Rack Console unlock requested',
      tag: 'RackConsoleDoor',
      fields: {'doorId': id, 'doorName': name, 'doorCount': _doors.length},
    );

    setState(() {
      _unlockingDoors.add(id);
    });

    try {
      final siteId =
          SiteRuntimeConfig.siteId(CpanelApiService.instance.currentSite);
      final authorized = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => UnlockDoorSheet(
          doorId: id,
          doorName: name,
          isRackConsoleStyle: true,
          siteId: siteId,
        ),
      );

      if (authorized != true || !mounted) return;

      setState(() {
        _localUnlocked.add(id);
      });

      _unlockTimers[id]?.cancel();
      _unlockTimers[id] = Timer(const Duration(seconds: 5), () {
        if (!mounted) return;
        setState(() {
          _localUnlocked.remove(id);
        });
      });
    } finally {
      if (mounted) {
        setState(() {
          _unlockingDoors.remove(id);
        });
      } else {
        _unlockingDoors.remove(id);
      }
    }
  }

  String _formatLogDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  String _formatLogTime(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('hh:mm:ss a').format(dt);
  }

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _dataCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }

  Widget _buildRecentLogsTable(BuildContext context) {
    final logs = widget.snapshot.recentDoorLogs;

    if (logs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No recent door access logs',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.6),
        1: FlexColumnWidth(1.4),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(1.7),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: ConsoleTheme.primaryBlue(context).withValues(alpha: 0.16),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          children: [
            _headerCell('Date'),
            _headerCell('Time'),
            _headerCell('Door'),
            _headerCell('User'),
          ],
        ),
        ...logs.take(12).map((log) {
          final rawTime =
              log['opTime']?.toString() ?? log['time']?.toString() ?? '--';
          final date = rawTime == '--' ? rawTime : _formatLogDate(rawTime);
          final time = rawTime == '--' ? rawTime : _formatLogTime(rawTime);

          var door = log['accessName']?.toString() ??
              log['doorName']?.toString() ??
              '--';
          final lowerDoor = door.toLowerCase();
          if (lowerDoor.contains('front')) {
            door = 'Front Door';
          } else if (lowerDoor.contains('rear') || lowerDoor.contains('back')) {
            door = 'Back Door';
          }

          final user = log['opUser']?.toString() ??
              log['openUser']?.toString() ??
              log['userName']?.toString() ??
              log['username']?.toString() ??
              log['user']?.toString() ??
              '--';

          return TableRow(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            children: [
              _dataCell(date),
              _dataCell(time),
              _dataCell(door),
              _dataCell(user),
            ],
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final frontDoor = _doorBySemanticName(const ['front', 'front door']) ??
        _doorByFallbackIndex(0);
    final backDoor = _doorBySemanticName(const ['rear', 'back', 'back door']) ??
        (_doors.length > 1
            ? _doorByFallbackIndex(_doors.length - 1)
            : frontDoor);

    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isNarrow = width < 1024;
    final isShort = height < 530;

    final topSection = isNarrow
        ? Column(
            children: [
              _DoorAccessPanel(
                doorLabel: _doorLabel(frontDoor, 'Front Door'),
                positionLabel: _doorPosition(frontDoor, 'Front'),
                isUnlocked: _isDoorUnlocked(frontDoor),
                enabled: _doorId(frontDoor) != 0,
                busy: _unlockingDoors.contains(_doorId(frontDoor)),
                onUnlock: () => _unlockDoor(frontDoor, 'Front Door'),
              ),
              const SizedBox(height: ConsoleTheme.lg),
              _DoorAccessPanel(
                doorLabel: _doorLabel(backDoor, 'Back Door'),
                positionLabel: _doorPosition(backDoor, 'Back'),
                isUnlocked: _isDoorUnlocked(backDoor),
                enabled: _doorId(backDoor) != 0,
                busy: _unlockingDoors.contains(_doorId(backDoor)),
                onUnlock: () => _unlockDoor(backDoor, 'Back Door'),
              ),
            ],
          )
        : IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _DoorAccessPanel(
                    doorLabel: _doorLabel(frontDoor, 'Front Door'),
                    positionLabel: _doorPosition(frontDoor, 'Front'),
                    isUnlocked: _isDoorUnlocked(frontDoor),
                    enabled: _doorId(frontDoor) != 0,
                    busy: _unlockingDoors.contains(_doorId(frontDoor)),
                    onUnlock: () => _unlockDoor(frontDoor, 'Front Door'),
                  ),
                ),
                const SizedBox(width: ConsoleTheme.lg),
                Expanded(
                  child: _DoorAccessPanel(
                    doorLabel: _doorLabel(backDoor, 'Back Door'),
                    positionLabel: _doorPosition(backDoor, 'Back'),
                    isUnlocked: _isDoorUnlocked(backDoor),
                    enabled: _doorId(backDoor) != 0,
                    busy: _unlockingDoors.contains(_doorId(backDoor)),
                    onUnlock: () => _unlockDoor(backDoor, 'Back Door'),
                  ),
                ),
              ],
            ),
          );

    return Padding(
      padding: const EdgeInsets.all(ConsoleTheme.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          topSection,
          const SizedBox(height: ConsoleTheme.lg),
          if (isShort)
            ConsoleSectionCard(
              title: 'Door Access Logs',
              expand: false,
              trailing: TextButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('View Logs'),
                style: TextButton.styleFrom(
                  foregroundColor: ConsoleTheme.cyan(context),
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => Container(
                      decoration: BoxDecoration(
                        gradient: ConsoleTheme.cardBgGradient(context),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24)),
                        border:
                            Border.all(color: ConsoleTheme.cardBorder(context)),
                      ),
                      padding: const EdgeInsets.all(24),
                      constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Door Access Logs',
                                  style: TextStyle(
                                      color: ConsoleTheme.textPrimary(context),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              IconButton(
                                  icon: Icon(Icons.close,
                                      color: ConsoleTheme.textPrimary(context)),
                                  onPressed: () => Navigator.pop(ctx)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: SingleChildScrollView(
                              child: _buildRecentLogsTable(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              child: const SizedBox.shrink(),
            )
          else
            Expanded(
              child: ConsoleSectionCard(
                title: 'Door Access Logs',
                expand: true,
                trailing: TextButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('View Logs'),
                  style: TextButton.styleFrom(
                    foregroundColor: ConsoleTheme.cyan(context),
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => Container(
                        decoration: BoxDecoration(
                          gradient: ConsoleTheme.cardBgGradient(context),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24)),
                          border: Border.all(
                              color: ConsoleTheme.cardBorder(context)),
                        ),
                        padding: const EdgeInsets.all(24),
                        constraints: BoxConstraints(
                            maxHeight:
                                MediaQuery.of(context).size.height * 0.8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Door Access Logs',
                                    style: TextStyle(
                                        color:
                                            ConsoleTheme.textPrimary(context),
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                IconButton(
                                    icon: Icon(Icons.close,
                                        color:
                                            ConsoleTheme.textPrimary(context)),
                                    onPressed: () => Navigator.pop(ctx)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: SingleChildScrollView(
                                child: _buildRecentLogsTable(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                child: SingleChildScrollView(
                  child: _buildRecentLogsTable(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DoorAccessPanel extends StatelessWidget {
  const _DoorAccessPanel({
    required this.doorLabel,
    required this.positionLabel,
    required this.isUnlocked,
    required this.enabled,
    required this.busy,
    required this.onUnlock,
  });

  final String doorLabel;
  final String positionLabel;
  final bool isUnlocked;
  final bool enabled;
  final bool busy;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return ConsoleSectionCard(
      minHeight: 120,
      expand: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doorLabel,
                    style: TextStyle(
                      color: ConsoleTheme.textPrimary(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isUnlocked ? 'Status: Opened' : 'Status: Closed',
                    style: TextStyle(
                      color: isUnlocked
                          ? ConsoleTheme.success(context)
                          : ConsoleTheme.textSecondary(context),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            _HoldToConfirmButton(
              isUnlocked: isUnlocked,
              enabled: enabled,
              busy: busy,
              onUnlock: onUnlock,
              isLight: isLight,
            ),
          ],
        ),
      ),
    );
  }
}

class _DoorGlyph extends StatefulWidget {
  const _DoorGlyph({required this.isUnlocked, required this.accent});

  final bool isUnlocked;
  final Color accent;

  @override
  State<_DoorGlyph> createState() => _DoorGlyphState();
}

class _DoorGlyphState extends State<_DoorGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
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
      builder: (context, _) {
        final pulse = 0.14 + (_controller.value * 0.16);
        return Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                widget.accent.withValues(alpha: pulse + 0.18),
                widget.accent.withValues(alpha: 0.10),
                Colors.transparent,
              ],
            ),
            border: Border.all(
              color: widget.accent.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: pulse),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              widget.isUnlocked
                  ? Icons.lock_open_rounded
                  : Icons.lock_outline_rounded,
              key: ValueKey<bool>(widget.isUnlocked),
              color: Colors.white,
              size: 38,
            ),
          ),
        );
      },
    );
  }
}

class _ConsoleUnlockButton extends StatefulWidget {
  const _ConsoleUnlockButton({
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final String label;
  final VoidCallback? onPressed;

  @override
  State<_ConsoleUnlockButton> createState() => _ConsoleUnlockButtonState();
}

class _ConsoleUnlockButtonState extends State<_ConsoleUnlockButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = !widget.enabled || widget.onPressed == null;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(999),
            child: Ink(
              decoration: BoxDecoration(
                color: disabled ? Colors.white.withValues(alpha: 0.08) : null,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: disabled
                      ? Colors.white.withValues(alpha: 0.10)
                      : ConsoleTheme.cyan(context).withValues(alpha: 0.30),
                ),
                boxShadow: disabled
                    ? null
                    : [
                        BoxShadow(
                          color: ConsoleTheme.cyan(context)
                              .withValues(alpha: 0.18),
                          blurRadius: 22,
                          spreadRadius: 2,
                        ),
                      ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!disabled)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.32,
                        child: Transform.translate(
                          offset: Offset(_controller.value * 240 - 90, 0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.14),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: disabled
                            ? Colors.white54
                            : ConsoleTheme.textInverse(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HoldToConfirmButton extends StatefulWidget {
  final bool isUnlocked;
  final bool enabled;
  final bool busy;
  final VoidCallback onUnlock;
  final bool isLight;

  const _HoldToConfirmButton({
    required this.isUnlocked,
    required this.enabled,
    required this.busy,
    required this.onUnlock,
    required this.isLight,
  });

  @override
  State<_HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<_HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _successFlash = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _successFlash = true);
        widget.onUnlock();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() => _successFlash = false);
            _controller.reset();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(_) {
    if (widget.enabled && !widget.isUnlocked && !widget.busy) {
      _controller.forward(from: 0.0);
    }
  }

  void _onPointerUp(_) {
    if (!_controller.isCompleted) {
      _controller.value = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onPointerDown,
      onTapUp: _onPointerUp,
      onTapCancel: () => _onPointerUp(null),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final showSuccess = _successFlash || widget.isUnlocked;
          final bgColor = widget.isLight
              ? const Color(0xFFF1F5F9)
              : Colors.white.withValues(alpha: 0.1);
          final progressColor = ConsoleTheme.cyan(context);
          final successColor = ConsoleTheme.success(context);

          return SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _RingProgressPainter(
                progress: _controller.value,
                ringColor: showSuccess ? successColor : progressColor,
                bgColor: bgColor,
              ),
              child: Center(
                child: widget.busy
                    ? const CircularProgressIndicator()
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: Icon(
                          widget.isUnlocked
                              ? Icons.lock_open_rounded
                              : Icons.lock_outline_rounded,
                          key: ValueKey<bool>(widget.isUnlocked),
                          color: showSuccess
                              ? successColor
                              : (widget.isLight
                                  ? Colors.black54
                                  : Colors.white70),
                          size: 38,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingProgressPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color bgColor;

  _RingProgressPainter({
    required this.progress,
    required this.ringColor,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    if (progress > 0.0) {
      final ringPaint = Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 2.0),
        -3.141592653589793 / 2,
        2 * 3.141592653589793 * progress,
        false,
        ringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.bgColor != bgColor;
  }
}
