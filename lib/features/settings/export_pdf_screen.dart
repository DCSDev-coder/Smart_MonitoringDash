import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/background_layer.dart';
import '../../shared/utils/app_toast.dart';
import '../../core/utils/pdf_generator_service.dart';

enum _DatePreset { last24Hours, last7Days, last30Days, thisMonth, custom }

class ExportPdfScreen extends StatefulWidget {
  const ExportPdfScreen({super.key});

  @override
  State<ExportPdfScreen> createState() => _ExportPdfScreenState();
}

class _ExportPdfScreenState extends State<ExportPdfScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  _DatePreset _activePreset = _DatePreset.last7Days;

  bool _includeEnvironment = true;
  bool _includePower = true;
  bool _includeAlarms = true;
  bool _includeDoorLogs = true;

  bool _isGenerating = false;

  int get _selectedCount =>
      (_includeEnvironment ? 1 : 0) +
      (_includePower ? 1 : 0) +
      (_includeAlarms ? 1 : 0) +
      (_includeDoorLogs ? 1 : 0);

  bool get _allSelected => _selectedCount == 4;

  void _applyPreset(_DatePreset preset) {
    final now = DateTime.now();
    setState(() {
      _activePreset = preset;
      switch (preset) {
        case _DatePreset.last24Hours:
          _startDate = now.subtract(const Duration(hours: 24));
          _endDate = now;
          break;
        case _DatePreset.last7Days:
          _startDate = now.subtract(const Duration(days: 7));
          _endDate = now;
          break;
        case _DatePreset.last30Days:
          _startDate = now.subtract(const Duration(days: 30));
          _endDate = now;
          break;
        case _DatePreset.thisMonth:
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = now;
          break;
        case _DatePreset.custom:
          break;
      }
    });
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _startDate.isAfter(DateTime.now()) ? DateTime.now() : _startDate,
        end: _endDate.isAfter(DateTime.now()) ? DateTime.now() : _endDate,
      ),
      builder: (context, child) {
        final isLight = Theme.of(context).brightness == Brightness.light;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme(
              brightness: isLight ? Brightness.light : Brightness.dark,
              primary: AppTheme.accentBlue,
              onPrimary: Colors.white,
              secondary: AppTheme.accentBlue,
              onSecondary: Colors.white,
              surface: isLight ? Colors.white : const Color(0xFF131D2A),
              onSurface: isLight ? AppTheme.lightTextPrimary : Colors.white,
              error: AppTheme.accentRed,
              onError: Colors.white,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: isLight ? Colors.white : const Color(0xFF131D2A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _activePreset = _DatePreset.custom;
      });
    }
  }

  Future<void> _selectSingleDate(BuildContext context, bool isStart) async {
    final DateTime initialDate = isStart ? _startDate : _endDate;
    final DateTime firstDate = DateTime(2020);
    final DateTime lastDate = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(lastDate) ? lastDate : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        final isLight = Theme.of(context).brightness == Brightness.light;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme(
              brightness: isLight ? Brightness.light : Brightness.dark,
              primary: AppTheme.accentBlue,
              onPrimary: Colors.white,
              secondary: AppTheme.accentBlue,
              onSecondary: Colors.white,
              surface: isLight ? Colors.white : const Color(0xFF131D2A),
              onSurface: isLight ? AppTheme.lightTextPrimary : Colors.white,
              error: AppTheme.accentRed,
              onError: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _activePreset = _DatePreset.custom;
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  Future<void> _generatePdf() async {
    if (_selectedCount == 0) {
      AppToast.showError(
        context,
        'Please select at least one data section to include.',
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      await PdfGeneratorService.instance.generateAndDownloadA4Report(
        startDate: _startDate,
        endDate: _endDate,
        includeEnvironment: _includeEnvironment,
        includePower: _includePower,
        includeAlarms: _includeAlarms,
        includeDoorLogs: _includeDoorLogs,
      );
      if (mounted) {
        AppToast.showSuccess(context, 'PDF Report generated successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to generate PDF: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _toggleAllSections() {
    final target = !_allSelected;
    setState(() {
      _includeEnvironment = target;
      _includePower = target;
      _includeAlarms = target;
      _includeDoorLogs = target;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final dateSlashFormat = DateFormat('dd/MM/yyyy');

    final textColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final subTextColor = isLight
        ? const Color(0xFF64748B)
        : Colors.white.withValues(alpha: 0.65);
    final cardBg = isLight ? Colors.white : const Color(0xFF141820);
    final borderColor = isLight
        ? const Color(0xFFE2E8F0)
        : Colors.white.withValues(alpha: 0.08);
    final nestedBg = isLight
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF1A1F29);
    final dividerColor = isLight
        ? const Color(0xFFE2E8F0)
        : Colors.white.withValues(alpha: 0.07);
    final daysCount = _endDate.difference(_startDate).inDays.abs() + 1;
    final facilityName =
        (CpanelApiService.instance.currentSite?['site_name'] ?? 'Facility')
            .toString();

    return Scaffold(
      backgroundColor: isLight
          ? const Color(0xFFF7FAFD)
          : const Color(0xFF060B11),
      body: Stack(
        children: [
          if (!isLight)
            const Positioned.fill(
              child: BackgroundLayer(
                channel: BackgroundChannel.app,
                overlayAlpha: 0.74,
                staticForApp: true,
              ),
            ),
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.arrow_back_rounded,
                                color: textColor,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Export PDF Report',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Configure timeframe and sections for export',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: subTextColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.only(
                            top: 8,
                            bottom: media.padding.bottom + 36,
                            left: 16,
                            right: 16,
                          ),
                          children: [
                            // CARD 1: DATE RANGE
                            Container(
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: borderColor),
                              ),
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Date Range',
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '$daysCount ${daysCount == 1 ? 'day' : 'days'} selected',
                                        style: const TextStyle(
                                          color: Color(0xFF0EA5E9),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          fontFeatures: [
                                            FontFeature.tabularFigures()
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: nestedBg,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildSegmentedPreset(
                                          '24 Hours',
                                          _DatePreset.last24Hours,
                                          isLight,
                                          textColor,
                                          subTextColor,
                                        ),
                                        _buildSegmentedPreset(
                                          '7 Days',
                                          _DatePreset.last7Days,
                                          isLight,
                                          textColor,
                                          subTextColor,
                                        ),
                                        _buildSegmentedPreset(
                                          '30 Days',
                                          _DatePreset.last30Days,
                                          isLight,
                                          textColor,
                                          subTextColor,
                                        ),
                                        _buildSegmentedPreset(
                                          'Custom',
                                          _DatePreset.custom,
                                          isLight,
                                          textColor,
                                          subTextColor,
                                          onTap: () => _pickDateRange(context),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  IntrinsicHeight(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => _selectSingleDate(
                                                context, true),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 4),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .calendar_today_rounded,
                                                        size: 13,
                                                        color:
                                                            Color(0xFF0EA5E9),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        'Start date',
                                                        style: TextStyle(
                                                          color: subTextColor,
                                                          fontSize: 12.5,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          dateSlashFormat
                                                              .format(
                                                                  _startDate),
                                                          style: TextStyle(
                                                            color: textColor,
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontFeatures: const [
                                                              FontFeature
                                                                  .tabularFigures()
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      Icon(
                                                        Icons
                                                            .calendar_today_outlined,
                                                        size: 15,
                                                        color: subTextColor,
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        VerticalDivider(
                                          width: 28,
                                          thickness: 1,
                                          color: dividerColor,
                                        ),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => _selectSingleDate(
                                                context, false),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 4),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .calendar_today_rounded,
                                                        size: 13,
                                                        color:
                                                            Color(0xFF0EA5E9),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        'End date',
                                                        style: TextStyle(
                                                          color: subTextColor,
                                                          fontSize: 12.5,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          dateSlashFormat
                                                              .format(_endDate),
                                                          style: TextStyle(
                                                            color: textColor,
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontFeatures: const [
                                                              FontFeature
                                                                  .tabularFigures()
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      Icon(
                                                        Icons
                                                            .calendar_today_outlined,
                                                        size: 15,
                                                        color: subTextColor,
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // CARD 2: INCLUDE SECTIONS
                            Container(
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        18, 18, 18, 14),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Include Sections',
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '$_selectedCount of 4 selected',
                                                style: TextStyle(
                                                  color: subTextColor,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        InkWell(
                                          onTap: _toggleAllSections,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 4),
                                            child: Text(
                                              _allSelected
                                                  ? 'Deselect All'
                                                  : 'Select All',
                                              style: const TextStyle(
                                                color: Color(0xFF0EA5E9),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: dividerColor),
                                  _buildGroupedSectionTile(
                                    title: 'Environment & Climate',
                                    description:
                                        'Climate & Sensors \u00B7 Temperature & humidity trends, rack climate status',
                                    icon: Icons.thermostat_rounded,
                                    accentColor: const Color(0xFF00C08B),
                                    value: _includeEnvironment,
                                    onChanged: (v) => setState(
                                        () => _includeEnvironment = v),
                                    isLight: isLight,
                                    textColor: textColor,
                                    subTextColor: subTextColor,
                                  ),
                                  Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: dividerColor),
                                  _buildGroupedSectionTile(
                                    title: 'Power & Efficiency',
                                    description:
                                        'Electrical Analytics \u00B7 Energy consumption, phase loads & PUE efficiency',
                                    icon: Icons.bolt_rounded,
                                    accentColor: const Color(0xFFF59E0B),
                                    value: _includePower,
                                    onChanged: (v) =>
                                        setState(() => _includePower = v),
                                    isLight: isLight,
                                    textColor: textColor,
                                    subTextColor: subTextColor,
                                  ),
                                  Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: dividerColor),
                                  _buildGroupedSectionTile(
                                    title: 'Alarms & Events',
                                    description:
                                        'Security & Warnings \u00B7 Chronological log of all triggered alerts and thresholds',
                                    icon: Icons.warning_amber_rounded,
                                    accentColor: const Color(0xFFEF4444),
                                    value: _includeAlarms,
                                    onChanged: (v) =>
                                        setState(() => _includeAlarms = v),
                                    isLight: isLight,
                                    textColor: textColor,
                                    subTextColor: subTextColor,
                                  ),
                                  Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: dividerColor),
                                  _buildGroupedSectionTile(
                                    title: 'Door Access Logs',
                                    description:
                                        'Access Control \u00B7 Audit trail of physical rack door openings, RFID & keys',
                                    icon: Icons.meeting_room_rounded,
                                    accentColor: const Color(0xFF0EA5E9),
                                    value: _includeDoorLogs,
                                    onChanged: (v) =>
                                        setState(() => _includeDoorLogs = v),
                                    isLight: isLight,
                                    textColor: textColor,
                                    subTextColor: subTextColor,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // CARD 3: REPORT PREVIEW & GENERATE CTA
                            Container(
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: borderColor),
                              ),
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFF0EA5E9)
                                              .withValues(
                                                  alpha: isLight ? 0.12 : 0.16),
                                        ),
                                        child: const Icon(
                                          Icons.description_outlined,
                                          size: 18,
                                          color: Color(0xFF0EA5E9),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Report Preview \u00B7 $_selectedCount of 4 sections',
                                              style: TextStyle(
                                                color: textColor,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd').format(_endDate)} ($daysCount ${daysCount == 1 ? 'day' : 'days'})',
                                              style: TextStyle(
                                                color: subTextColor,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: nestedBg,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isLight
                                            ? const Color(0xFFE5E7EB)
                                            : Colors.white
                                                .withValues(alpha: 0.06),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildPreviewRow(
                                          'Facility',
                                          facilityName,
                                          subTextColor,
                                          textColor,
                                        ),
                                        Divider(
                                            height: 1,
                                            thickness: 1,
                                            color: dividerColor),
                                        _buildPreviewRow(
                                          'Format',
                                          'Print-ready Report',
                                          subTextColor,
                                          textColor,
                                        ),
                                        Divider(
                                            height: 1,
                                            thickness: 1,
                                            color: dividerColor),
                                        _buildPreviewRow(
                                          'Site Health',
                                          '100% Operational',
                                          subTextColor,
                                          const Color(0xFF00B87C),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildActionButton(context, isLight),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedPreset(
    String label,
    _DatePreset preset,
    bool isLight,
    Color textColor,
    Color subTextColor, {
    VoidCallback? onTap,
  }) {
    final selected = _activePreset == preset;
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () => _applyPreset(preset),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? (isLight ? Colors.white : const Color(0xFF2B3242))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected && isLight
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? textColor : subTextColor,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedSectionTile({
    required String title,
    required String description,
    required IconData icon,
    required Color accentColor,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isLight,
    required Color textColor,
    required Color subTextColor,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: isLight ? 0.12 : 0.16),
              ),
              child: Icon(
                icon,
                size: 19,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: const Color(0xFF0EA5E9),
              activeThumbColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewRow(
    String label,
    String value,
    Color labelColor,
    Color valueColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildActionButton(BuildContext context, bool isLight) {
    final isEnabled = _selectedCount > 0 && !_isGenerating;
    final btnBg = isLight ? const Color(0xFF0F172A) : Colors.white;
    final btnFg = isLight ? Colors.white : const Color(0xFF0F172A);

    return SizedBox(
      height: 50,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: btnBg,
          disabledBackgroundColor: isLight
              ? const Color(0xFFE2E8F0)
              : const Color(0xFF1E2836),
          foregroundColor: btnFg,
          disabledForegroundColor:
              isLight ? const Color(0xFF94A3B8) : Colors.white38,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        onPressed: isEnabled ? _generatePdf : null,
        child: _isGenerating
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: btnFg,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Generating Report...',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_rounded, size: 19),
                  SizedBox(width: 8),
                  Text(
                    'Generate & Download Report',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
