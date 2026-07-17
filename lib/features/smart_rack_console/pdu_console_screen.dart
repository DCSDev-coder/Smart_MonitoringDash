import 'package:flutter/material.dart';

import '../../core/network/adapter_api_service.dart';
import '../../core/network/cpanel_api_service.dart';
import 'models/smart_rack_console_snapshot.dart';
import 'theme/console_theme.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/console_section_card.dart';
import 'widgets/pdu_schematic_widget.dart';
import '../../shared/utils/app_toast.dart';
import '../../shared/widgets/kiosk_user_pin_sheet.dart';
import 'services/smart_rack_console_repository.dart';
import 'widgets/rack_setting_edit_sheet.dart';

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
  bool _writingSetting = false;

  List<ConsoleMetricRow> _selectedSummaryRows() {
    return _selectedPdu == 'PDU 1'
        ? widget.snapshot.powerPdu1MetricRows
        : widget.snapshot.powerPdu2MetricRows;
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
      title: 'Update PDU Setting',
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
          'Adapter connection is required to update PDU settings.',
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
          res?['message']?.toString() ?? 'Failed to update PDU setting.',
        );
        return;
      }

      if (!context.mounted) return;
      AppToast.showSuccess(context, 'PDU setting updated.');
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
          'Adapter connection is required to update PDU settings.',
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
          res?['message']?.toString() ?? 'Failed to update PDU setting.',
        );
        return;
      }

      if (!context.mounted) return;
      AppToast.showSuccess(context, 'PDU setting updated.');
      await SmartRackConsoleRepository.instance.refreshNow();
    } finally {
      if (mounted) setState(() => _writingSetting = false);
    }
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
        _buildParamRow(
          context,
          const ConsoleMetricRow(
            label: 'Status',
            value: 'No data',
          ),
        ),
      ];
    }
    return [
      _buildTableHeaderRow(context, const ['Parameter Items', 'Value']),
      ...rows.map((row) => _buildParamRow(context, row)),
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
            color: selected
                ? const Color(0xFF3B82F6)
                : ConsoleTheme.cardBorder(context),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected
                ? ConsoleTheme.textInverse(context)
                : ConsoleTheme.textSecondary(context),
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

  TableRow _buildParamRow(BuildContext context, ConsoleMetricRow row) {
    final canEdit = _selectedPanel == _PduPanel.setting &&
        row.isEditable &&
        row.metricCode != null &&
        row.metricCode!.trim().isNotEmpty &&
        row.nodeId != null;
    final hasChoices = canEdit && row.writeMap != null && row.writeMap!.isNotEmpty;
    final onTap = canEdit && !hasChoices && !_isPduCapabilityRow(row)
        ? () => _handleSettingTap(context, row)
        : null;
    return TableRow(
      children: [
        _buildParamCell(
          context,
          text: row.label,
          onTap: onTap,
          editable: false,
          alignCenter: false,
        ),
        hasChoices
            ? _buildDropdownSettingCell(context, row)
            : _buildParamCell(
                context,
                text: row.value,
                onTap: onTap,
                editable: canEdit,
                alignCenter: true,
              ),
      ],
    );
  }

  Widget _buildDropdownSettingCell(BuildContext context, ConsoleMetricRow row) {
    final writeMap = row.writeMap;
    if (writeMap == null || writeMap.isEmpty) {
      return _buildParamCell(
        context,
        text: row.value,
        onTap: () => _handleSettingTap(context, row),
        editable: true,
        alignCenter: true,
      );
    }

    final entries = writeMap.entries.toList()
      ..sort((a, b) => _sortWriteKey(a.key).compareTo(_sortWriteKey(b.key)));
    final currentKey = _currentChoiceKey(row, entries);
    final currentLabel = writeMap[currentKey] ?? row.value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: currentLabel,
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
                    textAlign: TextAlign.center,
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

  Widget _buildParamCell(
    BuildContext context, {
    required String text,
    required bool alignCenter,
    required VoidCallback? onTap,
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
            const SizedBox(width: 6),
            Icon(Icons.edit_rounded,
                size: 14, color: ConsoleTheme.textMuted(context)),
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

  bool _isPduCapabilityRow(ConsoleMetricRow row) {
    final label = row.label.toLowerCase();
    return label == 'outlet control' ||
        (label.contains('outlet control') && row.writeMap == null);
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
