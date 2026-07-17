import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/network/adapter_api_service.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/controllers/global_status_poller.dart';
import 'models/smart_rack_console_snapshot.dart';
import 'services/smart_rack_console_repository.dart';
import 'theme/console_theme.dart';
import 'widgets/console_section_card.dart';
import 'widgets/console_metric_card.dart';
import 'widgets/ac_schematic_widget.dart';
import '../../shared/utils/app_toast.dart';
import '../../shared/widgets/kiosk_user_pin_sheet.dart';
import 'widgets/rack_setting_edit_sheet.dart';

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
  bool _writingSetting = false;

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
        icon: Icon(
          Icons.info_outline,
          color: ConsoleTheme.textSecondary(context),
        ),
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
    final inactiveColor = ConsoleTheme.innerSurface(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: AppConfig.isRackConsoleBuild
            ? const Duration(milliseconds: 90)
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? activeColor : inactiveColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? activeColor.withValues(alpha: 0.9)
                : ConsoleTheme.cardBorder(context),
          ),
          boxShadow: selected && !AppConfig.isRackConsoleBuild
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
            color: selected
                ? ConsoleTheme.textInverse(context)
                : ConsoleTheme.textSecondary(context),
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

  Future<void> _handleSettingTap(
    BuildContext context,
    ConsoleMetricRow row,
  ) async {
    if (_writingSetting || !row.isEditable) return;
    final nodeId = row.nodeId;
    final metricCode = row.metricCode?.trim();
    if (nodeId == null || metricCode == null || metricCode.isEmpty) return;

    final currentValue = _editableValue(row);
    final newValue = await RackSettingEditSheet.show(
      context,
      title: 'Update AC Setting',
      label: row.label,
      currentValue: currentValue,
    );
    if (!context.mounted || newValue == null) return;

    final site = CpanelApiService.instance.currentSite;
    final isRackConsoleMode =
        site != null && CpanelApiService.instance.isCurrentSiteRackConsole(site);
    String? pin;
    if (isRackConsoleMode) {
      if (!AdapterApiService.instance.isConfigured) {
        AppToast.showError(
          context,
          'Adapter connection is required to update AC settings.',
        );
        return;
      }
      final approval = await RackConsoleUserPinSheet.show(
        context,
        title: 'RACK CONSOLE SETTING APPROVAL',
        reason: 'Enter the approving user PIN to update ${row.label}.',
        confirmLabel: 'Approve and Apply',
      );
      if (!context.mounted || approval == null) return;
      pin = approval.pin;
    }

    final parsedValue = _coerceSettingValue(newValue);
    setState(() => _writingSetting = true);
    try {
      final res = await SmartRackConsoleRepository.instance.writeSetting(
        row: row,
        value: parsedValue,
        pin: pin,
      );
      final ok =
          (res?['success'] == true) || (res?['code']?.toString() == '20000');
      if (!ok) {
        if (!context.mounted) return;
        AppToast.showError(
          context,
          res?['message']?.toString() ?? 'Failed to update AC setting.',
        );
        return;
      }

      if (!context.mounted) return;
      AppToast.showSuccess(context, 'AC setting updated.');
      await SmartRackConsoleRepository.instance.refreshNow();
    } finally {
      if (mounted) setState(() => _writingSetting = false);
    }
  }

  Future<void> _applySettingChoice(
    BuildContext context,
    ConsoleMetricRow row,
    MapEntry<String, String> choice,
  ) async {
    if (_writingSetting || !row.isEditable) return;
    final nodeId = row.nodeId;
    final metricCode = row.metricCode?.trim();
    if (nodeId == null || metricCode == null || metricCode.isEmpty) return;

    final site = CpanelApiService.instance.currentSite;
    final isRackConsoleMode =
        site != null && CpanelApiService.instance.isCurrentSiteRackConsole(site);
    String? pin;
    if (isRackConsoleMode) {
      if (!AdapterApiService.instance.isConfigured) {
        AppToast.showError(
          context,
          'Adapter connection is required to update AC settings.',
        );
        return;
      }
      final approval = await RackConsoleUserPinSheet.show(
        context,
        title: 'RACK CONSOLE SETTING APPROVAL',
        reason:
            'Enter the approving user PIN to change ${row.label} to ${choice.value}.',
        confirmLabel: 'Approve and Apply',
      );
      if (!context.mounted || approval == null) return;
      pin = approval.pin;
    }

    setState(() => _writingSetting = true);
    try {
      final res = await SmartRackConsoleRepository.instance.writeSetting(
        row: row,
        value: _settingWriteValue(choice.key),
        pin: pin,
      );
      final ok =
          (res?['success'] == true) || (res?['code']?.toString() == '20000');
      if (!ok) {
        if (!context.mounted) return;
        AppToast.showError(
          context,
          res?['message']?.toString() ?? 'Failed to update AC setting.',
        );
        return;
      }

      if (!context.mounted) return;
      AppToast.showSuccess(context, 'AC setting updated.');
      await SmartRackConsoleRepository.instance.refreshNow();
    } finally {
      if (mounted) setState(() => _writingSetting = false);
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
              color: ConsoleTheme.textSecondary(context).withValues(alpha: 0.3), width: 1),
          children: [
            TableRow(
              decoration: BoxDecoration(
                  color:
                      ConsoleTheme.primaryBlue(context).withValues(alpha: 0.2)),
              children: [
                _buildTableHeader(context, 'Metric Item'),
                _buildTableHeader(context, 'Value'),
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
              color: ConsoleTheme.textSecondary(context).withValues(alpha: 0.3), width: 1),
          children: [
            TableRow(
              decoration: BoxDecoration(
                  color:
                      ConsoleTheme.primaryBlue(context).withValues(alpha: 0.2)),
              children: [
                _buildTableHeader(context, 'Parameter Item'),
                _buildTableHeader(context, 'Set Value'),
              ],
            ),
            ...snapshot.acSettingRows.map(
              (row) => _buildSettingTableRow(context, row),
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
              color: ConsoleTheme.textSecondary(context).withValues(alpha: 0.3), width: 1),
          children: [
            TableRow(
              decoration: BoxDecoration(
                  color:
                      ConsoleTheme.primaryBlue(context).withValues(alpha: 0.2)),
              children: [
                _buildTableHeader(context, 'Status Item'),
                _buildTableHeader(context, 'Status'),
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

  Widget _buildTableHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: ConsoleTheme.textPrimary(context),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  TableRow _buildSettingTableRow(
    BuildContext context,
    ConsoleMetricRow row,
  ) {
    final canEdit = row.isEditable &&
        row.metricCode != null &&
        row.metricCode!.trim().isNotEmpty &&
        row.nodeId != null;
    final hasChoices = canEdit && row.writeMap != null && row.writeMap!.isNotEmpty;
    final onTap = canEdit && !hasChoices ? () => _handleSettingTap(context, row) : null;
    return TableRow(
      children: [
        _buildSettingCell(
          context,
          text: row.label,
          onTap: onTap,
          alignCenter: false,
        ),
        hasChoices
            ? _buildDropdownSettingCell(context, row)
            : _buildSettingCell(
                context,
                text: row.value,
                onTap: onTap,
                alignCenter: true,
                editable: canEdit,
              ),
      ],
    );
  }

  Widget _buildDropdownSettingCell(BuildContext context, ConsoleMetricRow row) {
    final writeMap = row.writeMap;
    if (writeMap == null || writeMap.isEmpty) {
      return _buildSettingCell(
        context,
        text: row.value,
        onTap: () => _handleSettingTap(context, row),
        alignCenter: true,
        editable: true,
      );
    }
    final entries = writeMap.entries.toList()
      ..sort((a, b) => _sortWriteKey(a.key).compareTo(_sortWriteKey(b.key)));
    final currentKey = _currentChoiceKey(row, entries);
    final currentValue = writeMap[currentKey] ?? row.value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: currentValue,
          dropdownColor: ConsoleTheme.panelBg(context),
          iconEnabledColor: ConsoleTheme.textSecondary(context),
          style: TextStyle(
            color: ConsoleTheme.textPrimary(context),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          items: entries
              .map(
                (entry) => DropdownMenuItem<String>(
                  value: entry.value,
                  child: Text(
                    entry.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: _writingSetting
              ? null
              : (value) {
                  if (value == null) return;
                  final match = entries.firstWhere(
                    (entry) => entry.value == value,
                    orElse: () => entries.first,
                  );
                  _applySettingChoice(context, row, match);
                },
        ),
      ),
    );
  }

  Widget _buildSettingCell(
    BuildContext context, {
    required String text,
    required VoidCallback? onTap,
    required bool alignCenter,
    bool editable = false,
  }) {
    final padded = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Row(
        mainAxisAlignment:
            alignCenter ? MainAxisAlignment.center : MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              text,
              textAlign: alignCenter ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                fontSize: 14,
                color: editable
                    ? ConsoleTheme.textPrimary(context)
                    : ConsoleTheme.textSecondary(context),
                fontWeight: editable ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (editable) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.edit_rounded,
              size: 14,
              color: ConsoleTheme.textPrimary(context).withValues(alpha: 0.8),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return padded;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: padded,
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
            style: TextStyle(
                fontSize: 14,
                color: ConsoleTheme.textSecondary(context),
                fontWeight: FontWeight.w500),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                color: ConsoleTheme.textPrimary(context),
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  TableRow _buildStatusTableRow(
      BuildContext context, String label, String status, bool isRunning) {
    Color statusColor = ConsoleTheme.textPrimary(context);
    if (isRunning || status.toLowerCase() == 'stopped') {
      statusColor = ConsoleTheme.success(context);
    }

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
                fontSize: 14,
                color: ConsoleTheme.textSecondary(context),
                fontWeight: FontWeight.w500),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                color: statusColor,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  String _editableValue(ConsoleMetricRow row) {
    final raw = row.rawValue?.trim();
    if (raw != null && raw.isNotEmpty) return raw;

    final display = row.value.trim();
    final stripped = display.replaceAll(RegExp(r'\s+[A-Za-z%°WkVh]+$'), '');
    return stripped.isEmpty ? display : stripped;
  }

  Object _coerceSettingValue(String value) {
    final normalized = value.trim();
    final lower = normalized.toLowerCase();
    if (lower == 'on' || lower == 'true' || lower == 'enable') return true;
    if (lower == 'off' || lower == 'false' || lower == 'disable') return false;
    final intValue = int.tryParse(normalized);
    if (intValue != null) return intValue;
    final doubleValue = double.tryParse(normalized);
    if (doubleValue != null) return doubleValue;
    return normalized;
  }

  String _currentChoiceKey(
    ConsoleMetricRow row,
    List<MapEntry<String, String>> entries,
  ) {
    final raw = row.rawValue?.trim();
    if (raw != null && raw.isNotEmpty) {
      final rawInt = int.tryParse(raw);
      final rawDouble = double.tryParse(raw);
      for (final entry in entries) {
        final key = entry.key.trim();
        if (key == raw) return key;
        final parsedInt = int.tryParse(key);
        final parsedDouble = double.tryParse(key);
        if (rawInt != null && parsedInt != null && parsedInt == rawInt) {
          return key;
        }
        if (rawDouble != null && parsedDouble != null && parsedDouble == rawDouble) {
          return key;
        }
      }
    }

    final display = row.value.trim().toLowerCase();
    for (final entry in entries) {
      if (entry.value.trim().toLowerCase() == display) {
        return entry.key;
      }
    }

    return entries.first.key;
  }

  int _sortWriteKey(String key) {
    return int.tryParse(key.trim()) ?? 9999;
  }

  Object _settingWriteValue(String key) {
    final parsedInt = int.tryParse(key.trim());
    if (parsedInt != null) return parsedInt;
    final parsedDouble = double.tryParse(key.trim());
    if (parsedDouble != null) return parsedDouble;
    return key.trim();
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
                    Text(
                      'System Schematic',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ConsoleTheme.textPrimary(context),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: ConsoleTheme.textSecondary(context)),
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
