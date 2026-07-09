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
                icon: const Icon(Icons.info_outline, color: Colors.white54),
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
                      border: TableBorder.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                      children: [
                        _buildTableHeaderRow(context, ['Parameter Item', 'Value']),
                        _buildParamRow(context, 'Output Voltage', '221 V'),
                        _buildParamRow(context, 'Output Load Ratio', '11 %'),
                        _buildParamRow(context, 'Offline State', 'Normal'),
                        _buildParamRow(context, 'Input Voltage', '241.70 V'),
                        _buildParamRow(context, 'Input Frequency', '50 Hz'),
                      ],
                    ),
                    const SizedBox(height: ConsoleTheme.lg),
                    _buildSectionHeader(context, 'Status'),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1),
                        1: FlexColumnWidth(1),
                      },
                      border: TableBorder.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                      children: [
                        _buildStatusRow(context, 'Working mode', 'Online'),
                        _buildStatusRow(context, 'UPS status', 'Normal'),
                        _buildStatusRow(context, 'Working condition', 'Normal'),
                        _buildStatusRow(context, 'Self inspection', 'Normal'),
                        _buildStatusRow(context, 'Prompt sound', 'Close'),
                        _buildStatusRow(context, 'Mains power', 'Normal'),
                        _buildStatusRow(context, 'Power on', 'Normal'),
                        _buildStatusRow(context, 'Battery', 'Normal'),
                      ],
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
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
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
                    const Text(
                      'UPS Schematic (Detailed)',
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
