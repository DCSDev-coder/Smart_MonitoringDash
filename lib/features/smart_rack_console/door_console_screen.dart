import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  List<Map<String, dynamic>> get _doors => widget.snapshot.doors;

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
    if (name.isNotEmpty) return name;
    return fallback;
  }

  int _doorId(Map<String, dynamic>? door) {
    if (door == null) return 0;
    final dynamic idRaw = door['id'] ?? door['accessId'] ?? door['access_id'];
    if (idRaw is num) return idRaw.toInt();
    return int.tryParse(idRaw?.toString() ?? '') ?? 0;
  }

  String _formatLogDateTime(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('yyyy-MM-dd hh:mm:ss a').format(dt);
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

  Future<bool> _handleUnlockDoor(int id, String name) async {
    AppLog.d(
      'Rack Console unlock requested',
      tag: 'RackConsoleDoor',
      fields: {'doorId': id, 'doorName': name, 'doorCount': _doors.length},
    );
    final authorized = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UnlockDoorSheet(doorId: id, doorName: name),
    );

    if (authorized == true) {
      return true;
    }
    return false;
  }

  Widget _buildHorizontalDoorRow(
    BuildContext context,
    String defaultLabel,
    Map<String, dynamic>? door, {
    double bottomMargin = 16,
  }) {
    final name = _doorLabel(door, defaultLabel);
    final id = _doorId(door);
    final isUnlocked = door?['isOpen'] == true;
    final enabled = id != 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: EdgeInsets.only(bottom: bottomMargin),
      decoration: BoxDecoration(
        color: ConsoleTheme.panelBg(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isUnlocked 
                ? ConsoleTheme.success(context).withValues(alpha: 0.2) 
                : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
              color: isUnlocked ? ConsoleTheme.success(context) : Colors.white70,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 140,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isUnlocked ? ConsoleTheme.success(context) : ConsoleTheme.primaryBlue(context),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: enabled ? () => _handleUnlockDoor(id, name) : null,
              child: Text(
                isUnlocked ? 'UNLOCKED' : 'UNLOCK',
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentLogsTable(BuildContext context) {
    final logs = widget.snapshot.recentDoorLogs;
    
    if (logs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
          child: Text('No recent door access logs', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.7),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(1.3),
        3: FlexColumnWidth(1.7),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: ConsoleTheme.primaryBlue(context).withValues(alpha: 0.2),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          ),
          children: [
            _headerCell('Date'),
            _headerCell('Time'),
            _headerCell('Door'),
            _headerCell('User'),
          ],
        ),
        ...logs.take(15).map((log) {
          final rawTime =
              log['opTime']?.toString() ?? log['time']?.toString() ?? '--';
          final date = rawTime == '--' ? rawTime : _formatLogDate(rawTime);
          final time = rawTime == '--' ? rawTime : _formatLogTime(rawTime);
          
          String door = log['accessName']?.toString() ?? log['doorName']?.toString() ?? '--';
          if (door != '--') {
            final lower = door.toLowerCase();
            if (lower.contains('front')) {
              door = 'Front 1';
            } else if (lower.contains('rear') || lower.contains('back')) {
              door = 'Rear 1';
            }
          }
          
          final user = log['opUser']?.toString() ?? log['openUser']?.toString() ?? log['userName']?.toString() ?? log['username']?.toString() ?? log['user']?.toString() ?? '--';
          
          return TableRow(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
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

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _dataCell(String text, {bool isStatus = false}) {
    Color color = Colors.white70;
    if (isStatus) {
      final s = text.toLowerCase();
      if (s.contains('success') || s.contains('unlock') || s == '1' || s.contains('open')) {
        color = Colors.greenAccent;
        text = 'Success';
      } else if (s.contains('fail') || s.contains('denied') || s == '0') {
        color = Colors.redAccent;
        text = 'Failed';
      }
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 13),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leftDoor = _doorBySemanticName(const ['front', 'front door']) ??
        _doorByFallbackIndex(0);
    final rightDoor = _doorBySemanticName(const ['rear', 'back', 'rear door']) ??
        (_doors.length > 1 ? _doorByFallbackIndex(_doors.length - 1) : leftDoor);

    final double width = MediaQuery.of(context).size.width;
    final isNarrow = width < 768;

    final frontDoorCard = ConsoleSectionCard(
      title: 'Front Door Access',
      child: _buildHorizontalDoorRow(context, 'Front Door', leftDoor, bottomMargin: 0),
    );

    final rearDoorCard = ConsoleSectionCard(
      title: 'Rear Door Access',
      child: _buildHorizontalDoorRow(context, 'Rear Door', rightDoor, bottomMargin: 0),
    );

    final logsCard = ConsoleSectionCard(
      title: 'Door Access Logs',
      expand: true,
      child: SingleChildScrollView(
        child: _buildRecentLogsTable(context),
      ),
    );

    if (isNarrow) {
      return Padding(
        padding: const EdgeInsets.all(ConsoleTheme.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            frontDoorCard,
            const SizedBox(height: ConsoleTheme.lg),
            rearDoorCard,
            const SizedBox(height: ConsoleTheme.lg),
            Expanded(child: logsCard),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(ConsoleTheme.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: frontDoorCard),
              const SizedBox(width: ConsoleTheme.lg),
              Expanded(child: rearDoorCard),
            ],
          ),
          const SizedBox(height: ConsoleTheme.lg),
          Expanded(child: logsCard),
        ],
      ),
    );
  }
}
