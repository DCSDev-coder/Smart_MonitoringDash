import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_service.dart';
import '../../../core/utils/alarm_payload.dart';
import 'dashboard_typography.dart';

class DeviceHistorySheet extends StatefulWidget {
  final int nodeId;
  final String deviceName;
  final String deviceType;
  final String? metricCode;
  final String? iconAsset;
  final Color? iconBgColor;

  const DeviceHistorySheet({
    super.key,
    required this.nodeId,
    required this.deviceName,
    required this.deviceType,
    this.metricCode,
    this.iconAsset,
    this.iconBgColor,
  });

  @override
  State<DeviceHistorySheet> createState() => _DeviceHistorySheetState();
}

class _DeviceHistorySheetState extends State<DeviceHistorySheet> {
  bool _isLoading = true;
  Map<String, dynamic>? _nodeData;
  List<dynamic> _alarms = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    // Fetch live metrics
    final data = await ApiService.instance.fetchNodeWithMetric(widget.nodeId);
    if (data != null && data['result'] != null) {
      _nodeData = data['result'];
    }

    // For Smoke/WLD we fetch recent alarms to see if this node has any
    if (widget.deviceType == 'SMOKE' || widget.deviceType == 'WLD') {
      final alarmData = await ApiService.instance.fetchRecentAlarms();
      if (alarmData != null && alarmData['result'] != null) {
        final allAlarms = alarmData['result'] as List<dynamic>;
        _alarms = allAlarms.where((a) {
          final msg = alarmSearchText(a);
          return msg.contains(widget.deviceName.toLowerCase());
        }).toList();
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isLight ? Colors.white : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.iconAsset != null && widget.iconBgColor != null) ...[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.iconBgColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        widget.iconAsset!,
                        width: 24,
                        height: 24,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Text(
                    widget.deviceName,
                    style: bitcount(
                      context,
                      fontSize: 20,
                      color: isLight ? Colors.black : Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: isLight ? Colors.black54 : Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ))
            else if (_nodeData != null) ...[
              Text('Live Metrics',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isLight
                          ? AppTheme.lightTextSecondary
                          : Colors.white70)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isLight ? Colors.black : Colors.white)
                      .withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildMetricsList(_nodeData!['sample'] ?? []),
              ),
              const SizedBox(height: 24),
              if (widget.deviceType == 'SMOKE' ||
                  widget.deviceType == 'WLD') ...[
                Text('Recent Events',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isLight
                            ? AppTheme.lightTextSecondary
                            : Colors.white70)),
                const SizedBox(height: 12),
                if (_alarms.isEmpty)
                  Text('No recent events for this device.',
                      style: TextStyle(
                          color: isLight ? Colors.black54 : Colors.white54))
                else
                  ..._alarms
                      .map((a) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.warning_amber_rounded,
                                color: Colors.orange),
                            title: Text(alarmDisplayText(a)),
                            subtitle: Text(
                              (a['lastOccurTime'] ??
                                      a['occurrenceTime'] ??
                                      a['createTime'] ??
                                      '')
                                  .toString(),
                            ),
                          ))
                      .toList(),
              ] else ...[
                // Placeholder for a graph if needed
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: (isLight ? Colors.black : Colors.white)
                        .withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: (isLight ? Colors.black : Colors.white)
                            .withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.show_chart,
                          size: 48,
                          color: (isLight ? Colors.black : Colors.white)
                              .withValues(alpha: 0.2)),
                      const SizedBox(height: 12),
                      Text('Historical graphs coming soon',
                          style: TextStyle(
                              color: (isLight ? Colors.black : Colors.white)
                                  .withValues(alpha: 0.5))),
                    ],
                  ),
                ),
              ]
            ] else
              Text('Could not load data for this device.',
                  style: TextStyle(
                      color: isLight ? Colors.black54 : Colors.white54)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsList(List<dynamic> samples) {
    if (samples.isEmpty) return const Text('No metrics available');
    return Column(
      children: samples.map((s) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Text(s['name'] ?? '',
                      style: const TextStyle(fontSize: 13))),
              Text('${s['value'] ?? ''} ${s['unit'] ?? ''}'.trim(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
