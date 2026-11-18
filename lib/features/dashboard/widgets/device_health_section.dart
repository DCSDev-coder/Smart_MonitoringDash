import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/utils/alarm_payload.dart';
import '../../../core/theme/app_theme.dart';
import 'device_history_sheet.dart';

class DeviceHealthSection extends StatelessWidget {
  final List<dynamic> devices;
  final List<dynamic>? alarms;
  final List<Map<String, dynamic>> temperatures;
  final List<Map<String, dynamic>> humidities;
  final int smokeStatus;
  final int floodStatus;
  final bool minimalist;
  final bool twoColumn;
  final bool modernMobile;

  const DeviceHealthSection({
    super.key,
    required this.devices,
    this.alarms,
    this.temperatures = const [],
    this.humidities = const [],
    this.smokeStatus = -1,
    this.floodStatus = -1,
    this.minimalist = false,
    this.twoColumn = false,
    this.modernMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    bool msgHasAll(String msg, List<String> needles) {
      for (final n in needles) {
        if (!msg.contains(n)) return false;
      }
      return true;
    }

    _BoxState? stateFromAlarms(String type, String displayName) {
      if (alarms == null || alarms!.isEmpty) return null;
      final dn = displayName.toLowerCase();
      for (final a in alarms!) {
        final msg = alarmSearchText(a);

        // If the message indicates connectivity loss, prefer OFFLINE over ALERT.
        final isOfflineMsg = msg.contains('offline') ||
            msg.contains('off-line') ||
            msg.contains('disconnect') ||
            msg.contains('disconnected') ||
            msg.contains('down') ||
            msg.contains('not online') ||
            msg.contains('unreachable');

        if (type == 'T&H') {
          // Map "Cabinet X Front/Back" to alarm messages.
          final m = RegExp(r'cabinet\\s*(\\d+)').firstMatch(dn);
          final cab = m?.group(1);
          if (cab == null) continue;
          final isFront = dn.contains('front');
          final hasCab = msg.contains('cabinet') && msg.contains(cab);
          if (!hasCab) continue;
          if (isFront && (msg.contains('front') || msg.contains('door 1'))) {
            return isOfflineMsg ? _BoxState.offline : _BoxState.alarm;
          }
          if (!isFront &&
              (msg.contains('back') ||
                  msg.contains('rear') ||
                  msg.contains('door 2'))) {
            return isOfflineMsg ? _BoxState.offline : _BoxState.alarm;
          }
          continue;
        }

        // Generic matching for other types.
        if (type == 'PDU') {
          if (msgHasAll(msg, ['pdu', dn.replaceAll('pdu ', '')])) {
            return isOfflineMsg ? _BoxState.offline : _BoxState.alarm;
          }
          if (msg.contains(dn)) {
            return isOfflineMsg ? _BoxState.offline : _BoxState.alarm;
          }
        } else if (type == 'UPS') {
          if (msg.contains('ups')) {
            return isOfflineMsg ? _BoxState.offline : _BoxState.alarm;
          }
        } else if (type == 'SMOKE') {
          if (msg.contains('smoke') || msg.contains('fire')) {
            return _BoxState.alarm;
          }
        } else if (type == 'WLD') {
          if (msg.contains('wld') ||
              msg.contains('leak') ||
              msg.contains('water')) {
            return _BoxState.alarm;
          }
        } else if (type == 'POWER') {
          // Avoid false positives like "powerEnv". Require word-boundary match.
          final hasPowerWord = RegExp(r'\\bpower\\b').hasMatch(msg);
          final hasVoltWord = RegExp(r'\\bvolt(age)?\\b').hasMatch(msg);
          final hasAmpWord = RegExp(r'\\bamp(s|ere)?\\b').hasMatch(msg);
          final hasLoadWord = RegExp(r'\\bload\\b').hasMatch(msg);
          if (hasPowerWord || hasVoltWord || hasAmpWord || hasLoadWord) {
            return isOfflineMsg ? _BoxState.offline : _BoxState.alarm;
          }
        } else if (type == 'AC') {
          // Avoid matching random words; require "ac" as a token or "aircond".
          final hasAcToken = RegExp(r'\\bac\\b').hasMatch(msg);
          if (hasAcToken ||
              msg.contains('aircond') ||
              msg.contains('air con')) {
            return isOfflineMsg ? _BoxState.offline : _BoxState.alarm;
          }
        }

        if (msg.contains(dn)) {
          return isOfflineMsg ? _BoxState.offline : _BoxState.alarm;
        }
      }
      return null;
    }

    bool isOkReading(Map<String, dynamic> m) {
      final sc = m['statusColor'];
      if (sc != null && sc.toString().isNotEmpty) return false;
      final s = m['status']?.toString().toLowerCase();
      if (s == null || s.isEmpty) return true;
      return (s == '1' || s == 'normal' || s == 'secure');
    }

    String? normalizeTHName(String raw) {
      final lower = raw.toLowerCase();
      final cabMatch = RegExp(r'cabinet\\s*(\\d+)').firstMatch(lower) ??
          RegExp(r'(\\d+)').firstMatch(lower);
      final cab = cabMatch?.group(1);
      if (cab == null) return null;

      final isFront = lower.contains('front') || lower.contains('door 1');
      final isBack = lower.contains('back') ||
          lower.contains('rear') ||
          lower.contains('door 2');
      final side = isBack ? 'Back' : (isFront ? 'Front' : 'Front');
      return 'Cabinet $cab $side';
    }

    // Build a fast lookup for Temp/Humd alert state per cabinet side using the
    // same data source as the Environment gauges.
    final thAlert = <String, bool>{};
    for (final m in [...temperatures, ...humidities]) {
      final rawName = (m['name'] ?? m['nodeName'] ?? '').toString().trim();
      if (rawName.isEmpty) continue;
      final norm = normalizeTHName(rawName);
      if (norm == null) continue;
      if (!isOkReading(m)) {
        thAlert[norm] = true;
      }
    }

    int readCount(Map<String, dynamic> m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v == null) continue;
        if (v is int) return v;
        if (v is num) return v.toInt();
        final parsed = int.tryParse('$v');
        if (parsed != null) return parsed;
      }
      return 0;
    }

    String normalizeType(String raw) {
      final up = raw.trim().toUpperCase();
      final compact = up.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (up.isEmpty) return up;

      // Temp/Humidity variants
      if (up == 'T&H' ||
          up == 'TH' ||
          up == 'TEMP' ||
          up == 'HUM' ||
          compact == 'TH' ||
          compact == 'TEMPHUM' ||
          compact == 'TEMPHUMID') {
        return 'T&H';
      }

      // Leak / water leak detector variants
      if (up == 'WLD' ||
          up == 'LEAK' ||
          up == 'LEAKDETECTOR' ||
          compact == 'WLD' ||
          compact == 'LEAK' ||
          compact == 'WATERLEAK' ||
          compact == 'WATERLEAKDETECTOR') {
        return 'WLD';
      }

      // Smoke / fire detector variants
      if (up == 'SMOKE' ||
          up == 'FIRE' ||
          up == 'SMOKEDETECTOR' ||
          compact == 'SMOKE' ||
          compact == 'FIRE' ||
          compact == 'SMOKEDETECTOR') {
        return 'SMOKE';
      }

      // UPS variants
      if (up == 'UPS' || compact == 'UPS') {
        return 'UPS';
      }

      // PDU variants
      if (up == 'PDU' || compact == 'PDU') {
        return 'PDU';
      }

      // Power variants: POWER ENV / POWERENV / POWER
      if (up == 'POWER' ||
          compact == 'POWER' ||
          compact == 'POWERENV' ||
          up.contains('POWER')) {
        return 'POWER';
      }

      // Aircon variants
      if (up == 'AC' ||
          compact == 'AC' ||
          up.contains('AIR') ||
          up.contains('AIRCON') ||
          up.contains('AIR CON') ||
          up.contains('COOL')) {
        return 'AC';
      }

      return up;
    }

    // Group devices by a normalized type name
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final d in devices) {
      if (d is! Map<String, dynamic>) continue;
      final raw = (d['nodeTypeName'] ?? d['type'] ?? d['nodeType'] ?? '')
          .toString()
          .trim();
      if (raw.isEmpty) continue;
      final type = normalizeType(raw);
      grouped.putIfAbsent(type, () => <Map<String, dynamic>>[]).add(d);
    }

    // Group active alarms by category to reflect in the health cards
    final categoryAlarms = <String, List<dynamic>>{};
    if (alarms != null) {
      for (final a in alarms!) {
        final msg = alarmSearchText(a);

        if (msg.contains('smoke') ||
            msg.contains('fire') ||
            msg.contains('detector')) {
          categoryAlarms.putIfAbsent('SMOKE', () => []).add(a);
        }
        if (msg.contains('flood') ||
            msg.contains('leak') ||
            msg.contains('wld') ||
            msg.contains('water') ||
            msg.contains('moisture')) {
          categoryAlarms.putIfAbsent('WLD', () => []).add(a);
        }
        if (msg.contains('temp') ||
            msg.contains('humid') ||
            msg.contains('t&h') ||
            msg.contains('cabinet') ||
            msg.contains('rack') ||
            msg.contains('door')) {
          categoryAlarms.putIfAbsent('T&H', () => []).add(a);
        }
        if (msg.contains('ups') ||
            msg.contains('battery') ||
            msg.contains('bypass')) {
          categoryAlarms.putIfAbsent('UPS', () => []).add(a);
        }
        if (msg.contains('pdu')) {
          categoryAlarms.putIfAbsent('PDU', () => []).add(a);
        } else if (msg.contains('power') ||
            msg.contains('volt') ||
            msg.contains('amp') ||
            msg.contains('curr') ||
            msg.contains('load')) {
          categoryAlarms.putIfAbsent('POWER', () => []).add(a);
        }
        if (msg.contains('ac ') ||
            msg.contains('air con') ||
            msg.contains('cooling') ||
            msg.contains('compressor') ||
            msg.contains('fan')) {
          categoryAlarms.putIfAbsent('AC', () => []).add(a);
        }
      }
    }

    _DeviceHealthItem? mapItem(
      String type, {
      required String label,
      required String iconAsset,
      int? siteStatus,
      String? siteLabel,
    }) {
      final items = grouped[type] ?? [];
      final activeAlarms = categoryAlarms[type] ?? [];

      // If there are no rack items AND no site status AND no alarms, skip this category
      if (items.isEmpty &&
          (siteStatus == null || siteStatus == -1) &&
          activeAlarms.isEmpty) {
        return null;
      }

      int total = 0;
      int normal = 0;
      int offline = 0;
      int alarm = 0;
      final List<Map<String, dynamic>> deviceList = [];
      List<_BoxState> boxStates = [];

      // 1. Add Site-level sensor if provided and no specific devices exist
      if (items.isEmpty && siteStatus != null && siteStatus != -1) {
        total++;
        if (siteStatus == 0) {
          normal++;
          boxStates.add(_BoxState.normal);
        } else {
          alarm++;
          boxStates.add(_BoxState.alarm);
        }
        deviceList.add({
          'nodeName': siteLabel ?? 'Facility Environment Sensor',
          'status': siteStatus == 0 ? '1' : '0',
          'isSiteLevel': true,
        });
      }

      // 2. Add Rack-level sensors
      for (final item in items) {
        final tc = readCount(item, const ['totalCount', 'total', 'count']);
        final nc = readCount(
            item, const ['normalCount', 'normal', 'okCount', 'secureCount']);
        // Vendor dashboards typically expose alarm/offline separately. Use best-effort keys.
        var ac = readCount(item, const [
          'alarmCount',
          'alarm',
          'alertCount',
          'criticalCount',
          'warnCount',
          'abnormalCount'
        ]);
        var oc = readCount(item, const [
          'offlineCount',
          'offline',
          'offCount',
          'downCount',
          'disconnectCount'
        ]);

        // If the backend doesn't expose split counts, treat non-normal as offline by default.
        if (ac == 0 && oc == 0 && tc > 0) {
          oc = (tc - nc).clamp(0, tc);
        } else {
          // Ensure counts don't exceed total.
          ac = ac.clamp(0, tc);
          oc = oc.clamp(0, (tc - ac).clamp(0, tc));
        }

        if (tc > 0) {
          total += tc;
          normal += nc.clamp(0, tc);
          alarm += ac;
          offline += oc;

          // Build per-device indicator boxes: alarm -> offline -> normal.
          for (var i = 0; i < ac; i++) {
            boxStates.add(_BoxState.alarm);
          }
          for (var i = 0; i < oc; i++) {
            boxStates.add(_BoxState.offline);
          }
          final remaining = (tc - ac - oc).clamp(0, tc);
          for (var i = 0; i < remaining; i++) {
            boxStates.add(_BoxState.normal);
          }

          // Keep an expanded list for the detail dialog (not a strict per-device mapping).
          deviceList.add({
            'nodeName': item['nodeName'] ?? item['name'] ?? type,
            'totalCount': tc,
            'normalCount': nc,
            'alarmCount': ac,
            'offlineCount': oc,
            'status': (ac > 0 || oc > 0) ? '0' : '1',
          });
        } else {
          total++;

          // Check for specific alarms mentioning this device's name
          bool hasSpecificAlarm = false;
          final nodeName = (item['nodeName'] ?? item['name'] ?? '')
              .toString()
              .toLowerCase()
              .trim();
          if (alarms != null && nodeName.isNotEmpty) {
            for (final a in alarms!) {
              final msg = alarmSearchText(a);
              if (msg.contains(nodeName)) {
                hasSpecificAlarm = true;
                break;
              }
            }
          }

          final status = (item['status'] ?? item['nodeStatus'] ?? 0)
              .toString()
              .trim()
              .toLowerCase();
          final statusColor = item['statusColor'];

          // A device is "Good" ONLY if:
          // 1. Its status is normal/secure/1
          // 2. It has NO statusColor (which indicates an active alert/warning)
          // 3. It has NO specific alarm message in the recent alarms list
          final isNormal =
              (status == '1' || status == 'normal' || status == 'secure');
          final hasNoColor =
              statusColor == null || statusColor.toString().isEmpty;

          if (isNormal && hasNoColor && !hasSpecificAlarm) {
            normal++;
            boxStates.add(_BoxState.normal);
          } else {
            // Without explicit offline/alarm counts, treat as alarm when we have a matching
            // alarm message or an explicit statusColor.
            alarm++;
            boxStates.add(_BoxState.alarm);
          }
          deviceList.add(item);
        }
      }

      // 3. Fallback: if the backend doesn't provide alarm counts but we do have
      // active alarms for this category, mark at least one indicator as alarm.
      if (alarm == 0 &&
          offline == 0 &&
          activeAlarms.isNotEmpty &&
          boxStates.isNotEmpty) {
        boxStates[0] = _BoxState.alarm;
        alarm = 1;
      }

      if (total <= 0) return null;

      // 4. Sort and Standardize T&H device names if needed
      if (type == 'T&H') {
        deviceList.sort((a, b) {
          final aName =
              (a['nodeName'] ?? a['name'] ?? '').toString().toLowerCase();
          final bName =
              (b['nodeName'] ?? b['name'] ?? '').toString().toLowerCase();

          final aNum = int.tryParse(
                  RegExp(r'(\d+)').firstMatch(aName)?.group(1) ?? '1') ??
              1;
          final bNum = int.tryParse(
                  RegExp(r'(\d+)').firstMatch(bName)?.group(1) ?? '1') ??
              1;

          if (aNum != bNum) return aNum.compareTo(bNum);

          final aIsFront = aName.contains('front') ? 0 : 1;
          final bIsFront = bName.contains('front') ? 0 : 1;
          return aIsFront.compareTo(bIsFront);
        });
      }

      // Derive "normal" from totals so it stays consistent with alarm/offline splits.
      normal = (total - alarm - offline).clamp(0, total);

      // Build display names from actual device data
      final displayNames = <String>[];
      final nodeIds = <int?>[]; // Store actual nodeIds for interaction
      final metricCodes = <String?>[];

      for (var i = 0; i < deviceList.length; i++) {
        final d = deviceList[i];
        String name = (d['nodeName'] ?? d['name'] ?? '').toString().trim();
        if (name.isEmpty) name = '$label ${i + 1}';

        final tc = d['totalCount'] as int? ?? 1;
        final nId = int.tryParse(d['id']?.toString() ??
            d['collectControlNodeId']?.toString() ??
            d['nodeId']?.toString() ??
            '');
        final mCode = d['metricCode']?.toString();

        if (tc > 1) {
          for (var j = 0; j < tc; j++) {
            displayNames.add('$name ${j + 1}');
            nodeIds.add(nId);
            metricCodes.add(mCode);
          }
        } else {
          displayNames.add(name);
          nodeIds.add(nId);
          metricCodes.add(mCode);
        }
      }

      // Fallback padding if total > deviceList bounds
      while (displayNames.length < total) {
        displayNames.add('$label ${displayNames.length + 1}');
        nodeIds.add(null);
        metricCodes.add(null);
      }
      // Rebuild boxStates in display order:
      // - default normal (orange)
      // - apply offline count as grey (unknown identity -> mark from the end)
      // - apply alarm count as red (unknown identity -> mark from the start)
      // - refine alarms based on message matching (best-effort, per-device)
      boxStates =
          List<_BoxState>.filled(total, _BoxState.normal, growable: true);

      // For Temp/Humd specifically, prefer the same live readings the gauges use.
      // This gives us per-cabinet-side accuracy (e.g. only Cabinet 1 Front turns red).
      if (type == 'T&H') {
        for (var i = 0; i < displayNames.length; i++) {
          if (thAlert[displayNames[i]] == true) {
            boxStates[i] = _BoxState.alarm;
          }
        }
      }

      for (var i = 0; i < offline && i < total; i++) {
        final idx = (total - 1 - i).clamp(0, total - 1);
        boxStates[idx] = _BoxState.offline;
      }
      var remainingAlarm = alarm.clamp(0, total);
      for (var i = 0; i < total && remainingAlarm > 0; i++) {
        if (boxStates[i] == _BoxState.normal) {
          boxStates[i] = _BoxState.alarm;
          remainingAlarm--;
        }
      }
      for (var i = 0; i < total; i++) {
        final override = stateFromAlarms(type, displayNames[i]);
        if (override != null) {
          boxStates[i] = override;
        }
      }

      return _DeviceHealthItem(
        type: type,
        label: label,
        iconAsset: iconAsset,
        total: total,
        normal: normal.clamp(0, total),
        offline: offline.clamp(0, total),
        alarm: alarm.clamp(0, total),
        devices: deviceList,
        boxStates: boxStates,
        displayNames: displayNames,
        nodeIds: nodeIds,
        metricCodes: metricCodes,
      );
    }

    const preferredOrder = <String>[
      'AC',
      'T&H',
      'POWER',
      'UPS',
      'SMOKE',
      'WLD',
      'PDU',
    ];

    const meta = <String, Map<String, String>>{
      'AC': {'label': 'AC', 'icon': 'assets/icons/thermometer.svg'},
      'T&H': {'label': 'T.H', 'icon': 'assets/icons/thermometer.svg'},
      'POWER': {'label': 'Power', 'icon': 'assets/icons/plug.svg'},
      'UPS': {'label': 'UPS', 'icon': 'assets/icons/ups.svg'},
      'SMOKE': {'label': 'Smoke', 'icon': 'assets/icons/fire-extinguisher.svg'},
      'WLD': {'label': 'Leak', 'icon': 'assets/icons/droplet.svg'},
      'PDU': {'label': 'PDU', 'icon': 'assets/icons/pdu.svg'},
    };

    final items = <_DeviceHealthItem>[];

    // First: fixed 7 cards in preferred order.
    for (final type in preferredOrder) {
      final m = meta[type]!;
      final it = mapItem(
        type,
        label: m['label']!,
        iconAsset: m['icon']!,
        // Site-level sensors: treat smokeStatus/floodStatus as an extra sensor
        // in their respective cards.
        siteStatus: type == 'SMOKE'
            ? smokeStatus
            : (type == 'WLD' ? floodStatus : null),
        siteLabel: type == 'SMOKE'
            ? 'Smoke Sensor'
            : (type == 'WLD' ? 'Leak Sensor' : null),
      );
      if (it != null) items.add(it);
    }

    // Then: any unknown categories returned by the backend (keep them visible,
    // but push them to the end so the dashboard is stable).
    final extras =
        grouped.keys.where((t) => !preferredOrder.contains(t)).toList()..sort();
    for (final type in extras) {
      final it = mapItem(
        type,
        label: type,
        iconAsset: 'assets/icons/plug.svg',
      );
      if (it != null) items.add(it);
    }

    if (items.isEmpty) {
      const fallbackDefs = [
        {'type': 'AC', 'label': 'AC', 'icon': 'assets/icons/thermometer.svg', 'bars': 1},
        {'type': 'T&H', 'label': 'T.H', 'icon': 'assets/icons/thermometer.svg', 'bars': 4},
        {'type': 'POWER', 'label': 'Power', 'icon': 'assets/icons/plug.svg', 'bars': 2},
        {'type': 'UPS', 'label': 'UPS', 'icon': 'assets/icons/ups.svg', 'bars': 1},
        {'type': 'SMOKE', 'label': 'Smoke', 'icon': 'assets/icons/fire-extinguisher.svg', 'bars': 2},
        {'type': 'WLD', 'label': 'Leak', 'icon': 'assets/icons/droplet.svg', 'bars': 1},
        {'type': 'PDU', 'label': 'PDU', 'icon': 'assets/icons/pdu.svg', 'bars': 2},
      ];
      for (final fb in fallbackDefs) {
        final count = fb['bars'] as int;
        items.add(
          _DeviceHealthItem(
            type: fb['type'] as String,
            label: fb['label'] as String,
            iconAsset: fb['icon'] as String,
            total: count,
            normal: count,
            offline: 0,
            alarm: 0,
            devices: const [],
            boxStates: List.filled(count, _BoxState.normal),
            displayNames: List.filled(count, fb['label'] as String),
            nodeIds: List.filled(count, null),
            metricCodes: List.filled(count, null),
          ),
        );
      }
    }

    final isLight = Theme.of(context).brightness == Brightness.light;

    if (modernMobile) {
      return _ModernMobileDeviceHealthCard(
        items: items,
        alarms: alarms,
        temperatures: temperatures,
        humidities: humidities,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double parentHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.of(context).size.height;
        final double screenWidth = MediaQuery.of(context).size.width;

        final double circleSize;
        final double iconSize;
        final double fontSize;
        final double verticalPadding;
        final double boxWidth;
        final double boxHeight;

        if (parentHeight >= 360 && screenWidth >= 1400) {
          circleSize = 46.0;
          iconSize = 23.0;
          fontSize = 16.0;
          verticalPadding = 16.0;
          boxWidth = 11.0;
          boxHeight = 40.0;
        } else if (parentHeight >= 290 && screenWidth >= 1100) {
          circleSize = 40.0;
          iconSize = 20.0;
          fontSize = 14.0;
          verticalPadding = 12.0;
          boxWidth = 9.0;
          boxHeight = 34.0;
        } else {
          circleSize = minimalist ? 30.0 : 36.0;
          iconSize = minimalist ? 16.0 : 18.0;
          fontSize = minimalist ? 12.0 : 13.0;
          verticalPadding = minimalist ? 6.0 : 10.0;
          boxWidth = minimalist ? 6.0 : 14.0;
          boxHeight = minimalist ? 26.0 : 34.0;
        }

        Widget buildGroup(List<_DeviceHealthItem> groupItems,
            {bool stretch = false}) {
          if (groupItems.isEmpty) return const SizedBox.shrink();
          return Container(
            height: stretch ? double.infinity : null,
            margin: EdgeInsets.only(bottom: minimalist ? 10 : 16),
            decoration: BoxDecoration(
              color: minimalist
                  ? Colors.transparent
                  : (isLight
                      ? Colors.white
                      : Theme.of(context).cardTheme.color),
              borderRadius: BorderRadius.circular(24),
              boxShadow: (isLight && !minimalist)
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            clipBehavior: minimalist ? Clip.none : Clip.antiAlias,
            child: Column(
              mainAxisAlignment: stretch
                  ? MainAxisAlignment.spaceEvenly
                  : MainAxisAlignment.start,
              children: groupItems.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final isLast = i == groupItems.length - 1;
                return Column(
                  children: [
                    _DeviceHealthRow(
                      item: item,
                      alarms: alarms,
                      minimalist: minimalist,
                      circleSize: circleSize,
                      iconSize: iconSize,
                      fontSize: fontSize,
                      verticalPadding: verticalPadding,
                      boxWidth: boxWidth,
                      boxHeight: boxHeight,
                    ),
                    if (!isLast)
                      Padding(
                        padding: EdgeInsets.only(
                            left: minimalist ? 52 : 72,
                            right: minimalist ? 0 : 16),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: isLight
                              ? Colors.black.withValues(alpha: 0.05)
                              : Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          );
        }

        if (twoColumn && items.length > 1) {
          final mid = (items.length / 2).ceil();
          final leftItems = items.sublist(0, mid);
          final rightItems = items.sublist(mid);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: buildGroup(leftItems, stretch: false),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: buildGroup(rightItems, stretch: false),
              ),
            ],
          );
        }

        return Column(
          children: [
            buildGroup(items),
          ],
        );
      },
    );
  }
}

class _DeviceHealthItem {
  final String type;
  final String label;
  final String iconAsset;
  final int total;
  final int normal;
  final int offline;
  final int alarm;
  final List<Map<String, dynamic>> devices;
  final List<_BoxState> boxStates;
  final List<String> displayNames;
  final List<int?> nodeIds;
  final List<String?> metricCodes;

  _DeviceHealthItem({
    required this.type,
    required this.label,
    required this.iconAsset,
    required this.total,
    required this.normal,
    required this.offline,
    required this.alarm,
    required this.devices,
    required this.boxStates,
    required this.displayNames,
    required this.nodeIds,
    required this.metricCodes,
  });

  Color get iconBgColor {
    switch (type) {
      case 'AC':
        return const Color(0xFF00C7BE); // Cyan
      case 'T&H':
        return const Color(0xFFFF9500); // Orange
      case 'POWER':
        return const Color(0xFF5856D6); // Purple
      case 'UPS':
        return const Color(0xFF4CD964); // Green
      case 'SMOKE':
        return const Color(0xFFFF3B30); // Red
      case 'WLD':
        return const Color(0xFF34A853); // Teal
      case 'PDU':
        return const Color(0xFF007AFF); // Blue
      default:
        return const Color(0xFF8E8E93); // Grey
    }
  }

  bool get isOk => total > 0 && (alarm + offline) == 0 && normal >= total;
}

class _DeviceHealthRow extends StatelessWidget {
  final _DeviceHealthItem item;
  final List<dynamic>? alarms;
  final bool minimalist;
  final double? circleSize;
  final double? iconSize;
  final double? fontSize;
  final double? verticalPadding;
  final double? boxWidth;
  final double? boxHeight;

  const _DeviceHealthRow({
    required this.item,
    this.alarms,
    this.minimalist = false,
    this.circleSize,
    this.iconSize,
    this.fontSize,
    this.verticalPadding,
    this.boxWidth,
    this.boxHeight,
  });

  void _showDetails(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isLight = theme.brightness == Brightness.light;

    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      barrierDismissible: true,
      barrierLabel: 'Hardware Info',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: isLight ? Colors.white : const Color(0xFF141820),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isLight
                        ? const Color(0xFFE5E7EB)
                        : Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.40),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: item.iconBgColor.withValues(
                                alpha: isLight ? 0.12 : 0.16,
                              ),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Center(
                              child: SvgPicture.asset(
                                item.iconAsset,
                                width: 18,
                                height: 18,
                                colorFilter: ColorFilter.mode(
                                  isLight
                                      ? item.iconBgColor
                                      : (Color.lerp(item.iconBgColor,
                                              Colors.white, 0.35) ??
                                          Colors.white),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    color: isLight
                                        ? AppTheme.lightTextPrimary
                                        : Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.total} ${item.total == 1 ? 'Sensor' : 'Sensors'}',
                                  style: TextStyle(
                                    color: (isLight
                                            ? AppTheme.lightTextSecondary
                                            : Colors.white)
                                        .withValues(alpha: 0.55),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isLight
                                  ? const Color(0xFFF1F5F9)
                                  : Colors.white.withValues(alpha: 0.06),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.close_rounded,
                                  color: onSurface, size: 18),
                              onPressed: () => Navigator.pop(ctx),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 34, minHeight: 34),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              // Legacy per-device rendering based on raw payload kept for reference.
                              // The new behavior renders from displayNames + boxStates (derived from
                              // /byTypeForStatus and alarm message matching).
                              /*
                        ...item.devices.map((d) {
                          final idx = item.devices.indexOf(d);
                          final isAlarm = d['isAlarm'] == true;
                          
                          // Extract value for T&H categories
                          String? displayValue;
                          String? valueLabel;
                          if (item.type == 'T&H' && !isAlarm) {
                            final val = d['axisY'] ?? d['value'] ?? d['temp'] ?? d['humd'];
                            final isHumid = d['nodeName']?.toString().toLowerCase().contains('hum') == true ||
                                            d['name']?.toString().toLowerCase().contains('hum') == true;
                            final unit = d['unit'] ?? (isHumid ? '%' : '°C');
                            if (val != null) {
                              displayValue = '$val$unit';
                              valueLabel = isHumid ? 'Humidity' : 'Temperature';
                            }
                          }
 
                          String bestName() {
                            final raw = (d['nodeName'] ?? d['name'] ?? '').toString().trim();
                            
                            // Standardize T&H names to "Cabinet X Front/Back"
                            if (item.type == 'T&H') {
                              final lower = raw.toLowerCase();
                              final match = RegExp(r'(\d+)').firstMatch(lower);
                              final cabNum = match?.group(1) ?? '1';
                              final isBack = lower.contains('back');
                              return 'Cabinet $cabNum ${isBack ? 'Back' : 'Front'}';
                            }

                            // Use "Device X" numbering for Smoke and Leak as requested
                            if (item.type == 'SMOKE' || item.type == 'WLD') {
                              return 'Device ${idx + 1}';
                            }
                            
                            if (raw.isNotEmpty) return raw;
 
                            final typeName = (d['nodeTypeName'] ?? d['nodeType'] ?? '').toString().trim();
                            if (typeName.isNotEmpty) return typeName;
 
                            return 'Sensor ${idx + 1}';
                          }
 
                          final name = bestName();
 
                          // Check for specific alarms mentioning this device's name for individual status display
                          bool hasSpecificAlarm = false;
                          final dn = (d['nodeName'] ?? d['name'] ?? '').toString().toLowerCase().trim();
                          if (alarms != null && dn.isNotEmpty) {
                            for (final a in alarms!) {
                              final msg = alarmSearchText(a);
                              if (msg.contains(dn)) {
                                hasSpecificAlarm = true;
                                break;
                              }
                            }
                          }
 
                          final statusRaw = (d['status'] ?? d['nodeStatus'] ?? 0).toString().trim().toLowerCase();
                          final statusColor = d['statusColor'];
                          
                          final isOk = (statusRaw == '1' || statusRaw == 'normal' || statusRaw == 'secure') 
                                      && (statusColor == null || statusColor.toString().isEmpty)
                                      && !hasSpecificAlarm;
 
                          return _DeviceDetailRow(
                            name: name, 
                            isOk: isOk,
                            value: displayValue,
                            valueLabel: valueLabel,
                          );
                        }),
                        */
                              for (var i = 0; i < item.displayNames.length; i++)
                                _DeviceDetailRow(
                                  name: item.displayNames[i],
                                  state: i < item.boxStates.length
                                      ? item.boxStates[i]
                                      : _BoxState.normal,
                                  nodeId: i < item.nodeIds.length
                                      ? item.nodeIds[i]
                                      : null,
                                  metricCode: i < item.metricCodes.length
                                      ? item.metricCodes[i]
                                      : null,
                                  deviceType: item.type,
                                  iconAsset: item.iconAsset,
                                  iconBgColor: item.iconBgColor,
                                  alarms: alarms,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: 12 * anim1.value, sigmaY: 12 * anim1.value),
          child: Transform.scale(
            scale: 0.8 + (0.2 * curve.value),
            child: FadeTransition(
              opacity: anim1,
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isOk = item.isOk;
    final subtleAlertOnly = item.type == 'AC';
    final statusColor =
        isOk ? const Color(0xFFFF8A00) : const Color(0xFFFF3B30);
    final alertTint = (subtleAlertOnly || isOk)
        ? null
        : (isLight
            ? const Color(0xFFFF3B30).withValues(alpha: 0.10)
            : const Color(0xFFFF3B30).withValues(alpha: 0.08));

    final iconBgColor = item.iconBgColor;

    final double cSize = circleSize ?? (minimalist ? 30.0 : 36.0);
    final double iSize = iconSize ?? (minimalist ? 16.0 : 18.0);
    final double fSize = fontSize ?? (minimalist ? 12.0 : 13.0);
    final double vPadding = verticalPadding ?? (minimalist ? 10.0 : 14.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: alertTint ?? Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              padding: EdgeInsets.symmetric(
                  horizontal: minimalist ? 12 : 14, vertical: vPadding),
              child: Row(
                children: [
                  Container(
                    width: cSize,
                    height: cSize,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        item.iconAsset,
                        width: iSize,
                        height: iSize,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: minimalist ? 10 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            color: isLight
                                ? AppTheme.lightTextPrimary
                                : Colors.white,
                            fontSize: fSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (!minimalist) ...[
                          const SizedBox(height: 2),
                          Text(
                            isOk ? 'Secure' : 'Requires attention',
                            style: TextStyle(
                              color: isOk
                                  ? (isLight
                                      ? AppTheme.lightTextSecondary
                                      : Colors.white70)
                                  : statusColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: minimalist ? 6 : 10),
                  _HealthBoxesFromStates(
                    states: item.boxStates,
                    minimalist: minimalist,
                    boxWidth: boxWidth,
                    boxHeight: boxHeight,
                  ),
                ],
              ),
            ),
            if (!isOk && !subtleAlertOnly)
              const Positioned.fill(
                child: IgnorePointer(
                  child: _BreathingOutlineGlow(
                    color: Color(0xFFFF3B30),
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BreathingOutlineGlow extends StatefulWidget {
  final Color color;
  final BorderRadius borderRadius;

  const _BreathingOutlineGlow({
    required this.color,
    required this.borderRadius,
  });

  @override
  State<_BreathingOutlineGlow> createState() => _BreathingOutlineGlowState();
}

class _BreathingOutlineGlowState extends State<_BreathingOutlineGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        final t = curved.value; // 0..1
        final k = lerpDouble(0.70, 1.0, t)!;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            border: Border.all(
              color: widget.color.withValues(alpha: 0.55 + 0.25 * t),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.10 * k),
                blurRadius: 8 + 4 * t,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: widget.color.withValues(alpha: 0.05 * k),
                blurRadius: 16 + 8 * t,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DeviceDetailRow extends StatelessWidget {
  final String name;
  final _BoxState state;
  final int? nodeId;
  final String? metricCode;
  final String deviceType;
  final String? iconAsset;
  final Color? iconBgColor;
  final List<dynamic>? alarms;

  const _DeviceDetailRow({
    required this.name,
    required this.state,
    this.nodeId,
    this.metricCode,
    this.deviceType = '',
    this.iconAsset,
    this.iconBgColor,
    this.alarms,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    late final Color color;
    late final String label;
    late final IconData icon;
    switch (state) {
      case _BoxState.normal:
        color = const Color(0xFF22C55E);
        label = 'Normal';
        icon = Icons.check_circle_outline_rounded;
        break;
      case _BoxState.alarm:
        color = const Color(0xFFEF4444);
        label = 'Alert';
        icon = Icons.error_outline_rounded;
        break;
      case _BoxState.offline:
        color = const Color(0xFF94A3B8);
        label = 'Offline';
        icon = Icons.wifi_off_rounded;
        break;
    }

    Widget child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF1A1F29),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLight
              ? const Color(0xFFE5E7EB)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: isLight ? AppTheme.lightTextPrimary : Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isLight
                  ? color
                  : Color.lerp(color, Colors.white, 0.25),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (nodeId != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: isLight ? Colors.black38 : Colors.white38, size: 18),
          ],
        ],
      ),
    );

    if (nodeId != null) {
      child = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => DeviceHistorySheet(
                nodeId: nodeId!,
                deviceName: name,
                deviceType: deviceType,
                metricCode: metricCode,
                iconAsset: iconAsset,
                iconBgColor: iconBgColor,
                alarms: alarms,
              ),
            );
          },
          child: child,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: child,
    );
  }
}

enum _BoxState { normal, alarm, offline }

class _HealthBoxesFromStates extends StatelessWidget {
  final List<_BoxState> states;
  final bool minimalist;
  final double? boxWidth;
  final double? boxHeight;

  const _HealthBoxesFromStates({
    required this.states,
    this.minimalist = false,
    this.boxWidth,
    this.boxHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (states.isEmpty) return const SizedBox.shrink();

    final double screenWidth = MediaQuery.of(context).size.width;
    final double w;
    final double h;

    if (boxWidth != null && boxHeight != null) {
      w = boxWidth!;
      h = boxHeight!;
    } else if (screenWidth >= 1400) {
      w = 12.0;
      h = 42.0;
    } else if (screenWidth >= 1100) {
      w = 9.0;
      h = 36.0;
    } else {
      w = minimalist ? 6.0 : 14.0;
      h = minimalist ? 26.0 : 34.0;
    }

    // Keep the row compact; show a "+N" for large totals.
    final visible = states.length.clamp(1, 6);
    final extra = states.length - visible;

    return Row(
      children: [
        for (var i = 0; i < visible; i++)
          _SingleHealthBox(
            state: states[i],
            minimalist: minimalist,
            width: w,
            height: h,
          ),
        if (extra > 0)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              '+$extra',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.light
                    ? AppTheme.lightTextSecondary.withValues(alpha: 0.75)
                    : Colors.white.withValues(alpha: 0.75),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _SingleHealthBox extends StatelessWidget {
  final _BoxState state;
  final bool minimalist;
  final double? width;
  final double? height;

  const _SingleHealthBox({
    required this.state,
    this.minimalist = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final baseColor = switch (state) {
      _BoxState.normal => const Color(0xFFFF8A00), // Orange
      _BoxState.alarm => const Color(0xFFFF3B30), // Red
      _BoxState.offline =>
        isLight ? const Color(0xFFBFC5D2) : const Color(0xFF6B7280), // Grey
    };

    final double screenWidth = MediaQuery.of(context).size.width;
    final double w = width ??
        (screenWidth >= 1400
            ? 12.0
            : (screenWidth >= 1100 ? 9.0 : (minimalist ? 6.0 : 14.0)));
    final double h = height ??
        (screenWidth >= 1400
            ? 42.0
            : (screenWidth >= 1100 ? 36.0 : (minimalist ? 26.0 : 34.0)));

    return Container(
      width: w,
      height: h,
      margin: EdgeInsets.only(left: minimalist ? 4 : 6),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.20),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
    );
  }
}

class _ModernMobileDeviceHealthCard extends StatelessWidget {
  final List<_DeviceHealthItem> items;
  final List<dynamic>? alarms;
  final List<Map<String, dynamic>> temperatures;
  final List<Map<String, dynamic>> humidities;

  const _ModernMobileDeviceHealthCard({
    required this.items,
    required this.alarms,
    this.temperatures = const [],
    this.humidities = const [],
  });

  String? _tileSummary(_DeviceHealthItem item) {
    if (item.alarm > 0) {
      return '${item.alarm} alarm';
    }
    if (item.offline > 0) {
      return '${item.offline} offline';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textPrimary = isLight ? const Color(0xFF0F172A) : Colors.white;
    final textSecondary = isLight
        ? const Color(0xFF64748B)
        : Colors.white.withValues(alpha: 0.65);

    final totalAlarms = items.fold<int>(0, (s, e) => s + e.alarm);
    final totalOffline = items.fold<int>(0, (s, e) => s + e.offline);
    final secureCount =
        items.where((e) => e.alarm == 0 && e.offline == 0).length;

    final Color summaryColor = totalAlarms > 0
        ? const Color(0xFFEF4444)
        : (totalOffline > 0
            ? const Color(0xFFF59E0B)
            : const Color(0xFF00A878));
    final String summaryText = totalAlarms > 0
        ? '$totalAlarms Alert'
        : (totalOffline > 0
            ? '$secureCount/${items.length} Secure'
            : '$secureCount/${items.length} Secure');

    // Pair items into rows of 2 so the card sizes naturally inside SingleChildScrollView.
    final List<List<_DeviceHealthItem>> rows = [];
    for (int i = 0; i < items.length; i += 2) {
      rows.add(items.sublist(i, (i + 2).clamp(0, items.length)));
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isLight ? Colors.white : const Color(0xFF141820),
        border: Border.all(
          color: isLight
              ? const Color(0xFFE2E8F0)
              : Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.04 : 0.24),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subsystems',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Tap tile for live node readings',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                summaryText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isLight
                      ? summaryColor
                      : (Color.lerp(summaryColor, Colors.white, 0.2) ??
                          summaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...rows.asMap().entries.map((rowEntry) {
            final rowIdx = rowEntry.key;
            final pair = rowEntry.value;
            return Padding(
              padding: EdgeInsets.only(
                  bottom: rowIdx < rows.length - 1 ? 10 : 0),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _SubsystemTile(
                        item: pair[0],
                        summary: _tileSummary(pair[0]),
                        isLight: isLight,
                        onTap: () =>
                            _DeviceHealthRow(item: pair[0], alarms: alarms)
                                ._showDetails(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: pair.length > 1
                          ? _SubsystemTile(
                              item: pair[1],
                              summary: _tileSummary(pair[1]),
                              isLight: isLight,
                              onTap: () =>
                                  _DeviceHealthRow(item: pair[1], alarms: alarms)
                                      ._showDetails(context),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SubsystemTile extends StatelessWidget {
  final _DeviceHealthItem item;
  final String? summary;
  final bool isLight;
  final VoidCallback onTap;

  const _SubsystemTile({
    required this.item,
    required this.summary,
    required this.isLight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasAlarm = item.alarm > 0;
    final allOffline = item.offline >= item.total && item.total > 0;
    final String stateLabel = hasAlarm
        ? '${item.alarm} Alert'
        : (allOffline ? 'Offline' : 'Secure');
    final accent = item.iconBgColor;

    final List<_BoxState> barStates = item.boxStates.isNotEmpty
        ? item.boxStates
        : List.generate(item.total.clamp(0, 8), (i) {
            if (i < item.alarm) return _BoxState.alarm;
            if (i < item.alarm + item.offline) return _BoxState.offline;
            return _BoxState.normal;
          });

    return Material(
      color: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF1A1F29),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasAlarm
                  ? const Color(0xFFEF4444).withValues(alpha: 0.35)
                  : (isLight
                      ? const Color(0xFFE5E7EB)
                      : Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: isLight ? 0.14 : 0.18),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        item.iconAsset,
                        width: 15,
                        height: 15,
                        colorFilter: ColorFilter.mode(
                          isLight
                              ? accent
                              : (Color.lerp(accent, Colors.white, 0.35) ??
                                  Colors.white),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isLight
                                ? const Color(0xFF0F172A)
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          stateLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: hasAlarm
                                ? const Color(0xFFEF4444)
                                : (isLight
                                    ? const Color(0xFF64748B)
                                    : Colors.white.withValues(alpha: 0.6)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(barStates.length, (i) {
                      final st = barStates[i];
                      final Color barColor = switch (st) {
                        _BoxState.normal => const Color(0xFFF59E0B),
                        _BoxState.alarm => const Color(0xFFEF4444),
                        _BoxState.offline => isLight
                            ? const Color(0xFFCBD5E1)
                            : Colors.white.withValues(alpha: 0.16),
                      };
                      return Container(
                        width: 3.5,
                        height: 18,
                        margin: EdgeInsets.only(left: i == 0 ? 0 : 2.5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: barColor,
                        ),
                      );
                    }),
                  ),
                ],
              ),
              if (summary != null) ...[
                const SizedBox(height: 9),
                Text(
                  summary!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isLight
                        ? const Color(0xFF64748B)
                        : Colors.white.withValues(alpha: 0.65),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
