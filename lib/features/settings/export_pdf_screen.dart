import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/background_layer.dart';
import '../../shared/utils/app_toast.dart';
import '../../core/utils/pdf_generator_service.dart';

class ExportPdfScreen extends StatefulWidget {
  const ExportPdfScreen({super.key});

  @override
  State<ExportPdfScreen> createState() => _ExportPdfScreenState();
}

class _ExportPdfScreenState extends State<ExportPdfScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  bool _includeEnvironment = true;
  bool _includePower = true;
  bool _includeAlarms = true;
  bool _includeDoorLogs = true;

  bool _isGenerating = false;

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime initialDate = isStart ? _startDate : _endDate;
    final DateTime firstDate = DateTime(2020);
    final DateTime lastDate = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.accentBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
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
    if (!_includeEnvironment &&
        !_includePower &&
        !_includeAlarms &&
        !_includeDoorLogs) {
      AppToast.showError(context, 'Please select at least one data section to include.');
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

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final topPad = media.padding.top;
    final dateFormat = DateFormat('MMM dd, yyyy');

    final textColor = isLight ? AppTheme.lightTextPrimary : Colors.white;
    final subTextColor = isLight ? AppTheme.lightTextSecondary : Colors.white70;

    return Scaffold(
      backgroundColor: isLight
          ? const Color.fromARGB(255, 247, 251, 255)
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
                top: topPad + 70,
                bottom: media.padding.bottom + 32,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Export PDF Report',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Configure a custom, high-resolution A4 report for printing or sharing with clients.',
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionHeader('DATE RANGE', isLight),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateButton(
                              context,
                              label: 'Start Date',
                              dateStr: dateFormat.format(_startDate),
                              onTap: () => _selectDate(context, true),
                              isLight: isLight,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDateButton(
                              context,
                              label: 'End Date',
                              dateStr: dateFormat.format(_endDate),
                              onTap: () => _selectDate(context, false),
                              isLight: isLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),
                      _buildSectionHeader('INCLUDE SECTIONS', isLight),
                      const SizedBox(height: 12),
                      _buildToggleRow(
                        'Environment Metrics',
                        'Temperature & Humidity trends',
                        Icons.thermostat_rounded,
                        _includeEnvironment,
                        (v) => setState(() => _includeEnvironment = v),
                        isLight,
                      ),
                      _buildToggleRow(
                        'Power & PUE',
                        'Energy consumption analytics',
                        Icons.bolt_rounded,
                        _includePower,
                        (v) => setState(() => _includePower = v),
                        isLight,
                      ),
                      _buildToggleRow(
                        'Alarm History',
                        'Detailed table of all triggered alarms',
                        Icons.warning_rounded,
                        _includeAlarms,
                        (v) => setState(() => _includeAlarms = v),
                        isLight,
                      ),
                      _buildToggleRow(
                        'Door Access Logs',
                        'Detailed table of all physical rack openings',
                        Icons.meeting_room_rounded,
                        _includeDoorLogs,
                        (v) => setState(() => _includeDoorLogs = v),
                        isLight,
                      ),
                      const SizedBox(height: 48), // Spacing before the button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.accentBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _isGenerating ? null : _generatePdf,
                          child: _isGenerating
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.download_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Generate & Download PDF',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF1C222B) : Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isLight) {
    return Text(
      title,
      style: TextStyle(
        color: isLight
            ? AppTheme.lightTextPrimary.withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.5),
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDateButton(
    BuildContext context, {
    required String label,
    required String dateStr,
    required VoidCallback onTap,
    required bool isLight,
  }) {
    final bgColor = isLight
        ? Colors.white
        : const Color(0xFF1E242B);
    final borderColor = isLight
        ? Colors.black.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isLight
                    ? AppTheme.lightTextSecondary
                    : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: isLight ? AppTheme.accentBlue : Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
    bool isLight,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLight
              ? Colors.white
              : const Color(0xFF1E242B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLight
                ? Colors.black.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isLight
                    ? AppTheme.accentBlue.withValues(alpha: 0.1)
                    : AppTheme.accentBlue.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppTheme.accentBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isLight
                          ? AppTheme.lightTextSecondary
                          : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: value,
              onChanged: _isGenerating ? null : onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: AppTheme.accentBlue,
              inactiveThumbColor: isLight
                  ? const Color(0xFFEDEDED)
                  : Colors.white.withValues(alpha: 0.85),
              inactiveTrackColor: isLight
                  ? const Color(0xFF3F3F3F)
                  : Colors.white.withValues(alpha: 0.18),
            ),
          ],
        ),
      ),
    );
  }
}
