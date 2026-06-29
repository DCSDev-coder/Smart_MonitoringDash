import 'package:flutter/foundation.dart';
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
  final List<dynamic>? alarms;

  const DeviceHistorySheet({
    super.key,
    required this.nodeId,
    required this.deviceName,
    required this.deviceType,
    this.metricCode,
    this.iconAsset,
    this.iconBgColor,
    this.alarms,
  });

  @override
  State<DeviceHistorySheet> createState() => _DeviceHistorySheetState();
}

class _DeviceHistorySheetState extends State<DeviceHistorySheet> {
  bool _isLoading = true;
  Map<String, dynamic>? _nodeData;
  List<dynamic> _alarms = [];
  final ScrollController _scrollController = ScrollController();

  bool get _showPreviewIssues => !kReleaseMode && _alarms.isEmpty;

  List<Map<String, dynamic>> get _displayAlarms {
    if (_alarms.isNotEmpty) {
      return _alarms.whereType<Map>().map((alarm) {
        return alarm.cast<String, dynamic>();
      }).toList();
    }
    if (!_showPreviewIssues) return const [];
    return _previewIssuesForDevice();
  }

  List<Map<String, dynamic>> _previewIssuesForDevice() {
    final now = DateTime.now().toIso8601String();
    final device = widget.deviceName.trim().isEmpty
        ? (widget.deviceType.isEmpty ? 'Hardware' : widget.deviceType)
        : widget.deviceName.trim();
    final type = widget.deviceType.toUpperCase().trim();

    String title;
    String content;
    switch (type) {
      case 'AC':
        title = '$device temperature warning';
        content =
            'Preview active issue: supply air temperature is above target.';
        break;
      case 'T&H':
        title = '$device environment alarm';
        content =
            'Preview active issue: cabinet temperature or humidity is out of range.';
        break;
      case 'PDU':
        title = '$device overload alarm';
        content = 'Preview active issue: PDU load is above the safe threshold.';
        break;
      case 'UPS':
        title = '$device battery alarm';
        content =
            'Preview active issue: UPS battery or bypass condition needs attention.';
        break;
      case 'SMOKE':
        title = '$device smoke alarm';
        content = 'Preview active issue: smoke detector is reporting an alarm.';
        break;
      case 'WLD':
        title = '$device leak alarm';
        content =
            'Preview active issue: water leak detector is reporting an alarm.';
        break;
      case 'POWER':
        title = '$device power alarm';
        content =
            'Preview active issue: power quality or load condition needs attention.';
        break;
      default:
        title = '$device active issue';
        content = 'Preview active issue for this hardware.';
        break;
    }

    return [
      <String, dynamic>{
        'alarmItem': title,
        'alarmName': title,
        'content': content,
        'alarmTypeName': 'Preview',
        'statusTxt': 'active',
        'occurrenceTime': now,
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    // Fetch live metrics
    final data = await ApiService.instance.fetchNodeWithMetric(widget.nodeId);
    if (data != null && data['result'] != null) {
      _nodeData = data['result'];
    }

    final sourceAlarms = (widget.alarms != null && widget.alarms!.isNotEmpty)
        ? widget.alarms!
        : await _fetchRecentAlarms();
    _alarms = sourceAlarms.where(_isRelevantAlarm).toList();

    if (_alarms.isEmpty && widget.deviceType == 'SMOKE') {
      _alarms = sourceAlarms
          .where((a) => alarmSearchText(a).contains('smoke'))
          .where((a) => !alarmIsResolved(a))
          .toList();
    } else if (_alarms.isEmpty && widget.deviceType == 'WLD') {
      _alarms = sourceAlarms
          .where((a) =>
              alarmSearchText(a).contains('leak') ||
              alarmSearchText(a).contains('water') ||
              alarmSearchText(a).contains('flood'))
          .where((a) => !alarmIsResolved(a))
          .toList();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<List<dynamic>> _fetchRecentAlarms() async {
    final alarmData = await ApiService.instance.fetchRecentAlarms();
    if (alarmData != null && alarmData['result'] != null) {
      return (alarmData['result'] as List<dynamic>).toList();
    }
    return const [];
  }

  bool _isRelevantAlarm(dynamic alarm) {
    if (alarmIsResolved(alarm)) return false;

    final msg = alarmSearchText(alarm);
    if (msg.isEmpty) return false;

    final deviceName = widget.deviceName.toLowerCase().trim();
    final type = widget.deviceType.toUpperCase().trim();

    if (deviceName.isNotEmpty && msg.contains(deviceName)) return true;

    if (type == 'SMOKE') {
      return msg.contains('smoke') || msg.contains('fire');
    }
    if (type == 'WLD') {
      return msg.contains('leak') ||
          msg.contains('water') ||
          msg.contains('flood') ||
          msg.contains('moisture');
    }
    if (type == 'AC') {
      return msg.contains('ac') ||
          msg.contains('air con') ||
          msg.contains('aircond') ||
          msg.contains('cooling') ||
          msg.contains('compressor') ||
          msg.contains('fan');
    }
    if (type == 'UPS') {
      return msg.contains('ups') ||
          msg.contains('battery') ||
          msg.contains('bypass');
    }
    if (type == 'PDU') {
      return msg.contains('pdu') || msg.contains(deviceName);
    }
    if (type == 'POWER') {
      return msg.contains('power') ||
          msg.contains('volt') ||
          msg.contains('amp') ||
          msg.contains('load');
    }
    if (type == 'T&H') {
      final cabMatch = RegExp(r'cabinet\s*(\d+)').firstMatch(deviceName);
      final cab = cabMatch?.group(1);
      if (cab != null && msg.contains('cabinet') && msg.contains(cab)) {
        final isFront = deviceName.contains('front');
        final isBack =
            deviceName.contains('back') || deviceName.contains('rear');
        if (isFront && (msg.contains('front') || msg.contains('door 1'))) {
          return true;
        }
        if (isBack &&
            (msg.contains('back') ||
                msg.contains('rear') ||
                msg.contains('door 2'))) {
          return true;
        }
      }
      return msg.contains('temp') ||
          msg.contains('humid') ||
          msg.contains('t&h') ||
          msg.contains('cabinet');
    }

    return msg.contains(deviceName) || msg.contains(type.toLowerCase());
  }

  String _issueTime(dynamic alarm) {
    final raw = (alarm is Map)
        ? (alarm['lastOccurTime'] ??
            alarm['occurrenceTime'] ??
            alarm['createTime'] ??
            alarm['alarmTime'] ??
            alarm['recordTime'] ??
            '')
        : '';
    return raw.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final alarmsToShow = _displayAlarms;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isLight ? Colors.white : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (widget.iconAsset != null &&
                          widget.iconBgColor != null) ...[
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
                      ),
                    )
                  else if (_nodeData != null) ...[
                    Text(
                      'Live Metrics',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isLight
                            ? AppTheme.lightTextSecondary
                            : Colors.white70,
                      ),
                    ),
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
                    if (_showPreviewIssues)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3CD),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                const Color(0xFFFFC107).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'Preview mode: sample active issue shown because no live alarm is active.',
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF7A4B00)
                                : Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (alarmsToShow.isNotEmpty) ...[
                      Text(
                        'Recent Unresolved Issues',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isLight
                              ? AppTheme.lightTextSecondary
                              : Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...alarmsToShow.map((a) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: (isLight ? Colors.black : Colors.white)
                                  .withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFFF3B30)
                                    .withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: Colors.orange, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        alarmDisplayText(a),
                                        style: TextStyle(
                                          color: isLight
                                              ? AppTheme.lightTextPrimary
                                              : Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _issueTime(a).isEmpty
                                            ? 'Unresolved issue'
                                            : '${_issueTime(a)} • unresolved',
                                        style: TextStyle(
                                          color: isLight
                                              ? AppTheme.lightTextSecondary
                                              : Colors.white60,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ] else ...[
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
                                    color:
                                        (isLight ? Colors.black : Colors.white)
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
          ),
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
