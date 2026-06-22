import 'package:flutter/material.dart';

import 'models/smart_rack_console_snapshot.dart';
import 'theme/console_theme.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/console_section_card.dart';
import 'widgets/pdu_schematic_widget.dart';

class PduConsoleScreen extends StatefulWidget {
  const PduConsoleScreen({
    super.key,
    required this.snapshot,
  });

  final SmartRackConsoleSnapshot snapshot;

  @override
  State<PduConsoleScreen> createState() => _PduConsoleScreenState();
}

class _PduConsoleScreenState extends State<PduConsoleScreen> {
  String _selectedTab = 'PDU 1';
  bool _pduExpanded = false;

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPillButton('PDU 1'),
          const SizedBox(width: 16),
          _buildPillButton('PDU 2'),
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
          _pduExpanded = false; // Reset expand state when switching
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

  TableRow _buildTableHeaderRow(BuildContext context, List<String> headers) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return TableRow(
      decoration: BoxDecoration(
        color: isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.05),
      ),
      children: headers.map((header) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Text(
            header,
            style: TextStyle(
              color: isLight ? AppTheme.lightTextSecondary : Colors.white70,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        );
      }).toList(),
    );
  }

  TableRow _buildParamRow(BuildContext context, String item, String value) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Text(
            item,
            style: TextStyle(
              color: isLight ? AppTheme.lightTextPrimary : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Text(
            value,
            style: TextStyle(
              color: isLight ? AppTheme.lightTextPrimary : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  List<TableRow> _buildPdu1Rows(BuildContext context) {
    return [
      _buildTableHeaderRow(context, ['Parameter Items', 'Value']),
      _buildParamRow(context, 'Voltage', '220 V'),
      _buildParamRow(context, 'Current', '2.2 A'),
      _buildParamRow(context, 'Active Power (Single-Phase)', '0.47 kW'),
      _buildParamRow(context, 'Reactive Power (Single-Phase)', '47 VAR'),
      _buildParamRow(context, 'Power Factor (Single-Phase)', '1.0'),
      _buildParamRow(context, 'Total Energy', '7387.8 kWh'),
      _buildParamRow(context, 'Frequency', '50 Hz'),
      _buildParamRow(context, 'Rated Voltage', '220 V'),
      _buildParamRow(context, 'Rated Current', '32 A'),
      _buildParamRow(context, 'Rated Frequency', '50 Hz'),
    ];
  }

  List<TableRow> _buildPdu2Rows(BuildContext context) {
    return [
      _buildTableHeaderRow(context, ['Parameter Items', 'Value']),
      _buildParamRow(context, 'Voltage', '224 V'),
      _buildParamRow(context, 'Current', '3.1 A'),
      _buildParamRow(context, 'Active Power (Single-Phase)', '0.68 kW'),
      _buildParamRow(context, 'Reactive Power (Single-Phase)', '142 VAR'),
      _buildParamRow(context, 'Power Factor (Single-Phase)', '0.98'),
      _buildParamRow(context, 'Total Energy', '14645.2 kWh'),
      _buildParamRow(context, 'Frequency', '50 Hz'),
      _buildParamRow(context, 'Rated Voltage', '220 V'),
      _buildParamRow(context, 'Rated Current', '32 A'),
      _buildParamRow(context, 'Rated Frequency', '50 Hz'),
    ];
  }

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
              child: Column(
                children: [
                  _buildTabBar(),
                  Expanded(
                    child: PduSchematicWidget(
                      pduName: _selectedTab,
                      expanded: _pduExpanded,
                      onToggleExpand: () {
                        setState(() {
                          _pduExpanded = !_pduExpanded;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: ConsoleTheme.lg),
          // Right Column: Data Tables
          Expanded(
            flex: 4,
            child: ConsoleSectionCard(
              title: 'Parameter Status',
              expand: true,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      color: ConsoleTheme.primaryBlue(context).withValues(alpha: 0.2),
                      child: Text(
                        'Current Parameter ($_selectedTab)',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1),
                        1: FlexColumnWidth(1),
                      },
                      border: TableBorder.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                      children: _selectedTab == 'PDU 1' ? _buildPdu1Rows(context) : _buildPdu2Rows(context),
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
}
