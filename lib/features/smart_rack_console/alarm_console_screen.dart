import 'package:flutter/material.dart';

import '../../../core/network/api_service.dart';
import '../../../core/network/cpanel_api_service.dart';
import '../../../core/network/adapter_api_service.dart';
import '../../../core/config/site_runtime_config.dart';
import '../../../core/utils/app_log.dart';
import '../report/report_screen.dart'; // To get ExpandableHistoricalAlarmCard
import 'theme/console_theme.dart';
import 'widgets/console_section_card.dart';

class AlarmConsoleScreen extends StatefulWidget {
  final bool compact;

  const AlarmConsoleScreen({
    super.key,
    required this.compact,
  });

  @override
  State<AlarmConsoleScreen> createState() => _AlarmConsoleScreenState();
}

class _AlarmConsoleScreenState extends State<AlarmConsoleScreen> {
  bool _fetchingHistoricalEvents = false;
  List<dynamic> _reportAlarms = [];
  String _eventFilter = 'Recent'; // Default

  @override
  void initState() {
    super.initState();
    _fetchHistoricalEvents();
  }

  int _eventRangeStartFor(DateTime now) {
    switch (_eventFilter) {
      case 'Recent':
        return now.subtract(const Duration(days: 3)).millisecondsSinceEpoch;
      case 'Monthly':
        return now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
      case 'Weekly':
      default:
        return now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    }
  }

  bool _shouldUseAdapter(int? siteId) {
    return AdapterApiService.instance.isConfigured && siteId != null;
  }

  Future<void> _fetchHistoricalEvents() async {
    if (!mounted) return;
    setState(() => _fetchingHistoricalEvents = true);
    try {
      final now = DateTime.now();
      final int startTime = _eventRangeStartFor(now);
      final int endTime = now.millisecondsSinceEpoch;

      final siteId = SiteRuntimeConfig.siteId(
        CpanelApiService.instance.currentSite,
      );

      Map<String, dynamic>? res;
      if (_shouldUseAdapter(siteId)) {
        final sid = siteId!;
        res = await AdapterApiService.instance.fetchReportAlarms(
          siteId: sid,
          startTime: startTime,
          endTime: endTime,
          page: 1,
          pageSize: 50,
        );
      }

      if (!_shouldUseAdapter(siteId)) {
        res ??= await ApiService.instance
            .fetchReportAlarms(startTime: startTime, endTime: endTime);
      }

      if (mounted) {
        setState(() {
          _reportAlarms = (res?['result']?['records'] as List?) ?? [];
          _fetchingHistoricalEvents = false;
        });
      }
    } catch (e) {
      AppLog.w('Event fetch error', tag: 'AlarmConsoleScreen', error: e);
      if (mounted) setState(() => _fetchingHistoricalEvents = false);
    }
  }

  Widget _buildEventFilterRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ['Recent', 'Weekly', 'Monthly'].map((filter) {
        final isSelected = _eventFilter == filter;
        return GestureDetector(
          onTap: () {
            if (!isSelected) {
              setState(() {
                _eventFilter = filter;
              });
              _fetchHistoricalEvents();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? ConsoleTheme.primaryBlue(context) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? ConsoleTheme.primaryBlue(context) : ConsoleTheme.divider(context),
              ),
            ),
            child: Text(
              filter,
              style: TextStyle(
                color: isSelected ? Colors.white : ConsoleTheme.textSecondary(context),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: ConsoleTheme.pageBgGradient(context),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ConsoleTheme.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Historical Alarms', style: TextStyle(color: ConsoleTheme.textPrimary(context), fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            _buildEventFilterRow(),
            const SizedBox(height: 24),
            ConsoleSectionCard(
              title: 'Alarm Records',
              child: _fetchingHistoricalEvents
                  ? const SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _reportAlarms.isEmpty
                      ? SizedBox(
                          height: 200,
                          child: Center(
                            child: Text(
                              'No historical alarms found for this period.',
                              style: TextStyle(
                                color: ConsoleTheme.textSecondary(context),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _reportAlarms.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            return ExpandableHistoricalAlarmCard(alarm: _reportAlarms[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
