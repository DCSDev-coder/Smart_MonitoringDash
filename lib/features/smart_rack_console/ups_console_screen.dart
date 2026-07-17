import 'package:flutter/material.dart';

import 'models/smart_rack_console_snapshot.dart';
import 'theme/console_theme.dart';
import 'widgets/console_section_card.dart';
import 'widgets/ups_schematic_widget.dart';

class UpsConsoleScreen extends StatelessWidget {
  const UpsConsoleScreen({
    super.key,
    required this.snapshot,
  });

  final SmartRackConsoleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    // 2-Column layout: Left side (Schematic & Status), Right side (Parameters)
    return Padding(
      padding: const EdgeInsets.all(ConsoleTheme.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Column
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
                onPressed: () => _showFullscreenSchematic(context, snapshot),
              ),
              child: UpsSchematicWidget(snapshot: snapshot),
            ),
          ),
          const SizedBox(width: ConsoleTheme.lg),
          // Right Column
          Expanded(
            flex: 5,
            child: ConsoleSectionCard(
              title: 'Parameter Status',
              expand: true,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionHeader(context, 'Current Parameter'),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1),
                        1: FlexColumnWidth(1),
                      },
                      border: TableBorder.all(
                        color: ConsoleTheme.textSecondary(context).withValues(alpha: 0.3),
                        width: 1,
                      ),
                      children: _buildParameterRows(context),
                    ),
                    const SizedBox(height: ConsoleTheme.lg),
                    _buildSectionHeader(context, 'Status'),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1),
                        1: FlexColumnWidth(1),
                      },
                      border: TableBorder.all(
                        color: ConsoleTheme.textSecondary(context).withValues(alpha: 0.3),
                        width: 1,
                      ),
                      children: _buildStatusRows(context),
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

  List<TableRow> _buildParameterRows(BuildContext context) {
    final rows = snapshot.upsParameterRows;
    if (rows.isEmpty) {
      return [
        _buildTableHeaderRow(context, ['Parameter Item', 'Value']),
        _buildParamRow(context, 'Status', 'No data'),
      ];
    }
    return [
      _buildTableHeaderRow(context, ['Parameter Item', 'Value']),
      ...rows.map((row) => _buildConsoleMetricRow(context, row)),
    ];
  }

  List<TableRow> _buildStatusRows(BuildContext context) {
    final rows = snapshot.upsStatusRows;
    if (rows.isEmpty) {
      return [
        _buildTableHeaderRow(context, ['Status Item', 'Value']),
        _buildStatusRow(context, 'Status', 'No data'),
      ];
    }
    return [
      _buildTableHeaderRow(context, ['Status Item', 'Value']),
      ...rows.map((row) => _buildConsoleMetricRow(context, row)),
    ];
  }

  TableRow _buildStatusRow(BuildContext context, String label, String value) {
    return TableRow(
      children: [
        _buildTableCell(context, label, isLabel: true),
        _buildTableCell(context, value, isLabel: false, isNormal: value.toLowerCase() == 'normal'),
      ],
    );
  }

  TableRow _buildParamRow(BuildContext context, String label, String value) {
    return TableRow(
      children: [
        _buildTableCell(context, label, isLabel: true),
        _buildTableCell(context, value, isLabel: false),
      ],
    );
  }

  TableRow _buildConsoleMetricRow(BuildContext context, ConsoleMetricRow row) {
    return TableRow(
      children: [
        _buildTableCell(context, row.label, isLabel: true),
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
    Color textColor = ConsoleTheme.textPrimary(context);
    if (isLabel) textColor = ConsoleTheme.textSecondary(context);
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

  void _showFullscreenSchematic(BuildContext context, SmartRackConsoleSnapshot snapshot) {
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
                    Text(
                      'UPS Schematic (Detailed)',
                      style: TextStyle(
                        color: ConsoleTheme.textPrimary(context),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: ConsoleTheme.textMuted(context),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: UpsSchematicWidget(
                    snapshot: snapshot,
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
