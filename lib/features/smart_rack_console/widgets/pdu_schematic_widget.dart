import 'package:flutter/material.dart';

import '../theme/console_theme.dart';
import '../../../core/theme/app_theme.dart';

class PduSchematicWidget extends StatelessWidget {
  const PduSchematicWidget({
    super.key,
    required this.pduName,
    required this.expanded,
    required this.onToggleExpand,
  });

  final String pduName;
  final bool expanded;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    
    // Real values from PDU.har
    final bool online = true;
    final double pKw = pduName == 'PDU 1' ? 0.47 : 0.68;
    final double pA = pduName == 'PDU 1' ? 2.2 : 3.1;
    final int totalOutlets = 16;
    
    // Active outlets for mock
    final List<int> activeOutlets = pduName == 'PDU 1' ? [11, 12, 13, 15] : [9, 10, 11, 12, 13, 14];
    
    final List<int> allOutlets = List.generate(totalOutlets, (i) => i + 1);
    final List<int> showing = expanded ? allOutlets : (activeOutlets.isNotEmpty ? activeOutlets : allOutlets);

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
                '${pKw.toStringAsFixed(2)} kW',
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
                '${pA.toStringAsFixed(1)} A',
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
                      double watts = 0.0;
                      if (isOn) {
                        if (pduName == 'PDU 1') {
                          if (n == 11) watts = 209.0;
                          else if (n == 12) watts = 76.0;
                          else if (n == 13) watts = 99.0;
                          else if (n == 15) watts = 66.0;
                        } else {
                          if (n == 9) watts = 109.0;
                          else if (n == 10) watts = 114.0;
                          else if (n == 11) watts = 149.0;
                          else if (n == 12) watts = 115.0;
                          else if (n == 13) watts = 71.0;
                          else if (n == 14) watts = 81.0;
                        }
                      }
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

    final double maxWatts = 3000.0;
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
