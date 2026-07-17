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
  int _selectedInletSectionIndex = 0;
  int _selectedOutletSectionIndex = 0;

  @override
  Widget build(BuildContext context) {
    final inletSections = _buildInletSections();
    final selectedInletSection =
        inletSections.isEmpty
            ? null
            : inletSections[_selectedInletSectionIndex.clamp(
              0,
              inletSections.length - 1,
            )];
    final outletSections = _buildOutletSections();
    final selectedOutletSection =
        outletSections.isEmpty
            ? null
            : outletSections[_selectedOutletSectionIndex.clamp(
              0,
              outletSections.length - 1,
            )];

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
                icon: Icon(
                  Icons.info_outline,
                  color: ConsoleTheme.textMuted(context),
                ),
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
              expand: true,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionHeader(
                      context,
                      _selectedTab == 'Inlet' && selectedInletSection != null
                          ? 'Current Parameter (Inlet / ${selectedInletSection.title})'
                          : _selectedTab == 'Outlet' &&
                                  selectedOutletSection != null
                              ? 'Current Parameter (Outlet / ${selectedOutletSection.title})'
                              : 'Current Parameter ($_selectedTab)',
                    ),
                    if (_selectedTab == 'Inlet' && inletSections.length > 1) ...[
                      const SizedBox(height: 12),
                      _buildSectionNavigator(
                        sections: inletSections,
                        selectedIndex: _selectedInletSectionIndex,
                        onSelected: (index) {
                          setState(() {
                            _selectedInletSectionIndex = index;
                          });
                        },
                      ),
                    ],
                    if (_selectedTab == 'Outlet' &&
                        outletSections.length > 1) ...[
                      const SizedBox(height: 12),
                      _buildSectionNavigator(
                        sections: outletSections,
                        selectedIndex: _selectedOutletSectionIndex,
                        onSelected: (index) {
                          setState(() {
                            _selectedOutletSectionIndex = index;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1),
                        1: FlexColumnWidth(1),
                      },
                      border: TableBorder.all(
                        color: ConsoleTheme.textSecondary(context).withValues(alpha: 0.3),
                        width: 1,
                      ),
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
          if (title == 'Inlet') {
            _selectedInletSectionIndex = 0;
          }
          if (title == 'Outlet') {
            _selectedOutletSectionIndex = 0;
          }
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6)
                : ConsoleTheme.cardBorder(context),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? ConsoleTheme.textInverse(context)
                : ConsoleTheme.textSecondary(context),
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
        style: TextStyle(
          color: ConsoleTheme.textPrimary(context),
          fontWeight: FontWeight.bold,
        ),
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
    final sections = _buildInletSections();
    if (sections.isEmpty) {
      return [
        _buildTableHeaderRow(context, ['Parameter Items', 'Value']),
        _buildParamRow(context, 'Status', 'No data'),
      ];
    }
    final currentSection = sections[_selectedInletSectionIndex.clamp(
      0,
      sections.length - 1,
    )];
    return [
      _buildTableHeaderRow(context, ['Parameter Items', 'Value']),
      ...currentSection.rows.map((row) => _buildConsoleMetricRow(context, row)),
    ];
  }

  List<TableRow> _buildOutletRows(BuildContext context) {
    final sections = _buildOutletSections();
    if (sections.isEmpty) {
      return [
        _buildTableHeaderRow(context, ['Parameter Items', 'Value']),
        _buildParamRow(context, 'Status', 'No data'),
      ];
    }
    final currentSection = sections[_selectedOutletSectionIndex.clamp(
      0,
      sections.length - 1,
    )];
    return [
      _buildTableHeaderRow(context, ['Parameter Items', 'Value']),
      ...currentSection.rows.map((row) => _buildConsoleMetricRow(context, row)),
    ];
  }

  TableRow _buildConsoleMetricRow(BuildContext context, ConsoleMetricRow row) {
    final displayLabel =
        row.metricCode == 'device_online' &&
                row.label.toLowerCase() == 'offline state'
            ? 'Status'
            : row.label;
    return TableRow(
      children: [
        _buildTableCell(context, displayLabel, isLabel: true),
        _buildTableCell(
          context,
          row.value,
          isLabel: false,
          isNormal: row.isNormal,
        ),
      ],
    );
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

  Widget _buildSectionNavigator({
    required List<_MetricSection> sections,
    required int selectedIndex,
    required ValueChanged<int> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(sections.length, (index) {
        final section = sections[index];
        final isSelected = index == selectedIndex;
        return InkWell(
          onTap: () => onSelected(index),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? const Color(0xFF3B82F6)
                      : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    isSelected
                        ? const Color(0xFF3B82F6)
                        : Colors.white24,
              ),
            ),
            child: Text(
              section.title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        );
      }),
    );
  }

  List<_MetricSection> _buildInletSections() {
    final rows = widget.snapshot.powerInletRows;
    if (rows.isEmpty) return const [];

    final overview = <ConsoleMetricRow>[];
    final line1 = <ConsoleMetricRow>[];
    final line2 = <ConsoleMetricRow>[];
    final energy = <ConsoleMetricRow>[];

    for (final row in rows) {
      final label = row.label.toLowerCase();
      if (_isInletEnergyRow(label)) {
        energy.add(row);
      } else if (_isInletLine1Row(label)) {
        line1.add(row);
      } else if (_isInletLine2Row(label)) {
        line2.add(row);
      } else {
        overview.add(row);
      }
    }

    final sections = <_MetricSection>[
      if (overview.isNotEmpty) _MetricSection(title: 'Overview', rows: overview),
      if (line1.isNotEmpty) _MetricSection(title: 'Line 1', rows: line1),
      if (line2.isNotEmpty) _MetricSection(title: 'Line 2', rows: line2),
      if (energy.isNotEmpty) _MetricSection(title: 'Energy', rows: energy),
    ];

    return sections.isNotEmpty
        ? sections
        : [_MetricSection(title: 'Overview', rows: rows)];
  }

  List<_MetricSection> _buildOutletSections() {
    final rows = widget.snapshot.powerOutletRows;
    if (rows.isEmpty) return const [];

    final status = <ConsoleMetricRow>[];
    final overview = <ConsoleMetricRow>[];
    final sectionI = <ConsoleMetricRow>[];
    final sectionII = <ConsoleMetricRow>[];
    final energy = <ConsoleMetricRow>[];

    for (final row in rows) {
      if (_isOutletStatusRow(row)) {
        status.add(row);
      } else if (_isOutletEnergyRow(row)) {
        energy.add(row);
      } else if (_isOutletSectionIRow(row)) {
        sectionI.add(row);
      } else if (_isOutletSectionIIRow(row)) {
        sectionII.add(row);
      } else {
        overview.add(row);
      }
    }

    final sections = <_MetricSection>[
      if (status.isNotEmpty) _MetricSection(title: 'Status', rows: status),
      if (overview.isNotEmpty) _MetricSection(title: 'Overview', rows: overview),
      if (sectionI.isNotEmpty) _MetricSection(title: 'Line 1', rows: sectionI),
      if (sectionII.isNotEmpty) _MetricSection(title: 'Line 2', rows: sectionII),
      if (energy.isNotEmpty) _MetricSection(title: 'Energy', rows: energy),
    ];

    return sections.isNotEmpty
        ? sections
        : [_MetricSection(title: 'Overview', rows: rows)];
  }

  bool _isInletLine1Row(String label) {
    return label.contains('line 1') ||
        label.contains('line1') ||
        label.contains('l1') ||
        label.contains('phase a');
  }

  bool _isInletLine2Row(String label) {
    return label.contains('line 2') ||
        label.contains('line2') ||
        label.contains('l2') ||
        label.contains('phase b');
  }

  bool _isInletEnergyRow(String label) {
    return label.contains('energy') ||
        label.contains('kwh') ||
        label.contains('active power') ||
        label.contains('reactive power') ||
        label.contains('apparent power');
  }

  bool _isOutletSectionIRow(ConsoleMetricRow row) {
    final label = row.label.toLowerCase();
    final code = (row.metricCode ?? '').toLowerCase();
    return code.startsWith('section_i_') ||
        code.contains('section_i_outlet') ||
        RegExp(r'\bsection i\b').hasMatch(label) ||
        RegExp(r'\bsection 1\b').hasMatch(label);
  }

  bool _isOutletSectionIIRow(ConsoleMetricRow row) {
    final label = row.label.toLowerCase();
    final code = (row.metricCode ?? '').toLowerCase();
    return code.startsWith('section_ii_') ||
        code.contains('section_ii_outlet') ||
        RegExp(r'\bsection ii\b').hasMatch(label) ||
        RegExp(r'\bsection 2\b').hasMatch(label);
  }

  bool _isOutletEnergyRow(ConsoleMetricRow row) {
    final label = row.label.toLowerCase();
    final code = (row.metricCode ?? '').toLowerCase();
    return label.contains('energy') ||
        label.contains('kwh') ||
        label.contains('active power') ||
        label.contains('reactive power') ||
        label.contains('apparent power') ||
        label.contains('power factor') ||
        code.contains('energy') ||
        code.contains('activepower') ||
        code.contains('reactivepower') ||
        code.contains('apparentpower') ||
        code.contains('powerfactor');
  }

  bool _isOutletStatusRow(ConsoleMetricRow row) {
    final label = row.label.toLowerCase();
    final code = (row.metricCode ?? '').toLowerCase();
    return label == 'offline state' ||
        code == 'device_online' ||
        label.contains('status') ||
        label.contains('alarm') ||
        label.contains('phase sequence') ||
        label.contains('phase-sequence') ||
        label.contains('health') ||
        code.contains('status') ||
        code.contains('alarm') ||
        code.contains('phasesequence');
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

class _MetricSection {
  const _MetricSection({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<ConsoleMetricRow> rows;
}
