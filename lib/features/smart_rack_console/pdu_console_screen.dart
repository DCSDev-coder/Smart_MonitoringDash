import 'package:flutter/material.dart';

import 'models/smart_rack_console_snapshot.dart';
import 'theme/console_theme.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/console_section_card.dart';
import 'widgets/pdu_schematic_widget.dart';

enum _PduPanel {
  metric,
  status,
  setting,
}

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
  String _selectedPdu = 'PDU 1';
  _PduPanel _selectedPanel = _PduPanel.metric;
  bool _pduExpanded = false;

  List<ConsoleMetricRow> _selectedSummaryRows() {
    return _selectedPdu == 'PDU 1'
        ? widget.snapshot.powerInletRows
        : widget.snapshot.powerOutletRows;
  }

  List<Map<String, dynamic>> _selectedOutlets() {
    return _selectedPdu == 'PDU 1'
        ? widget.snapshot.powerPdu1Outlets
        : widget.snapshot.powerPdu2Outlets;
  }

  List<ConsoleMetricRow> _selectedMetricRows() {
    return _selectedPdu == 'PDU 1'
        ? widget.snapshot.powerPdu1MetricRows
        : widget.snapshot.powerPdu2MetricRows;
  }

  List<ConsoleMetricRow> _selectedStatusRows() {
    return _selectedPdu == 'PDU 1'
        ? widget.snapshot.powerPdu1StatusRows
        : widget.snapshot.powerPdu2StatusRows;
  }

  List<ConsoleMetricRow> _selectedSettingRows() {
    return _selectedPdu == 'PDU 1'
        ? widget.snapshot.powerPdu1SettingRows
        : widget.snapshot.powerPdu2SettingRows;
  }

  List<TableRow> _buildPduRows(BuildContext context) {
    final rows = switch (_selectedPanel) {
      _PduPanel.metric => _selectedMetricRows(),
      _PduPanel.status => _selectedStatusRows(),
      _PduPanel.setting => _selectedSettingRows(),
    };
    if (rows.isEmpty) {
      return [
        _buildTableHeaderRow(context, const ['Parameter Items', 'Value']),
        _buildParamRow(context, 'Status', 'No data'),
      ];
    }
    return [
      _buildTableHeaderRow(context, const ['Parameter Items', 'Value']),
      ...rows.map((row) => _buildParamRow(context, row.label, row.value)),
    ];
  }

  String _selectedPanelLabel() {
    return switch (_selectedPanel) {
      _PduPanel.metric => 'Metric',
      _PduPanel.status => 'Status',
      _PduPanel.setting => 'Setting',
    };
  }

  Widget _buildPduTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPduButton('PDU 1'),
          const SizedBox(width: 16),
          _buildPduButton('PDU 2'),
        ],
      ),
    );
  }

  Widget _buildPanelTabs() {
    return Row(
      children: [
        Expanded(
          child: _buildPanelButton(
            label: 'Metric',
            selected: _selectedPanel == _PduPanel.metric,
            onTap: () => setState(() => _selectedPanel = _PduPanel.metric),
          ),
        ),
        const SizedBox(width: ConsoleTheme.sm),
        Expanded(
          child: _buildPanelButton(
            label: 'Status',
            selected: _selectedPanel == _PduPanel.status,
            onTap: () => setState(() => _selectedPanel = _PduPanel.status),
          ),
        ),
        const SizedBox(width: ConsoleTheme.sm),
        Expanded(
          child: _buildPanelButton(
            label: 'Setting',
            selected: _selectedPanel == _PduPanel.setting,
            onTap: () => setState(() => _selectedPanel = _PduPanel.setting),
          ),
        ),
      ],
    );
  }

  Widget _buildPduButton(String title) {
    final bool isSelected = _selectedPdu == title;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPdu = title;
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

  Widget _buildPanelButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3B82F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF3B82F6) : Colors.white24,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
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
                  _buildPduTabs(),
                  Expanded(
                    child: PduSchematicWidget(
                      pduName: _selectedPdu,
                      expanded: _pduExpanded,
                      summaryRows: _selectedSummaryRows(),
                      outlets: _selectedOutlets(),
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
                    _buildPanelTabs(),
                    const SizedBox(height: ConsoleTheme.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      color: ConsoleTheme.primaryBlue(context).withValues(alpha: 0.2),
                      child: Text(
                        'Current Parameter ($_selectedPdu - ${_selectedPanelLabel()})',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1),
                        1: FlexColumnWidth(1),
                      },
                      border: TableBorder.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                      children: _buildPduRows(context),
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
