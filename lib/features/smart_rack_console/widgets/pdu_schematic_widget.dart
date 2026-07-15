import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/smart_rack_console_snapshot.dart';

class PduSchematicWidget extends StatelessWidget {
  const PduSchematicWidget({
    super.key,
    required this.pduName,
    required this.expanded,
    required this.summaryRows,
    required this.outlets,
    required this.onToggleExpand,
  });

  final String pduName;
  final bool expanded;
  final List<ConsoleMetricRow> summaryRows;
  final List<Map<String, dynamic>> outlets;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final powerText = _rowValue(summaryRows, ['total power', 'load']) ??
        (pduName == 'PDU 1' ? '0.47 kW' : '0.68 kW');
    final currentText =
        _rowValue(summaryRows, ['total current', 'current']) ??
            (pduName == 'PDU 1' ? '2.2 A' : '3.1 A');

    final normalizedOutlets = outlets
        .where((item) => item['index'] != null)
        .map((item) => <String, dynamic>{
              'index': (item['index'] as num).toInt(),
              'isOn': item['isOn'] == true,
              'watts': (item['watts'] is num)
                  ? (item['watts'] as num).toDouble()
                  : double.tryParse(item['watts']?.toString() ?? '') ?? 0.0,
            })
        .toList()
      ..sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));

    final activeOutlets = normalizedOutlets
        .where((item) => item['isOn'] == true)
        .map((item) => item['index'] as int)
        .toList();

    const int totalOutlets = 16;
    final allOutlets = List.generate(totalOutlets, (i) => i + 1);
    final showing = expanded
        ? allOutlets
        : (activeOutlets.isNotEmpty ? activeOutlets : allOutlets);

    return Column(
      children: [
        // Top summary row with Power and Amps
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isLight ? Colors.white : const Color(0xFF0B0F14).withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isLight
                  ? Colors.black.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            children: [
              Text(
                pduName,
                style: TextStyle(
                  color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.bolt_rounded,
                size: 18,
                color: isLight ? const Color(0xFFFFB020) : const Color(0xFFFFD15C),
              ),
              const SizedBox(width: 6),
              Text(
                powerText,
                style: TextStyle(
                  color: isLight ? AppTheme.lightTextSecondary : Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.speed_rounded,
                size: 18,
                color: isLight ? const Color(0xFF2F7BFF) : const Color(0xFF7DB7FF),
              ),
              const SizedBox(width: 6),
              Text(
                currentText,
                style: TextStyle(
                  color: isLight ? AppTheme.lightTextSecondary : Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Outlet Grid
        Expanded(
          child: SingleChildScrollView(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                children: [
                  GridView.builder(
                    key: ValueKey<String>('${pduName}_${expanded}_${showing.length}'),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: showing.length,
                    itemBuilder: (context, idx) {
                      final n = showing[idx];
                      final isOn = activeOutlets.contains(n);
                      final watts = _wattsForOutlet(normalizedOutlets, n);
                      return _buildOutletTile(context, n, isOn, watts);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Expand/Collapse Toggle
                  InkWell(
                    borderRadius: BorderRadius.circular(100),
                    onTap: onToggleExpand,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            expanded ? 'COLLAPSE ALL' : 'EXPAND ALL',
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedRotation(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeInOutCubic,
                            turns: expanded ? 0.0 : 0.5,
                            child: const Icon(Icons.keyboard_arrow_up, color: Colors.orangeAccent),
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
      ],
    );
  }

  String? _rowValue(List<ConsoleMetricRow> rows, List<String> needles) {
    for (final row in rows) {
      final label = row.label.toLowerCase();
      if (needles.any(label.contains)) {
        return row.value;
      }
    }
    return null;
  }

  double _wattsForOutlet(List<Map<String, dynamic>> outlets, int index) {
    for (final outlet in outlets) {
      if (outlet['index'] == index) {
        final watts = outlet['watts'];
        if (watts is num) return watts.toDouble();
        return double.tryParse(watts?.toString() ?? '') ?? 0.0;
      }
    }
    return 0.0;
  }

  Widget _buildOutletTile(BuildContext context, int outletNum, bool isOn, double watts) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    const onFill = Color(0xFF00A174);
    const offFillLight = Color(0xFFD9D9D9);
    final offFillDark = Colors.white.withValues(alpha: 0.10);
    final fill = isOn ? onFill : (isLight ? offFillLight : offFillDark);

    const onText = Colors.white;
    const offTextLight = Color(0xFF555555);
    final offTextDark = Colors.white.withValues(alpha: 0.70);
    final text = isOn ? onText : (isLight ? offTextLight : offTextDark);

    final border = isLight
        ? Colors.black.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.12);

    const double maxWatts = 3000.0;
    final pct = (watts / maxWatts).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1.0),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'U$outletNum',
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          if (isOn) ...[
            Text(
              '${watts.round()}W',
              style: TextStyle(
                color: text,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${(pct * 100).round()}%',
              style: TextStyle(
                color: isLight
                    ? Colors.white.withValues(alpha: 0.90)
                    : text.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ] else
            Text(
              'OFF',
              style: TextStyle(
                color: text,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }
}
