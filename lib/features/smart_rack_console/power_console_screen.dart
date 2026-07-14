import 'package:flutter/material.dart';

import 'models/smart_rack_console_snapshot.dart';
import 'theme/console_theme.dart';
import 'widgets/console_section_card.dart';
import 'widgets/power_schematic_widget.dart';

class PowerConsoleScreen extends StatefulWidget {
  const PowerConsoleScreen({
    super.key,
    required this.snapshot,
  });

  final SmartRackConsoleSnapshot snapshot;

  @override
  State<PowerConsoleScreen> createState() => _PowerConsoleScreenState();
}

class _PowerConsoleScreenState extends State<PowerConsoleScreen> {
  String _selectedTab = 'Inlet';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ConsoleTheme.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Column: Schematic
          Expanded(
            flex: 5,
            child: ConsoleSectionCard(
              title: 'System Schematic',
              expand: true,
              trailing: IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.white54),
                tooltip: 'Show Labels',
                onPressed: () => _showFullscreenSchematic(context),
              ),
              child: Column(
                children: [
                  _buildTabBar(),
                  Expanded(
                    child: PowerSchematicWidget(
                      snapshot: widget.snapshot,
                      showLabels: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: ConsoleTheme.lg),
          // Right Column: Parameters
          Expanded(
            flex: 5,
            child: ConsoleSectionCard(
              title: 'Parameter Status',
              expand: true,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionHeader(context, 'Current Parameter ($_selectedTab)'),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1),
                        1: FlexColumnWidth(1),
                      },
                      border: TableBorder.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                      children: _selectedTab == 'Inlet' ? _buildInletRows(context) : _buildOutletRows(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPillButton('Inlet'),
          const SizedBox(width: 16),
          _buildPillButton('Outlet'),
        ],
      ),
    );
  }

  Widget _buildPillButton(String title) {
    final bool isSelected = _selectedTab == title;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = title;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.white24,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: ConsoleTheme.primaryBlue(context).withValues(alpha: 0.2),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  TableRow _buildParamRow(BuildContext context, String label, String value) {
    return TableRow(
      children: [
        _buildTableCell(context, label, isLabel: true),
        _buildTableCell(context, value, isLabel: false, isNormal: value.toLowerCase() == 'normal'),
      ],
    );
  }

  List<TableRow> _buildInletRows(BuildContext context) {
    return [
      _buildTableHeaderRow(context, ['Parameter Items', 'Value']),
      _buildParamRow(context, 'Offline State', 'Normal'),
      _buildParamRow(context, 'Phase A Voltage (Incoming Line 1)', '241.88 V'),
      _buildParamRow(context, 'Phase B Voltage (Incoming Line 1)', '241.97 V'),
      _buildParamRow(context, 'Phase C Voltage (Incoming Line 1)', '241.97 V'),
      _buildParamRow(context, 'AB Line Voltage (Incoming Line 1)', '419.02 V'),
      _buildParamRow(context, 'BC Line Voltage (Incoming Line 1)', '419.10 V'),
      _buildParamRow(context, 'CA Line Voltage (Incoming Line 1)', '419.02 V'),
      _buildParamRow(context, 'Frequency (Incoming Line 1)', '50.02 Hz'),
      _buildParamRow(context, 'Phase A Current (Incoming Line 1)', '0.10 A'),
      _buildParamRow(context, 'Phase B Current (Incoming Line 1)', '0 A'),
      _buildParamRow(context, 'Phase C Current (Incoming Line 1)', '0.29 A'),
      _buildParamRow(context, 'Phase A Active Power (Incoming Line 1)', '0.02 kW'),
      _buildParamRow(context, 'Phase B Active Power (Incoming Line 1)', '0 kW'),
      _buildParamRow(context, 'Phase C Active Power (Incoming Line 1)', '0.07 kW'),
      _buildParamRow(context, 'Total Active Power (Incoming Line 1)', '0.08 kW'),
      _buildParamRow(context, 'Phase A Reactive Power (Incoming Line 1)', '0 kvar'),
      _buildParamRow(context, 'Phase B Reactive Power (Incoming Line 1)', '0 kvar'),
      _buildParamRow(context, 'Phase C Reactive Power (Incoming Line 1)', '-0.02 kvar'),
    ];
  }

  List<TableRow> _buildOutletRows(BuildContext context) {
    return [
      _buildTableHeaderRow(context, ['Parameter Items', 'Value']),
      _buildParamRow(context, 'Offline State', 'Normal'),
      _buildParamRow(context, 'Phase A Voltage (Incoming Line 2)', '221.12 V'),
      _buildParamRow(context, 'Phase B Voltage (Incoming Line 2)', '0.0 V'),
      _buildParamRow(context, 'Phase C Voltage (Incoming Line 2)', '0.0 V'),
      _buildParamRow(context, 'AB Line Voltage (Incoming Line 2)', '221.12 V'),
      _buildParamRow(context, 'BC Line Voltage (Incoming Line 2)', '0.0 V'),
      _buildParamRow(context, 'CA Line Voltage (Incoming Line 2)', '221.12 V'),
      _buildParamRow(context, 'Frequency (Incoming Line 2)', '50.02 Hz'),
      _buildParamRow(context, 'Phase A Current (Incoming Line 2)', '0.28 A'),
      _buildParamRow(context, 'Phase B Current (Incoming Line 2)', '0.0 A'),
      _buildParamRow(context, 'Phase C Current (Incoming Line 2)', '0.0 A'),
      _buildParamRow(context, 'Phase A Active Power (Incoming Line 2)', '0.06 kW'),
      _buildParamRow(context, 'Phase B Active Power (Incoming Line 2)', '0.0 kW'),
      _buildParamRow(context, 'Phase C Active Power (Incoming Line 2)', '0.0 kW'),
      _buildParamRow(context, 'Total Active Power (Incoming Line 2)', '0.06 kW'),
      _buildParamRow(context, 'Phase A Reactive Power (Incoming Line 2)', '-0.01 kvar'),
      _buildParamRow(context, 'Phase B Reactive Power (Incoming Line 2)', '0.0 kvar'),
      _buildParamRow(context, 'Phase C Reactive Power (Incoming Line 2)', '0.0 kvar'),
      _buildParamRow(context, 'Total Reactive Power (Incoming Line 2)', '-0.01 kvar'),
    ];
  }

  TableRow _buildTableHeaderRow(BuildContext context, List<String> titles) {
    return TableRow(
      decoration: BoxDecoration(color: ConsoleTheme.primaryBlue(context).withValues(alpha: 0.2)),
      children: titles.map((t) => _buildTableCell(context, t, isHeader: true)).toList(),
    );
  }

  Widget _buildTableCell(BuildContext context, String text, {bool isLabel = false, bool isHeader = false, bool isNormal = false}) {
    Color textColor = Colors.white;
    if (isLabel) textColor = Colors.white70;
    if (isNormal) textColor = ConsoleTheme.success(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Text(
        text,
        textAlign: isHeader ? TextAlign.center : (isLabel ? TextAlign.left : TextAlign.center),
        style: TextStyle(
          fontSize: 14,
          color: textColor,
          fontWeight: isHeader ? FontWeight.bold : (isLabel ? FontWeight.w500 : FontWeight.w600),
        ),
      ),
    );
  }

  void _showFullscreenSchematic(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              gradient: ConsoleTheme.cardBgGradient(context),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: ConsoleTheme.cardBorder(context),
                width: 1.5,
              ),
              boxShadow: ConsoleTheme.glowShadow(context),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Power Schematic Diagram (Detailed)',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: PowerSchematicWidget(
                    snapshot: widget.snapshot,
                    showLabels: true,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
