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
    final statusText =
        _rowValue(summaryRows, ['offline state', 'status']) ??
            'Normal';
    final powerText = _rowValue(summaryRows, [
          'active power',
          'total power',
          'load',
        ]) ??
        (pduName == 'PDU 1' ? '0.47 kW' : '0.68 kW');
    final currentText =
        _rowValue(summaryRows, ['current']) ??
            (pduName == 'PDU 1' ? '2.2 A' : '3.1 A');
    final energyText =
        _rowValue(summaryRows, ['total energy', 'energy']) ?? '--';

    final normalizedOutlets = outlets
        .where((item) => item['index'] != null)
        .map((item) => <String, dynamic>{
              'index': (item['index'] as num).toInt(),
              'isOn': item['isOn'] == true,
              'hasReading': item['hasReading'] == true,
              'watts': (item['watts'] is num)
                  ? (item['watts'] as num).toDouble()
                  : double.tryParse(item['watts']?.toString() ?? '') ?? 0.0,
            })
        .toList()
      ..sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));

    final readingOutlets = normalizedOutlets
        .where((item) => item['hasReading'] == true)
        .map((item) => item['index'] as int)
        .toList();
    final outletsText = _outletsSummary(normalizedOutlets);

    const int totalOutlets = 16;
    final allOutlets = List.generate(totalOutlets, (i) => i + 1);
    final showing = expanded
        ? allOutlets
        : readingOutlets;

    return Column(
      children: [
        // Top summary row with status and PDU power summary
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                  _buildStatusPill(
                    statusText,
                    isLight: isLight,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryStat(
                      context,
                      label: 'Active Power',
                      value: powerText,
                      icon: Icons.bolt_rounded,
                      accent: const Color(0xFFFFB020),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryStat(
                      context,
                      label: 'Current',
                      value: currentText,
                      icon: Icons.speed_rounded,
                      accent: const Color(0xFF2F7BFF),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryStat(
                      context,
                      label: 'Energy',
                      value: energyText,
                      icon: Icons.battery_charging_full_rounded,
                      accent: const Color(0xFF00A174),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                outletsText,
                style: TextStyle(
                  color: isLight
                      ? AppTheme.lightTextSecondary
                      : Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
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
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
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
                      final item = normalizedOutlets.firstWhere(
                        (outlet) => outlet['index'] == n,
                        orElse: () => <String, dynamic>{
                          'isOn': false,
                          'hasReading': false,
                          'watts': 0.0,
                        },
                      );
                      final isOn = item['isOn'] == true;
                      final hasReading = item['hasReading'] == true;
                      final watts = _wattsForOutlet(normalizedOutlets, n);
                      return _buildOutletTile(context, n, isOn, hasReading, watts);
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
                            duration: const Duration(milliseconds: 140),
                            curve: Curves.easeOutCubic,
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

  String _outletsSummary(List<Map<String, dynamic>> outlets) {
    if (outlets.isEmpty) return 'No outlet data';
    final activeCount = outlets.where((item) => item['isOn'] == true).length;
    final readingCount = outlets.where((item) => item['hasReading'] == true).length;
    return '$readingCount outlets with readings • $activeCount active';
  }

  Widget _buildStatusPill(
    String value, {
    required bool isLight,
  }) {
    final normalized = value.trim().toLowerCase();
    final isOk = normalized == 'normal' ||
        normalized == 'online' ||
        normalized == 'on' ||
        normalized == 'enabled';
    final bg = isOk
        ? const Color(0xFF00A174).withValues(alpha: 0.16)
        : Colors.orangeAccent.withValues(alpha: 0.16);
    final fg = isOk ? const Color(0xFF00D18F) : Colors.orangeAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.45)),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildSummaryStat(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isLight ? 0.10 : 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isLight
                        ? AppTheme.lightTextSecondary
                        : Colors.white.withValues(alpha: 0.82),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isLight ? AppTheme.lightTextPrimary : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
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

  Widget _buildOutletTile(
    BuildContext context,
    int outletNum,
    bool isOn,
    bool hasReading,
    double watts,
  ) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    const onFill = Color(0xFF00A174);
    final fill = hasReading
        ? onFill
        : Colors.transparent;

    const onText = Colors.white;
    const offTextLight = Color(0xFF555555);
    final offTextDark = Colors.white.withValues(alpha: 0.70);
    final text = hasReading
        ? onText
        : (isOn ? onFill : (isLight ? offTextLight : offTextDark));

    final border = isLight
        ? Colors.black.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.12);
    final activeBorder = onFill.withValues(alpha: 0.95);

    const double maxWatts = 3000.0;
    final pct = (watts / maxWatts).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasReading
              ? activeBorder
              : (isOn ? activeBorder : border.withValues(alpha: 0.65)),
          width: isOn || hasReading ? 1.5 : 1.0,
        ),
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
          if (hasReading) ...[
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
                color: isLight ? Colors.white.withValues(alpha: 0.90) : text.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ] else if (isOn) ...[
            const Icon(
              Icons.link_rounded,
              size: 18,
              color: onFill,
            ),
            const SizedBox(height: 2),
            const Text(
              'ON',
              style: TextStyle(
                color: onFill,
                fontSize: 12,
                fontWeight: FontWeight.w900,
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
