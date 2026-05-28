part of 'report_screen.dart';

extension _ReportScreenHealthSecurity on _ReportScreenState {
  Widget _buildMaintenancePage(double hPadding) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hPadding, 0, hPadding, 24),
      child: Column(
        children: [
          _buildDiagnosticsSection(),
          const SizedBox(height: 24),
          _buildReportAlarmSection(),
        ],
      ),
    );
  }

  Widget _buildReportAlarmSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'HISTORICAL',
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
        if (_fetchingHistoricalEvents)
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
        else if (_reportAlarms.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No events found for this period.',
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
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reportAlarms.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _buildReportAlarmItem(_reportAlarms[index]);
            },
          ),
      ],
    );
  }
  Widget _buildReportAlarmItem(dynamic alarm) {
        final bool resolved = alarm['recoveryTime'] != null;
    final String title =
        (alarm['alarmTypeName'] ?? alarm['content'] ?? 'Alert')
            .toString();

    String alarmValue() {
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
      final content = (alarm['content'] ??
              alarm['alarmMsg'] ??
              alarm['message'] ??
              '')
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
    final String typeStr = (alarm['alarmTypeType'] ??
                alarm['alarmTypeName'] ??
                alarm['alarmType'] ??
                alarm['type'] ??
                title)
            .toString()
            .trim()
            .isEmpty
        ? title
        : (alarm['alarmTypeType'] ??
                alarm['alarmTypeName'] ??
                alarm['alarmType'] ??
                alarm['type'] ??
                title)
            .toString()
            .trim();
    final String levelStr = alarmLevelName();

    Color baseLevelColor() {
      if (resolved) return const Color(0xFF2D8CFF);
      final l = levelStr.toLowerCase();
      if (l.contains('critical') ||
          l.contains('orange') ||
          l.contains('red')) {
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
        ? Colors.white
        : Color.lerp(levelColor, Colors.black, 0.82)!;
    final titleColor =
        isLight ? AppTheme.lightTextPrimary : Colors.white;
    final detailColor = isLight
        ? AppTheme.lightTextSecondary.withValues(alpha: 0.92)
        : Colors.white70;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: levelColor.withValues(alpha: isLight ? 0.65 : 0.85),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color:
                levelColor.withValues(alpha: isLight ? 0.30 : 0.40),
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
                  color: levelColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w800,
                    fontSize: resolved ? 15 : 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
                if (resolved) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Resolved: ${alarm['recoveryTime']}',
                    style: TextStyle(
                      color: const Color(0xFF2D8CFF),
                      fontSize: resolved ? 12 : 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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
    final days = _lastMaintenance == null
        ? 'N/A'
        : DateTime.now().difference(_lastMaintenance!).inDays.toString();
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
                const SizedBox(height: 2),
                Text(
                  _lastMaintenance == null ? '' : '( $days Days Ago )',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
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
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.accentBlue,
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maintenance date updated successfully'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update maintenance date')),
          );
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
    final int offline = total - online;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return DashboardGlass(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      tint: isLight
          ? Colors.white
          : const Color(0xFF0E141B).withValues(alpha: 0.92),
      borderColor: isLight ? AppTheme.lightStroke : const Color(0x22FFFFFF),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Devices Online',
                  style: TextStyle(
                    color: AppTheme.accentGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$online/${total == 0 ? '--' : total}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.accentGreen,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 74,
            decoration: BoxDecoration(
              color: const Color(0xFF2D7DFF),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Device Offline',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$offline',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: offline > 0
                          ? Colors.red
                          : (isLight
                              ? AppTheme.lightTextPrimary
                              : AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
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
    final String user = log['opUser']?.toString() ?? 'System';

    DateTime? dt = DateTime.tryParse(timeStr);
    String timeLabel = '--:--';
    String dateLabel = '--/--';
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
            : const Color(0xFF2A2E33).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: 0.10)
              : (isOpened
                  ? AppTheme.accentGreen.withValues(alpha: 0.2)
                  : const Color(0x1AFFFFFF)),
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
