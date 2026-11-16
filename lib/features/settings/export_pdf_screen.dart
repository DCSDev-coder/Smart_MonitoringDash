import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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
    final topPad = media.padding.top;
    final dateFormat = DateFormat('MMM dd, yyyy');

    final textColor = isLight ? AppTheme.lightTextPrimary : Colors.white;
    final subTextColor = isLight ? AppTheme.lightTextSecondary : Colors.white70;
    final daysCount = _endDate.difference(_startDate).inDays.abs() + 1;

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
            child: ListView(
              padding: EdgeInsets.only(
                top: topPad + 16,
                bottom: media.padding.bottom + 36,
                left: 24,
                right: 24,
              ),
              children: [
                // Top Back Button
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildBackPill(context, isLight, textColor),
                ),
                const SizedBox(height: 18),

                // Main Title & Description
                Text(
                  'Export PDF Report',
                  style: GoogleFonts.manrope(
                    color: textColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Configure a custom, high-resolution report for printing or sharing with clients.',
                  style: GoogleFonts.manrope(
                    color: subTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),

                    // SECTION 1: DATE RANGE
                    _buildSectionHeader(
                      title: 'DATE RANGE',
                      actionLabel: '$daysCount ${daysCount == 1 ? 'day' : 'days'} selected',
                      actionColor: AppTheme.accentBlue,
                      isLight: isLight,
                    ),
                    const SizedBox(height: 12),

                    // Quick Preset Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPresetChip('Last 24 Hours', _DatePreset.last24Hours, isLight),
                          const SizedBox(width: 8),
                          _buildPresetChip('Last 7 Days', _DatePreset.last7Days, isLight),
                          const SizedBox(width: 8),
                          _buildPresetChip('Last 30 Days', _DatePreset.last30Days, isLight),
                          const SizedBox(width: 8),
                          _buildPresetChip('This Month', _DatePreset.thisMonth, isLight),
                          const SizedBox(width: 8),
                          _buildPresetChip('Custom', _DatePreset.custom, isLight, onTap: () => _pickDateRange(context)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Date range picker card
                    _buildDateRangeCard(
                      context,
                      dateFormat: dateFormat,
                      isLight: isLight,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),

                    const SizedBox(height: 32),

                    // SECTION 2: INCLUDE SECTIONS
                    _buildSectionHeader(
                      title: 'INCLUDE SECTIONS',
                      actionLabel: _allSelected ? 'Deselect All' : 'Select All',
                      onActionTap: _toggleAllSections,
                      actionColor: AppTheme.accentBlue,
                      trailingBadge: '$_selectedCount of 4',
                      isLight: isLight,
                    ),
                    const SizedBox(height: 12),

                    // Unified grouped or individual cards
                    _buildSectionCard(
                      title: 'Environment Metrics',
                      subtitle: 'Temperature & Humidity trends, rack climate status',
                      tag: 'Climate & Sensors',
                      icon: Icons.thermostat_rounded,
                      accentColor: const Color(0xFF00C08B),
                      value: _includeEnvironment,
                      onChanged: (v) => setState(() => _includeEnvironment = v),
                      isLight: isLight,
                    ),
                    const SizedBox(height: 10),

                    _buildSectionCard(
                      title: 'Power & PUE',
                      subtitle: 'Energy consumption, phase loads & PUE efficiency',
                      tag: 'Electrical Analytics',
                      icon: Icons.bolt_rounded,
                      accentColor: const Color(0xFFFF9500),
                      value: _includePower,
                      onChanged: (v) => setState(() => _includePower = v),
                      isLight: isLight,
                    ),
                    const SizedBox(height: 10),

                    _buildSectionCard(
                      title: 'Alarm History',
                      subtitle: 'Detailed chronological table of all triggered alarms',
                      tag: 'Security & Warnings',
                      icon: Icons.warning_amber_rounded,
                      accentColor: const Color(0xFFFF4C4C),
                      value: _includeAlarms,
                      onChanged: (v) => setState(() => _includeAlarms = v),
                      isLight: isLight,
                    ),
                    const SizedBox(height: 10),

                    _buildSectionCard(
                      title: 'Door Access Logs',
                      subtitle: 'Audit trail of physical rack door openings, RFID & keys',
                      tag: 'Access Control',
                      icon: Icons.meeting_room_rounded,
                      accentColor: const Color(0xFF3B82F6),
                      value: _includeDoorLogs,
                      onChanged: (v) => setState(() => _includeDoorLogs = v),
                      isLight: isLight,
                    ),

                    const SizedBox(height: 28),

                    // Summary preview bar
                    _buildSummaryPreview(isLight, textColor, subTextColor, daysCount),

                    const SizedBox(height: 20),

                    // Generate & Download PDF Button
                    _buildActionButton(context, isLight),
                  ],
                ),
              ),
            ],
          ),
        );
      }

  Widget _buildBackPill(BuildContext context, bool isLight, Color textColor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isLight ? Colors.white : const Color(0xFF131D2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isLight
                  ? Colors.black.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLight ? 0.04 : 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            size: 20,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? actionLabel,
    VoidCallback? onActionTap,
    Color? actionColor,
    String? trailingBadge,
    required bool isLight,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            color: isLight
                ? AppTheme.lightTextPrimary.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        if (trailingBadge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.black.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              trailingBadge,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isLight ? AppTheme.lightTextSecondary : Colors.white70,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (actionLabel != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              actionLabel,
              style: GoogleFonts.manrope(
                color: actionColor ?? AppTheme.accentBlue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPresetChip(
    String label,
    _DatePreset preset,
    bool isLight, {
    VoidCallback? onTap,
  }) {
    final isSelected = _activePreset == preset;
    final activeBg = AppTheme.accentBlue.withValues(alpha: isLight ? 0.12 : 0.22);
    final inactiveBg = isLight ? Colors.white : const Color(0xFF131D2A);
    final borderColor = isSelected
        ? AppTheme.accentBlue
        : (isLight
            ? Colors.black.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.10));

    return InkWell(
      onTap: onTap ?? () => _applyPreset(preset),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isSelected ? 1.4 : 1),
          boxShadow: isLight && !isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            color: isSelected
                ? AppTheme.accentBlue
                : (isLight ? AppTheme.lightTextPrimary : Colors.white70),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeCard(
    BuildContext context, {
    required DateFormat dateFormat,
    required bool isLight,
    required Color textColor,
    required Color subTextColor,
  }) {
    final cardBg = isLight ? Colors.white : const Color(0xFF131D2A);
    final borderColor = isLight
        ? Colors.black.withValues(alpha: 0.07)
        : Colors.white.withValues(alpha: 0.10);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.03 : 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Start Date Box
          Expanded(
            child: _buildDateSubCard(
              context,
              label: 'START DATE',
              dateStr: dateFormat.format(_startDate),
              isLight: isLight,
              onTap: () => _selectSingleDate(context, true),
            ),
          ),

          // Central Connector / Range Picker Quick Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _pickDateRange(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isLight
                        ? const Color(0xFFF0F4F8)
                        : const Color(0xFF1C2735),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: AppTheme.accentBlue,
                  ),
                ),
              ),
            ),
          ),

          // End Date Box
          Expanded(
            child: _buildDateSubCard(
              context,
              label: 'END DATE',
              dateStr: dateFormat.format(_endDate),
              isLight: isLight,
              onTap: () => _selectSingleDate(context, false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSubCard(
    BuildContext context, {
    required String label,
    required String dateStr,
    required bool isLight,
    required VoidCallback onTap,
  }) {
    final subBg = isLight ? const Color(0xFFF9FBFE) : const Color(0xFF0F1722);
    final borderColor = isLight
        ? Colors.black.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.06);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: subBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: AppTheme.accentBlue.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isLight
                        ? AppTheme.lightTextSecondary.withValues(alpha: 0.8)
                        : Colors.white54,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              dateStr,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isLight ? AppTheme.lightTextPrimary : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required String tag,
    required IconData icon,
    required Color accentColor,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isLight,
  }) {
    final cardBg = isLight ? Colors.white : const Color(0xFF131D2A);
    final borderColor = value
        ? accentColor.withValues(alpha: isLight ? 0.35 : 0.45)
        : (isLight
            ? Colors.black.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.08));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isGenerating ? null : () => onChanged(!value),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: value ? 1.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: value
                    ? accentColor.withValues(alpha: isLight ? 0.05 : 0.12)
                    : Colors.black.withValues(alpha: isLight ? 0.02 : 0.15),
                blurRadius: value ? 12 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Styled icon circle with soft tinted backdrop
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: value ? 0.14 : 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accentColor.withValues(alpha: value ? 0.30 : 0.15),
                  ),
                ),
                child: Icon(
                  icon,
                  color: value ? accentColor : accentColor.withValues(alpha: 0.5),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // Title, Subtitle, and mini badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: GoogleFonts.manrope(
                              color: isLight
                                  ? (value ? AppTheme.lightTextPrimary : AppTheme.lightTextPrimary.withValues(alpha: 0.7))
                                  : (value ? Colors.white : Colors.white70),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isLight
                                ? const Color(0xFFF0F4F8)
                                : const Color(0xFF1A2330),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isLight
                                  ? AppTheme.lightTextSecondary
                                  : Colors.white60,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.manrope(
                        color: isLight
                            ? AppTheme.lightTextSecondary.withValues(alpha: 0.8)
                            : Colors.white54,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Modern Toggle Switch
              Switch(
                value: value,
                onChanged: _isGenerating ? null : onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: AppTheme.accentBlue,
                inactiveThumbColor: isLight
                    ? const Color(0xFFCBD5E1)
                    : Colors.white.withValues(alpha: 0.7),
                inactiveTrackColor: isLight
                    ? const Color(0xFFE2E8F0)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryPreview(
    bool isLight,
    Color textColor,
    Color subTextColor,
    int daysCount,
  ) {
    final dateFormat = DateFormat('MMM dd');
    final rangeText = '${dateFormat.format(_startDate)} – ${dateFormat.format(_endDate)} ($daysCount ${daysCount == 1 ? 'day' : 'days'})';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLight
            ? const Color(0xFFF1F5F9)
            : const Color(0xFF0F1621),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.article_outlined,
              size: 18,
              color: AppTheme.accentBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PDF Report Preview • $_selectedCount of 4 sections',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Reporting timeframe: $rangeText',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, bool isLight) {
    final isEnabled = _selectedCount > 0 && !_isGenerating;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: AppTheme.accentBlue.withValues(alpha: isLight ? 0.35 : 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.accentBlue,
          disabledBackgroundColor: isLight
              ? const Color(0xFFE2E8F0)
              : const Color(0xFF1E2836),
          foregroundColor: Colors.white,
          disabledForegroundColor: isLight
              ? const Color(0xFF94A3B8)
              : Colors.white38,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        onPressed: isEnabled ? _generatePdf : null,
        child: _isGenerating
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Generating PDF Report...',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.download_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Generate & Download PDF',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
