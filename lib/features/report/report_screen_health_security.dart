part of 'report_screen.dart';

extension _ReportScreenHealthSecurity on _ReportScreenState {
  Widget _buildMaintenancePage(double hPadding) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hPadding, 0, hPadding, 24),
      child: Column(
        children: [
          _buildDiagnosticsSection(),
          const SizedBox(height: 24),
          _buildIssuesSection(),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _activeCurrentAlarms() {
    return _poller.recentAlarms
        .whereType<Map>()
        .map((alarm) => alarm.cast<String, dynamic>())
        .where((alarm) => !alarmIsResolved(alarm))
        .toList();
  }

  Widget _buildIssuesSection() {
    final issues = _combinedIssues();
    final isLight = Theme.of(context).brightness == Brightness.light;

    return DashboardGlass(
      radius: 22,
      padding: const EdgeInsets.all(18),
      tint: isLight
          ? Colors.white
          : const Color(0xFF111922).withValues(alpha: 0.92),
      borderColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ISSUES',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              _buildEventFilterRow(),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGapSm),
          if (_fetchingHistoricalEvents && issues.isEmpty)
            const SizedBox(
              height: 100,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (issues.isEmpty)
            _buildSectionEmptyState('No issues right now.')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: issues.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return ExpandableHistoricalAlarmCard(
                  alarm: issues[index],
                );
              },
            ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _combinedIssues() {
    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};

    void addIssue(dynamic alarm) {
      if (alarm is! Map) return;
      final item = alarm.cast<String, dynamic>();
      final key = _issueKey(item);
      if (seen.add(key)) {
        merged.add(item);
      }
    }

    for (final alarm in _activeCurrentAlarms()) {
      addIssue(alarm);
    }

    for (final alarm in _reportAlarms) {
      addIssue(alarm);
    }

    merged.sort((a, b) {
      final aTime = _issueSortTime(a);
      final bTime = _issueSortTime(b);
      return bTime.compareTo(aTime);
    });

    return merged;
  }

  String _issueKey(Map<String, dynamic> alarm) {
    final parts = <String>[
      (alarm['collectControlNodeName'] ??
              alarm['name'] ??
              alarm['alarmName'] ??
              '')
          .toString()
          .trim()
          .toLowerCase(),
      (alarm['occurrenceTime'] ??
              alarm['createTime'] ??
              alarm['timestamp'] ??
              alarm['opTime'] ??
              '')
          .toString()
          .trim(),
      (alarm['alarmItem'] ?? alarm['content'] ?? alarm['alarmTypeName'] ?? '')
          .toString()
          .trim()
          .toLowerCase(),
    ];
    return parts.join('|');
  }

  DateTime _issueSortTime(Map<String, dynamic> alarm) {
    final raw = alarm['occurrenceTime'] ??
        alarm['createTime'] ??
        alarm['timestamp'] ??
        alarm['opTime'] ??
        alarm['lastOccurTime'] ??
        alarm['recoverTime'] ??
        alarm['recoveryTime'] ??
        '';
    final parsed = raw is DateTime
        ? raw
        : DateTime.tryParse(raw.toString().replaceFirst(' ', 'T'));
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  Widget _buildSectionEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.light
              ? AppTheme.lightTextPrimary
              : Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDiagnosticsSection() {
    final isWide = MediaQuery.sizeOf(context).width >= 1100;
    if (isWide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildConnectivityMatrix()),
            const SizedBox(width: 18),
            Expanded(child: _buildMaintenanceCard()),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConnectivityMatrix(),
        const SizedBox(height: 24),
        _buildMaintenanceCard(),
      ],
    );
  }

  Widget _buildMaintenanceCard() {
    final isOverdue = _lastMaintenance != null &&
        DateTime.now().difference(_lastMaintenance!).inDays >= 90;
    final isLight = Theme.of(context).brightness == Brightness.light;
    const orange = Color(0xFFFF7A00);

    final cardBg = isLight ? const Color(0xFFFF8A3D) : const Color(0xFF2D1A0D);
    final updateBtnBg =
        isLight ? const Color(0xFFC86A2C) : const Color(0xFF8E4A1E);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isOverdue ? Colors.redAccent : orange,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOverdue
                  ? Icons.warning_amber_rounded
                  : Icons.construction_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Last Service',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _lastMaintenance == null
                          ? 'No Service Record'
                          : DateFormat('d MMMM yyyy').format(_lastMaintenance!),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isOverdue ? Colors.redAccent : Colors.white,
                      ),
                    ),
                    // const SizedBox(width: 8),
                    // if (_lastMaintenance != null)
                    //   Text(
                    //     '( $days Days Ago )',
                    //     style: TextStyle(
                    //       color: Colors.white.withValues(alpha: 0.92),
                    //       fontSize: 14,
                    //       fontWeight: FontWeight.w600,
                    //     ),
                    //   ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _pickMaintenanceDate,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: updateBtnBg,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMaintenanceDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _lastMaintenance ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final theme = Theme.of(context);
        final isLight = theme.brightness == Brightness.light;
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: AppTheme.accentBlue,
              surface: isLight ? Colors.white : const Color(0xFF0B0F14),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: isLight ? Colors.white : const Color(0xFF0B0F14),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && _siteId != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(picked);
      final success = await CpanelApiService.instance
          .updateMaintenanceDate(_siteId!, dateStr);

      if (mounted) {
        if (success) {
          _applyMaintenanceDate(picked, dateStr);
          AppToast.showSuccess(
              context, 'Maintenance date updated successfully');
        } else {
          AppToast.showError(context, 'Failed to update maintenance date');
        }
      }
    }
  }

  Widget _buildConnectivityMatrix() {
    int siteCount = 0;
    int siteOnline = 0;
    if (_smokeStatus != -1) {
      siteCount++;
      if (_smokeStatus == 0) siteOnline++;
    }
    if (_floodStatus != -1) {
      siteCount++;
      if (_floodStatus == 0) siteOnline++;
    }

    final int total = _devices.fold<int>(
          0,
          (sum, d) => sum + (d['totalCount'] as int? ?? 0),
        ) +
        siteCount;
    final int online = _devices.fold<int>(
          0,
          (sum, d) => sum + (d['normalCount'] as int? ?? 0),
        ) +
        siteOnline;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return DashboardGlass(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      tint: isLight
          ? Colors.white
          : const Color(0xFF111922).withValues(alpha: 0.92),
      borderColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Devices Status',
                style: TextStyle(
                  color: isLight
                      ? AppTheme.lightTextSecondary
                      : Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '$online/${total == 0 ? '--' : total}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.accentGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (total > 0)
            Row(
              children: List.generate(total, (index) {
                final isOnline = index < online;
                return Expanded(
                  child: Container(
                    height: 28,
                    margin: EdgeInsets.only(right: index == total - 1 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: isOnline ? AppTheme.accentGreen : Colors.redAccent,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: isOnline && !isLight
                          ? [
                              BoxShadow(
                                color: AppTheme.accentGreen
                                    .withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                  ),
                );
              }),
            )
          else
            Text(
              'No devices found',
              style: TextStyle(
                fontSize: 14,
                color: isLight ? Colors.grey[600] : Colors.white54,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSecurityPage(double hPadding) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hPadding, 0, hPadding, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACCESS LOGS',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).brightness == Brightness.light
                      ? AppTheme.lightTextPrimary
                      : Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              _buildEventFilterRow(),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGapSm),
          if (_fetchingDoorLogs)
            const SizedBox(
              height: 100,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_doorLogs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No security events found.',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.light
                      ? AppTheme.lightTextPrimary
                      : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            _buildCategorizedLogs(_doorLogs),
        ],
      ),
    );
  }

  Widget _buildCategorizedLogs(List<dynamic> logs) {
    if (logs.isEmpty) return const SizedBox.shrink();

    final isLight = Theme.of(context).brightness == Brightness.light;
    final Map<String, List<dynamic>> groupedLogs = {};

    for (final log in logs) {
      final timeStr = log['opTime']?.toString() ?? '';
      final dt = DateTime.tryParse(timeStr);
      String category = 'Unknown Date';

      if (dt != null) {
        if (_eventLogRange == 'Monthly') {
          category = DateFormat('MMMM dd, yyyy').format(dt);
        } else if (_eventLogRange == 'Weekly') {
          category = DateFormat('EEEE, MMMM dd').format(dt);
        } else {
          category = DateFormat('MMMM dd, yyyy').format(dt);
        }
      }

      groupedLogs.putIfAbsent(category, () => []).add(log);
    }

    final children = <Widget>[];
    for (final entry in groupedLogs.entries) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
          child: Text(
            entry.key.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: isLight
                  ? AppTheme.lightTextSecondary
                  : Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
      );

      for (int i = 0; i < entry.value.length; i++) {
        children.add(_buildReportLogItem(entry.value[i]));
        if (i < entry.value.length - 1) {
          children.add(const SizedBox(height: 8));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildReportLogItem(dynamic log) {
    final String rawName = log['accessName']?.toString() ?? 'Unknown Door';
    String name = rawName.replaceAll(RegExp(r'Cabinet Item \d+'), '').trim();
    if (name.isEmpty) name = rawName;

    final int status = int.tryParse(log['op']?.toString() ?? '') ?? -1;
    final String timeStr = log['opTime']?.toString() ?? '';

    String user =
        (log['opUser'] ?? log['openUser'] ?? log['userName'] ?? log['username'])
                ?.toString() ??
            '';

    String timeLabel = '--:--';
    String dateLabel = '--/--';

    DateTime? dt = DateTime.tryParse(timeStr);
    if (dt != null) {
      timeLabel = DateFormat('hh:mm a').format(dt);
      dateLabel = DateFormat('MMM dd, yyyy').format(dt);
    }

    final isOpened = status == 1;
    final isLight = Theme.of(context).brightness == Brightness.light;
    const orange = Color(0xFFFF8A00);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white
            : const Color(0xFF111922).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: 0.10)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isLight
                  ? orange.withValues(alpha: 0.14)
                  : (isOpened
                      ? AppTheme.accentGreen.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOpened ? Icons.lock_open_rounded : Icons.lock_person_rounded,
              color: isLight
                  ? orange
                  : (isOpened ? AppTheme.accentGreen : Colors.white30),
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light
                        ? AppTheme.lightTextPrimary
                        : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (user.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'User: $user',
                    style: TextStyle(
                      color: isLight
                          ? AppTheme.lightTextSecondary.withValues(alpha: 0.85)
                          : AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeLabel,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.light
                      ? AppTheme.lightTextPrimary
                      : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateLabel,
                style: TextStyle(
                  color: isLight
                      ? AppTheme.lightTextSecondary.withValues(alpha: 0.75)
                      : AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ExpandableHistoricalAlarmCard extends StatefulWidget {
  final Map alarm;
  const ExpandableHistoricalAlarmCard({super.key, required this.alarm});

  @override
  State<ExpandableHistoricalAlarmCard> createState() =>
      _ExpandableHistoricalAlarmCardState();
}

class _ExpandableHistoricalAlarmCardState
    extends State<ExpandableHistoricalAlarmCard> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    // Auto-expand if this is the target alarm clicked from Notifications Overlay
    final target = GlobalEventBus.targetHistoricalAlarm.value;
    if (target != null &&
        target['occurrenceTime'] == widget.alarm['occurrenceTime'] &&
        target['collectControlNodeName'] ==
            widget.alarm['collectControlNodeName']) {
      _isExpanded = true;
      // We don't clear the value immediately in case the list re-renders,
      // but you can choose to clear it if you only want it to happen once.
      // GlobalEventBus.targetHistoricalAlarm.value = null;
    }
  }

  String _formatTime(dynamic rawTime) {
    if (rawTime == null) return '--';
    if (rawTime is String && rawTime.isEmpty) return '--';

    DateTime? dt;
    if (rawTime is int) {
      dt = rawTime > 2000000000
          ? DateTime.fromMillisecondsSinceEpoch(rawTime)
          : DateTime.fromMillisecondsSinceEpoch(rawTime * 1000);
    } else if (rawTime is num) {
      final v = rawTime.toInt();
      dt = v > 2000000000
          ? DateTime.fromMillisecondsSinceEpoch(v)
          : DateTime.fromMillisecondsSinceEpoch(v * 1000);
    } else {
      final s = rawTime.toString().trim();
      final normalized =
          s.contains(' ') && !s.contains('T') ? s.replaceFirst(' ', 'T') : s;
      dt = DateTime.tryParse(normalized) ?? DateTime.tryParse(s);
    }

    if (dt == null) return '--';
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  Widget _buildTimelineNode(String title, String time,
      {bool isFirst = false, bool isLast = false, String? subtitle}) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 8,
                  color: isFirst
                      ? Colors.transparent
                      : (isLight ? Colors.black26 : const Color(0xFFEAA61E)),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isLight ? Colors.black54 : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color:
                            isLight ? Colors.black54 : const Color(0xFFEAA61E),
                        width: 3),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : (isLight ? Colors.black26 : const Color(0xFFEAA61E)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: isLight
                                ? Colors.black87
                                : const Color(0xFFEAA61E),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                                color:
                                    isLight ? Colors.black54 : Colors.white70,
                                fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          color: isLight
                              ? Colors.black45
                              : const Color(0xFF4C8FE1),
                          size: 14),
                      const SizedBox(width: 6),
                      Text(
                        time,
                        style: TextStyle(
                            color: isLight ? Colors.black87 : Colors.white,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alarm = widget.alarm;
    final bool resolved =
        alarm['recoveryTime'] != null || alarm['recoverTime'] != null;

    String getStatusText() {
      final String? statusTxt = alarm['statusTxt'];
      if (statusTxt != null) {
        final clean = statusTxt.trim().toLowerCase();
        if (clean == 'unconfirm' || clean == 'unconfirmed') {
          return 'Active';
        }
        if (clean == 'resolved' ||
            clean == 'recover' ||
            clean == 'recovered' ||
            clean == 'clear' ||
            clean == 'cleared') {
          return 'Resolved';
        }
        return statusTxt;
      }
      return resolved ? 'Resolved' : 'Active';
    }

    // Dahua often packs everything into a comma-separated 'content' string
    // e.g. "Alarm Item: Electric heating protection alarm,Alarm Value: Fault, Alarm Type: Device Reporting, Alarm Level: Major"
    final String rawContent = (alarm['content'] ?? '').toString();

    String extractFromContent(String key) {
      if (rawContent.isEmpty) return '';
      final parts = rawContent.split(',');
      for (final p in parts) {
        final pt = p.trim();
        if (pt.startsWith('$key:')) {
          return pt.substring(pt.indexOf(':') + 1).trim();
        }
      }
      return '';
    }

    final String extractedItem = extractFromContent('Alarm Item');
    final String extractedValue = extractFromContent('Alarm Value');
    final String extractedType = extractFromContent('Alarm Type');

    final String title = extractedItem.isNotEmpty
        ? extractedItem
        : (alarm['alarmName'] ??
                alarm['alarmItemName'] ??
                alarm['content'] ??
                alarm['alarmTypeName'] ??
                'Alert')
            .toString();

    final String cabinet =
        (alarm['deviceCabinetName'] ?? alarm['locationName'] ?? '')
            .toString()
            .trim();
    final String device = (alarm['deviceCabinetItemName'] ??
            alarm['name'] ??
            alarm['collectControlNodeName'] ??
            '')
        .toString()
        .trim();

    String subtitle = '';
    if (cabinet.isNotEmpty && device.isNotEmpty) {
      subtitle = '$cabinet / $device';
    } else if (cabinet.isNotEmpty) {
      subtitle = cabinet;
    } else if (device.isNotEmpty) {
      subtitle = device;
    }

    String alarmValue() {
      if (extractedValue.isNotEmpty) return extractedValue;
      final dynamic v = alarm['alarmValueValue'] ??
          alarm['alarmValue'] ??
          alarm['value'] ??
          alarm['alarm_value'];
      if (v == null) return '--';
      final s = v.toString().trim();
      return s.isEmpty ? '--' : s;
    }

    String valueWithUnit() {
      final v = alarmValue();
      if (v == '--') return v;
      final upper = v.toUpperCase();
      if (upper.contains('%') ||
          upper.contains('C') ||
          upper.contains('V') ||
          upper.contains('A') ||
          upper.contains('W')) {
        return v;
      }
      final content =
          (alarm['content'] ?? alarm['alarmMsg'] ?? alarm['message'] ?? '')
              .toString()
              .toUpperCase();
      if (content.contains('TEMP')) return '$v C';
      if (content.contains('HUM')) return '$v %';
      return v;
    }

    String alarmLevelName() {
      final dynamic raw = alarm['alarmLevelName'] ??
          alarm['alarmLevelLevel'] ??
          alarm['alarmLevel'] ??
          alarm['level'] ??
          alarm['severity'];
      if (raw == null) return '--';
      final s = raw.toString().trim();
      if (s.isEmpty) return '--';
      final n = int.tryParse(s);
      if (n != null) {
        switch (n) {
          case 0:
          case 1:
            return 'Info';
          case 2:
            return 'Good';
          case 3:
            return 'Moderate';
          case 4:
            return 'Critical';
          case 5:
            return 'Red';
        }
      }
      return s;
    }

    final String valueStr = valueWithUnit();

    String getRawTypeStr() {
      if (extractedType.isNotEmpty) return extractedType;
      return (alarm['alarmTypeType'] ??
              alarm['alarmTypeName'] ??
              alarm['alarmType'] ??
              alarm['type'] ??
              title)
          .toString()
          .trim();
    }

    final String rawType = getRawTypeStr();
    final String typeStr = rawType.isEmpty ? title : rawType;
    final String levelStr = alarmLevelName();

    Color baseLevelColor() {
      if (resolved) return const Color(0xFF2D8CFF);
      final l = levelStr.toLowerCase();
      if (l.contains('critical') || l.contains('orange') || l.contains('red')) {
        return const Color(0xFFFF5A5F);
      }
      final raw = alarm['alarmLevelColor'];
      if (raw != null) {
        final s = raw.toString().trim();
        if (s.isNotEmpty) {
          return Color(int.parse(s.replaceAll('#', '0xFF')));
        }
      }
      if (l.contains('moderate') || l.contains('yellow')) {
        return const Color(0xFFFFB000);
      }
      if (l.contains('good') || l.contains('green')) {
        return AppTheme.accentGreen;
      }
      if (l.contains('info') || l.contains('blue')) {
        return const Color(0xFF2D8CFF);
      }
      return const Color(0xFFFF5A5F);
    }

    final levelColor = baseLevelColor();
    final isLight = Theme.of(context).brightness == Brightness.light;
    final fill = isLight
        ? Color.lerp(levelColor, Colors.white, 0.25)!
        : Color.lerp(levelColor, Colors.black, 0.82)!;
    final titleColor = isLight ? Colors.black87 : Colors.white;
    final detailColor = isLight ? Colors.black54 : Colors.white70;

    // Timeline parsing
    final occurTime = _formatTime(
        alarm['occurrenceTime'] ?? alarm['createTime'] ?? alarm['timestamp']);
    final recoverTime =
        _formatTime(alarm['recoverTime'] ?? alarm['recoveryTime']);
    final clearTime = _formatTime(alarm['clearTime'] ?? alarm['endTime']);

    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isLight
                ? Colors.transparent
                : levelColor.withValues(alpha: 0.85),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isLight
                  ? AppTheme.accentBlue.withValues(alpha: 0.35)
                  : levelColor.withValues(alpha: 0.40),
              blurRadius: isLight ? 18 : 20,
              offset: Offset(0, isLight ? 10 : 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: isLight
                        ? Color.lerp(levelColor, Colors.black, 0.4)!
                        : levelColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w800,
                          fontSize: resolved ? 15 : 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: detailColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: detailColor,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 19),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alarm Value: $valueStr',
                    style: TextStyle(
                      color: detailColor,
                      fontSize: resolved ? 12 : 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Alarm Type: $typeStr',
                    style: TextStyle(
                      color: detailColor,
                      fontSize: resolved ? 12 : 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Alarm Level: $levelStr',
                    style: TextStyle(
                      color: detailColor,
                      fontSize: resolved ? 12 : 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Status: ${getStatusText()}',
                    style: TextStyle(
                      color: detailColor,
                      fontSize: resolved ? 12 : 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (resolved && !_isExpanded) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Resolved: ${alarm['recoveryTime'] ?? alarm['recoverTime'] ?? '--'}',
                      style: TextStyle(
                        color:
                            isLight ? Colors.black87 : const Color(0xFF2D8CFF),
                        fontSize: resolved ? 12 : 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Expanded Timeline Content
            if (_isExpanded) ...[
              const SizedBox(height: 24),
              Divider(
                  color: isLight ? Colors.black12 : Colors.white24, height: 1),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(left: 19),
                child: Column(
                  children: [
                    _buildTimelineNode('Alarm Occurrence', occurTime,
                        isFirst: true),
                    _buildTimelineNode('Alarm Recovery', recoverTime),
                    _buildTimelineNode('Alarm Clear', clearTime, isLast: true),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
