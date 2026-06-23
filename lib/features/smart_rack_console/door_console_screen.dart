import 'dart:async';

import 'package:flutter/material.dart';

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

  Map<String, dynamic>? _doorAt(int index) {
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

  Future<bool> _handleUnlockDoor(int id, String name) async {
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
    Map<String, dynamic>? door,
  ) {
    final name = _doorLabel(door, defaultLabel);
    final id = int.tryParse(door?['id']?.toString() ?? '') ?? 0;
    final isUnlocked = door?['isOpen'] == true;
    final enabled = id != 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom: 16),
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
        0: FlexColumnWidth(2.5),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: ConsoleTheme.primaryBlue(context).withValues(alpha: 0.2),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          ),
          children: [
            _headerCell('Date and time'),
            _headerCell('Door'),
            _headerCell('User'),
          ],
        ),
        ...logs.take(15).map((log) {
          final time = log['opTime']?.toString() ?? log['time']?.toString() ?? '--';
          
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
    final leftDoor = _doorAt(0);
    final rightDoor = _doors.length > 1 ? _doorAt(_doors.length - 1) : leftDoor;

    final double width = MediaQuery.of(context).size.width;
    final isNarrow = width < 768;

    final doorAccessCard = ConsoleSectionCard(
      title: 'Door Access',
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildHorizontalDoorRow(context, 'Front Door', leftDoor),
            _buildHorizontalDoorRow(context, 'Rear Door', rightDoor),
          ],
        ),
      ),
    );

    final logsCard = ConsoleSectionCard(
      title: 'Door Access Logs',
      child: _buildRecentLogsTable(context),
    );

    if (isNarrow) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(ConsoleTheme.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            doorAccessCard,
            const SizedBox(height: ConsoleTheme.lg),
            logsCard,
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(ConsoleTheme.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: doorAccessCard,
          ),
          const SizedBox(width: ConsoleTheme.lg),
          Expanded(
            flex: 6,
            child: logsCard,
          ),
        ],
      ),
    );
  }
}
