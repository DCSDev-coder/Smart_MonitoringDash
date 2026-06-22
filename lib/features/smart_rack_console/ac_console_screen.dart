import 'package:flutter/material.dart';

import '../../core/controllers/global_status_poller.dart';
import 'models/smart_rack_console_snapshot.dart';
import 'services/smart_rack_console_repository.dart';
import 'theme/console_theme.dart';
import 'widgets/console_section_card.dart';
import 'widgets/console_metric_card.dart';
import 'widgets/ac_schematic_widget.dart';

class AcConsoleScreen extends StatelessWidget {
  const AcConsoleScreen({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: GlobalStatusPoller.instance,
      builder: (context, _) {
        final snapshot =
            SmartRackConsoleRepository.instance.currentSnapshot();

        return Container(
          decoration: BoxDecoration(
            gradient: ConsoleTheme.pageBgGradient(context),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? ConsoleTheme.md : ConsoleTheme.lg),
            child: _buildAcContent(context, snapshot),
          ),
        );
      },
    );
  }

  Widget _buildAcContent(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    final isWide = MediaQuery.of(context).size.width > 900;

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.only(left: ConsoleTheme.lg, right: ConsoleTheme.md),
              child: _buildSchematicPanel(context, snapshot),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(left: ConsoleTheme.md, right: ConsoleTheme.lg),
              child: _buildControlsAndTelemetry(context, snapshot),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ConsoleTheme.md),
            child: _buildSchematicPanel(context, snapshot),
          ),
        ),
        const SizedBox(height: ConsoleTheme.lg),
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ConsoleTheme.md),
            child: _buildControlsAndTelemetry(context, snapshot),
          ),
        ),
      ],
    );
  }

  Widget _buildSchematicPanel(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ConsoleSectionCard(
            title: 'System Schematic',
            expand: true,
            trailing: IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white70),
              tooltip: 'View Full Diagram',
              onPressed: () => _showFullscreenSchematic(context, snapshot),
            ),
            child: AcSchematicWidget(
              snapshot: snapshot,
              showLabels: false, // Hidden by default in card
            ),
          ),
        ),
        const SizedBox(height: ConsoleTheme.lg),
        Row(
          children: [
            Expanded(
              child: ConsoleMetricCard(
                label: 'Unit Status',
                value: 'Running',
                icon: Icons.power_settings_new_rounded,
                accentColor: ConsoleTheme.success(context),
              ),
            ),
            const SizedBox(width: ConsoleTheme.lg),
            Expanded(
              child: ConsoleMetricCard(
                label: 'Compressor',
                value: 'Running',
                icon: Icons.ac_unit_rounded,
                accentColor: ConsoleTheme.success(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlsAndTelemetry(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    return Column(
      children: [
        Expanded(
          child: ConsoleSectionCard(
            title: 'Air Conditioning Setting',
            expand: true,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1),
                },
                border: TableBorder.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: ConsoleTheme.primaryBlue(context).withValues(alpha: 0.2)),
                    children: [
                      _buildTableHeader('Parameter Item'),
                      _buildTableHeader('Set Value'),
                    ],
                  ),
                  _buildSettingTableRow(context, 'Reset', 'OFF'),
                  _buildSettingTableRow(context, 'Power on/off', 'on'),
                  _buildSettingTableRow(context, 'Temperature Setpoint', '24.0 °C'),
                  _buildSettingTableRow(context, 'Humidity Setpoint', '45.0 %RH'),
                  _buildSettingTableRow(context, 'Supply Air High Humd Alarm', '80 %RH'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: ConsoleTheme.lg),
        Expanded(
          child: ConsoleSectionCard(
            title: 'Air Conditioning Status',
            expand: true,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(1),
                },
                border: TableBorder.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: ConsoleTheme.primaryBlue(context).withValues(alpha: 0.2)),
                    children: [
                      _buildTableHeader('Status Item'),
                      _buildTableHeader('Status'),
                    ],
                  ),
                  _buildStatusTableRow(context, 'Electric Heater Status', 'Stopped', false),
                  _buildStatusTableRow(context, 'Electric Heater', 'Stopped', false),
                  _buildStatusTableRow(context, 'Current operating state', 'Cooling', true),
                  _buildStatusTableRow(context, 'Compressor Status', 'Running', true),
                  _buildStatusTableRow(context, 'Water pump', 'Stopped', false),
                  _buildStatusTableRow(context, 'Temp control', 'Return air', true),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  TableRow _buildSettingTableRow(BuildContext context, String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showMockInputDialog(context, label, value),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: ConsoleTheme.primaryBlue(context).withValues(alpha: 0.1),
                    border: Border.all(color: ConsoleTheme.primaryBlue(context).withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showMockInputDialog(BuildContext context, String label, String currentValue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0B1426),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ConsoleTheme.primaryBlue(context).withValues(alpha: 0.3)),
        ),
        title: Text(
          'Change $label',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Current value: $currentValue',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter new value',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.3),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: ConsoleTheme.primaryBlue(context)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: ConsoleTheme.primaryBlue(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: ConsoleTheme.danger(context),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: ConsoleTheme.danger(context).withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildStatusTableRow(BuildContext context, String label, String status, bool isRunning) {
    Color statusColor = Colors.white;
    if (isRunning || status.toLowerCase() == 'stopped') {
      statusColor = ConsoleTheme.success(context);
    }

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: statusColor, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  void _showFullscreenSchematic(BuildContext context, SmartRackConsoleSnapshot snapshot) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: ConsoleTheme.panelBg(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ConsoleTheme.primaryBlue(context).withValues(alpha: 0.5)),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: ConsoleTheme.cardBgGradient(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'System Schematic',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: AcSchematicWidget(
                    snapshot: snapshot,
                    showLabels: true, // Show all text labels in fullscreen
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
