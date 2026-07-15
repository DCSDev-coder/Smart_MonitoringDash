import 'package:flutter/material.dart';

import '../../core/controllers/global_status_poller.dart';
import 'models/smart_rack_console_snapshot.dart';
import 'services/smart_rack_console_repository.dart';
import 'theme/console_theme.dart';
import 'widgets/console_section_card.dart';
import 'widgets/console_metric_card.dart';
import 'widgets/ac_schematic_widget.dart';

enum _AcPanel {
  metric,
  setting,
  status,
}

class AcConsoleScreen extends StatefulWidget {
  const AcConsoleScreen({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  State<AcConsoleScreen> createState() => _AcConsoleScreenState();
}

class _AcConsoleScreenState extends State<AcConsoleScreen> {
  _AcPanel _selectedPanel = _AcPanel.metric;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: GlobalStatusPoller.instance,
      builder: (context, _) {
        final snapshot = SmartRackConsoleRepository.instance.currentSnapshot();

        return Container(
          decoration: BoxDecoration(
            gradient: ConsoleTheme.pageBgGradient(context),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
                vertical: widget.compact ? ConsoleTheme.md : ConsoleTheme.lg),
            child: _buildAcContent(context, snapshot),
          ),
        );
      },
    );
  }

  Widget _buildAcContent(
      BuildContext context, SmartRackConsoleSnapshot snapshot) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.only(
                left: ConsoleTheme.lg, right: ConsoleTheme.md),
            child: _buildSchematicPanel(context, snapshot, true),
          ),
        ),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.only(
                left: ConsoleTheme.md, right: ConsoleTheme.lg),
            child: _buildControlsAndTelemetry(context, snapshot, true),
          ),
        ),
      ],
    );
  }

  Widget _buildSchematicPanel(
      BuildContext context, SmartRackConsoleSnapshot snapshot, bool expand) {
    final schematicCard = ConsoleSectionCard(
      title: 'System Schematic',
      expand: expand,
      trailing: IconButton(
        icon: const Icon(Icons.info_outline, color: Colors.white70),
        tooltip: 'View Full Diagram',
        onPressed: () => _showFullscreenSchematic(context, snapshot),
      ),
      child: AcSchematicWidget(
        snapshot: snapshot,
        showLabels: false, // Hidden by default in card
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        expand ? Expanded(child: schematicCard) : schematicCard,
        const SizedBox(height: ConsoleTheme.lg),
        Row(
          children: [
            Expanded(
              child: ConsoleMetricCard(
                label: 'Unit Status',
                value: snapshot.acUnitStatus ?? '--',
                icon: Icons.power_settings_new_rounded,
                accentColor: _isPositiveStatus(snapshot.acUnitStatus)
                    ? ConsoleTheme.success(context)
                    : ConsoleTheme.danger(context),
              ),
            ),
            const SizedBox(width: ConsoleTheme.lg),
            Expanded(
              child: ConsoleMetricCard(
                label: 'Compressor',
                value: snapshot.acCompressorStatus ?? '--',
                icon: Icons.ac_unit_rounded,
                accentColor: _isPositiveStatus(snapshot.acCompressorStatus)
                    ? ConsoleTheme.success(context)
                    : ConsoleTheme.danger(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlsAndTelemetry(
      BuildContext context, SmartRackConsoleSnapshot snapshot, bool expand) {
    return Column(
      children: [
        _buildPanelToggleRow(context),
        const SizedBox(height: ConsoleTheme.lg),
        Expanded(
          child: _buildSelectedPanel(context, snapshot, expand),
        ),
      ],
    );
  }

  Widget _buildPanelToggleRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildPanelButton(
            context,
            label: 'Metric',
            selected: _selectedPanel == _AcPanel.metric,
            onTap: () => setState(() => _selectedPanel = _AcPanel.metric),
          ),
        ),
        const SizedBox(width: ConsoleTheme.sm),
        Expanded(
          child: _buildPanelButton(
            context,
            label: 'Setting',
            selected: _selectedPanel == _AcPanel.setting,
            onTap: () => setState(() => _selectedPanel = _AcPanel.setting),
          ),
        ),
        const SizedBox(width: ConsoleTheme.sm),
        Expanded(
          child: _buildPanelButton(
            context,
            label: 'Status',
            selected: _selectedPanel == _AcPanel.status,
            onTap: () => setState(() => _selectedPanel = _AcPanel.status),
          ),
        ),
      ],
    );
  }

  Widget _buildPanelButton(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final activeColor = ConsoleTheme.primaryBlue(context);
    final inactiveColor = Colors.white.withValues(alpha: 0.08);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? activeColor : inactiveColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? activeColor.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.14),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : const [],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedPanel(
    BuildContext context,
    SmartRackConsoleSnapshot snapshot,
    bool expand,
  ) {
    switch (_selectedPanel) {
      case _AcPanel.metric:
        return _buildMetricCard(context, snapshot, expand);
      case _AcPanel.setting:
        return _buildSettingCard(context, snapshot, expand);
      case _AcPanel.status:
        return _buildStatusCard(context, snapshot, expand);
    }
  }

  Widget _buildMetricCard(
    BuildContext context,
    SmartRackConsoleSnapshot snapshot,
    bool expand,
  ) {
    return ConsoleSectionCard(
      title: 'Air Conditioning Metric',
      expand: expand,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1),
          },
          border: TableBorder.all(
              color: Colors.white.withValues(alpha: 0.15), width: 1),
          children: [
            TableRow(
              decoration: BoxDecoration(
                  color:
                      ConsoleTheme.primaryBlue(context).withValues(alpha: 0.2)),
              children: [
                _buildTableHeader('Metric Item'),
                _buildTableHeader('Value'),
              ],
            ),
            ...snapshot.acMetricRows.map(
              (row) => _buildMetricTableRow(context, row.label, row.value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context,
    SmartRackConsoleSnapshot snapshot,
    bool expand,
  ) {
    return ConsoleSectionCard(
      title: 'Air Conditioning Setting',
      expand: expand,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1),
          },
          border: TableBorder.all(
              color: Colors.white.withValues(alpha: 0.15), width: 1),
          children: [
            TableRow(
              decoration: BoxDecoration(
                  color:
                      ConsoleTheme.primaryBlue(context).withValues(alpha: 0.2)),
              children: [
                _buildTableHeader('Parameter Item'),
                _buildTableHeader('Set Value'),
              ],
            ),
            ...snapshot.acSettingRows.map(
              (row) => _buildSettingTableRow(context, row.label, row.value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    SmartRackConsoleSnapshot snapshot,
    bool expand,
  ) {
    return ConsoleSectionCard(
      title: 'Air Conditioning Status',
      expand: expand,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(1),
          },
          border: TableBorder.all(
              color: Colors.white.withValues(alpha: 0.15), width: 1),
          children: [
            TableRow(
              decoration: BoxDecoration(
                  color:
                      ConsoleTheme.primaryBlue(context).withValues(alpha: 0.2)),
              children: [
                _buildTableHeader('Status Item'),
                _buildTableHeader('Status'),
              ],
            ),
            ...snapshot.acStatusRows.map(
              (row) => _buildStatusTableRow(
                context,
                row.label,
                row.value,
                row.isNormal,
              ),
            ),
          ],
        ),
      ),
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

  TableRow _buildSettingTableRow(
      BuildContext context, String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Center(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: ConsoleTheme.primaryBlue(context).withValues(alpha: 0.1),
                border: Border.all(
                    color: ConsoleTheme.primaryBlue(context)
                        .withValues(alpha: 0.5)),
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
      ],
    );
  }

  TableRow _buildMetricTableRow(
      BuildContext context, String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  TableRow _buildStatusTableRow(
      BuildContext context, String label, String status, bool isRunning) {
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
            style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: statusColor, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  bool _isPositiveStatus(String? value) {
    final normalized = value?.trim().toLowerCase();
    return normalized == 'running' ||
        normalized == 'normal' ||
        normalized == 'on' ||
        normalized == 'cooling' ||
        normalized == 'return air';
  }

  void _showFullscreenSchematic(
      BuildContext context, SmartRackConsoleSnapshot snapshot) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: ConsoleTheme.panelBg(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color:
                    ConsoleTheme.primaryBlue(context).withValues(alpha: 0.5)),
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
