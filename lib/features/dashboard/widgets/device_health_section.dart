import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../shared/widgets/dashboard_glass.dart';
import 'dashboard_typography.dart';
import '../../../core/theme/app_theme.dart';

class DeviceHealthSection extends StatelessWidget {
  final List<dynamic> devices;
  final List<dynamic>? alarms;
  final List<Map<String, dynamic>> temperatures;
  final List<Map<String, dynamic>> humidities;
  final int smokeStatus;
  final int floodStatus;

  const DeviceHealthSection({
    super.key,
    required this.devices,
    this.alarms,
    this.temperatures = const [],
    this.humidities = const [],
    this.smokeStatus = -1,
    this.floodStatus = -1,
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
        final msg = (a is Map ? a['msg'] : null)?.toString().toLowerCase() ??
            a.toString().toLowerCase();

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
          if (hasAcToken || msg.contains('aircond') || msg.contains('air con')) {
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
          compact == 'TEMPHUMID') return 'T&H';

      // Leak / water leak detector variants
      if (up == 'WLD' ||
          up == 'LEAK' ||
          up == 'LEAKDETECTOR' ||
          compact == 'WLD' ||
          compact == 'LEAK' ||
          compact == 'WATERLEAK' ||
          compact == 'WATERLEAKDETECTOR') return 'WLD';

      // Smoke / fire detector variants
      if (up == 'SMOKE' ||
          up == 'FIRE' ||
          up == 'SMOKEDETECTOR' ||
          compact == 'SMOKE' ||
          compact == 'FIRE' ||
          compact == 'SMOKEDETECTOR') return 'SMOKE';

      // UPS variants
      if (up == 'UPS' || compact == 'UPS') return 'UPS';

      // PDU variants
      if (up == 'PDU' || compact == 'PDU') return 'PDU';

      // Power variants: POWER ENV / POWERENV / POWER
      if (up == 'POWER' ||
          compact == 'POWER' ||
          compact == 'POWERENV' ||
          up.contains('POWER')) return 'POWER';

      // Aircon variants
      if (up == 'AC' ||
          compact == 'AC' ||
          up.contains('AIR') ||
          up.contains('AIRCON') ||
          up.contains('AIR CON') ||
          up.contains('COOL')) return 'AC';

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
        final msg = a['msg']?.toString().toLowerCase() ?? '';
        
        if (msg.contains('smoke') || msg.contains('fire') || msg.contains('detector')) {
          categoryAlarms.putIfAbsent('SMOKE', () => []).add(a);
        }
        if (msg.contains('flood') || msg.contains('leak') || msg.contains('wld') || msg.contains('water') || msg.contains('moisture')) {
          categoryAlarms.putIfAbsent('WLD', () => []).add(a);
        }
        if (msg.contains('temp') || msg.contains('humid') || msg.contains('t&h') || msg.contains('cabinet') || msg.contains('rack') || msg.contains('door')) {
          categoryAlarms.putIfAbsent('T&H', () => []).add(a);
        }
        if (msg.contains('ups') || msg.contains('battery') || msg.contains('bypass')) {
          categoryAlarms.putIfAbsent('UPS', () => []).add(a);
        }
        if (msg.contains('pdu')) {
          categoryAlarms.putIfAbsent('PDU', () => []).add(a);
        } else if (msg.contains('power') || msg.contains('volt') || msg.contains('amp') || msg.contains('curr') || msg.contains('load')) {
          categoryAlarms.putIfAbsent('POWER', () => []).add(a);
        }
        if (msg.contains('ac ') || msg.contains('air con') || msg.contains('cooling') || msg.contains('compressor') || msg.contains('fan')) {
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
      if (items.isEmpty && (siteStatus == null || siteStatus == -1) && activeAlarms.isEmpty) return null;

      int total = 0;
      int normal = 0;
      int offline = 0;
      int alarm = 0;
      final List<Map<String, dynamic>> deviceList = [];
      List<_BoxState> boxStates = [];

      // 1. Add Site-level sensor if provided
      if (siteStatus != null && siteStatus != -1) {
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
        final nc = readCount(item, const ['normalCount', 'normal', 'okCount', 'secureCount']);
        // Vendor dashboards typically expose alarm/offline separately. Use best-effort keys.
        var ac = readCount(item, const ['alarmCount', 'alarm', 'alertCount', 'criticalCount', 'warnCount', 'abnormalCount']);
        var oc = readCount(item, const ['offlineCount', 'offline', 'offCount', 'downCount', 'disconnectCount']);

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
          final nodeName = (item['nodeName'] ?? item['name'] ?? '').toString().toLowerCase().trim();
          if (alarms != null && nodeName.isNotEmpty) {
            for (final a in alarms!) {
              final msg = a['msg']?.toString().toLowerCase() ?? '';
              if (msg.contains(nodeName)) {
                hasSpecificAlarm = true;
                break;
              }
            }
          }

          final status = (item['status'] ?? item['nodeStatus'] ?? 0).toString().trim().toLowerCase();
          final statusColor = item['statusColor'];
          
          // A device is "Good" ONLY if:
          // 1. Its status is normal/secure/1
          // 2. It has NO statusColor (which indicates an active alert/warning)
          // 3. It has NO specific alarm message in the recent alarms list
          final isNormal = (status == '1' || status == 'normal' || status == 'secure');
          final hasNoColor = statusColor == null || statusColor.toString().isEmpty;
          
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
      if (alarm == 0 && offline == 0 && activeAlarms.isNotEmpty && boxStates.isNotEmpty) {
        boxStates[0] = _BoxState.alarm;
        alarm = 1;
      }

      if (total <= 0) return null;

      // 4. Sort and Standardize T&H device names if needed
      if (type == 'T&H') {
        deviceList.sort((a, b) {
          final aName = (a['nodeName'] ?? a['name'] ?? '').toString().toLowerCase();
          final bName = (b['nodeName'] ?? b['name'] ?? '').toString().toLowerCase();
          
          final aNum = int.tryParse(RegExp(r'(\d+)').firstMatch(aName)?.group(1) ?? '1') ?? 1;
          final bNum = int.tryParse(RegExp(r'(\d+)').firstMatch(bName)?.group(1) ?? '1') ?? 1;
          
          if (aNum != bNum) return aNum.compareTo(bNum);
          
          final aIsFront = aName.contains('front') ? 0 : 1;
          final bIsFront = bName.contains('front') ? 0 : 1;
          return aIsFront.compareTo(bIsFront);
        });
      }

      // Derive "normal" from totals so it stays consistent with alarm/offline splits.
      normal = (total - alarm - offline).clamp(0, total);

      // Build stable display names and map states to the right device slots.
      final displayNames = <String>[];
      if (type == 'T&H') {
        // Preferred fixed mapping for 4 sensors.
        if (total >= 4) {
          displayNames.addAll(const [
            'Cabinet 1 Front',
            'Cabinet 1 Back',
            'Cabinet 2 Front',
            'Cabinet 2 Back',
          ]);
          // If there are more than 4, append generics.
          for (var i = 4; i < total; i++) {
            displayNames.add('Cabinet ${i + 1} Sensor');
          }
        } else {
          for (var i = 0; i < total; i++) {
            displayNames.add('Cabinet ${i + 1} Sensor');
          }
        }
      } else if (type == 'PDU') {
        for (var i = 0; i < total; i++) {
          displayNames.add('PDU ${i + 1}');
        }
      } else if (type == 'UPS') {
        for (var i = 0; i < total; i++) {
          displayNames.add(total == 1 ? 'UPS' : 'UPS ${i + 1}');
        }
      } else if (type == 'SMOKE') {
        for (var i = 0; i < total; i++) {
          displayNames.add(total == 1 ? 'Smoke' : 'Smoke ${i + 1}');
        }
      } else if (type == 'WLD') {
        for (var i = 0; i < total; i++) {
          displayNames.add(total == 1 ? 'WLD' : 'WLD ${i + 1}');
        }
      } else if (type == 'POWER') {
        for (var i = 0; i < total; i++) {
          displayNames.add(total == 1 ? 'Power' : 'Power ${i + 1}');
        }
      } else if (type == 'AC') {
        for (var i = 0; i < total; i++) {
          displayNames.add(total == 1 ? 'AC' : 'AC ${i + 1}');
        }
      } else {
        for (var i = 0; i < total; i++) {
          displayNames.add('$label ${i + 1}');
        }
      }

      // Rebuild boxStates in display order:
      // - default normal (orange)
      // - apply offline count as grey (unknown identity -> mark from the end)
      // - apply alarm count as red (unknown identity -> mark from the start)
      // - refine alarms based on message matching (best-effort, per-device)
      boxStates = List<_BoxState>.filled(total, _BoxState.normal, growable: true);

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
      'T&H': {'label': 'Temp / Humd', 'icon': 'assets/icons/thermometer.svg'},
      'POWER': {'label': 'Power', 'icon': 'assets/icons/plug.svg'},
      'UPS': {'label': 'UPS', 'icon': 'assets/icons/ups.svg'},
      'SMOKE': {
        'label': 'Smoke Detector',
        'icon': 'assets/icons/fire-extinguisher.svg'
      },
      'WLD': {'label': 'Leak Detector', 'icon': 'assets/icons/droplet.svg'},
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
    final extras = grouped.keys
        .where((t) => !preferredOrder.contains(t))
        .toList()
      ..sort();
    for (final type in extras) {
      final it = mapItem(
        type,
        label: type,
        iconAsset: 'assets/icons/plug.svg',
      );
      if (it != null) items.add(it);
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // Desktop/tablet layout: 3-column grid for easier scanning.
        final crossAxisCount = w >= 980 ? 3 : 1;
        final childAspectRatio = crossAxisCount == 3 ? 3.8 : 4.2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, i) => _DeviceHealthRow(
            item: items[i],
            alarms: alarms,
          ),
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
  });

  bool get isOk => total > 0 && (alarm + offline) == 0 && normal >= total;
}

class _DeviceHealthRow extends StatelessWidget {
  final _DeviceHealthItem item;
  final List<dynamic>? alarms;

  const _DeviceHealthRow({
    required this.item,
    this.alarms,
  });

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: DashboardGlass(
            radius: 24,
            padding: const EdgeInsets.all(24),
            tint: Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF0B0F14).withValues(alpha: 0.92),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          item.iconAsset,
                          width: 20,
                          height: 20,
                          colorFilter: ColorFilter.mode(Theme.of(context).brightness == Brightness.light ? AppTheme.lightTextPrimary : Colors.white, BlendMode.srcIn),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label.toUpperCase(),
                            style: bitcount(
                              context,
                              fontSize: 14,
                              color: const Color(0xFFFF8A00),
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            'Unified Monitoring: ${item.total} Sensors',
                            style: TextStyle(
                              color: (Theme.of(context).brightness == Brightness.light ? AppTheme.lightTextSecondary : Colors.white).withValues(alpha: 0.5),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: Theme.of(context).brightness == Brightness.light ? AppTheme.lightTextPrimary : Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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
                              final msg = a['msg']?.toString().toLowerCase() ?? '';
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
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                  Text(
                    'Combined Real-time Environment & IT Device Monitoring',
                    style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.light ? AppTheme.lightTextSecondary : Colors.white).withValues(alpha: 0.3),
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
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
      
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DashboardGlass(
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              tint: alertTint,
              borderColor: isLight ? AppTheme.lightStroke : null,
              child: Row(
                children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.06)
                        : Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(23),
                    border: Border.all(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.10)
                          : Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      item.iconAsset,
                      width: 26,
                      height: 26,
                      colorFilter: ColorFilter.mode(
                        isLight
                            ? AppTheme.lightTextPrimary.withValues(alpha: 0.85)
                            : Colors.white.withValues(alpha: 0.90),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.light ? AppTheme.lightTextPrimary : Colors.white,
                            fontSize:
                                Theme.of(context).brightness == Brightness.light
                                    ? 16
                                    : 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isOk ? 'SECURE' : 'ATTENTION',
                          style: TextStyle(
                            color: statusColor,
                            fontSize:
                                Theme.of(context).brightness == Brightness.light
                                    ? 13
                                    : 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _HealthBoxesFromStates(states: item.boxStates),
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
                color: widget.color.withValues(alpha: 0.22 * k),
                blurRadius: 14 + 10 * t,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: widget.color.withValues(alpha: 0.12 * k),
                blurRadius: 36 + 18 * t,
                spreadRadius: 10,
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

  const _DeviceDetailRow({
    required this.name,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    late final Color color;
    late final String label;
    late final IconData icon;
    switch (state) {
      case _BoxState.normal:
        color = const Color(0xFFFF8A00);
        label = 'NORMAL';
        icon = Icons.check_circle_outline_rounded;
        break;
      case _BoxState.alarm:
        color = const Color(0xFFFF3B30);
        label = 'ALERT';
        icon = Icons.error_outline_rounded;
        break;
      case _BoxState.offline:
        color = const Color(0xFF8E8E93);
        label = 'OFFLINE';
        icon = Icons.wifi_off_rounded;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              (isLight ? Colors.black : Colors.white).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                (isLight ? Colors.black : Colors.white).withValues(alpha: 0.08),
            width: 1,
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
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _BoxState { normal, alarm, offline }

class _HealthBoxesFromStates extends StatelessWidget {
  final List<_BoxState> states;
  const _HealthBoxesFromStates({required this.states});

  @override
  Widget build(BuildContext context) {
    if (states.isEmpty) return const SizedBox.shrink();

    // Keep the row compact; show a "+N" for large totals.
    final visible = states.length.clamp(1, 6);
    final extra = states.length - visible;

    return Row(
      children: [
        for (var i = 0; i < visible; i++) _SingleHealthBox(state: states[i]),
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
  const _SingleHealthBox({required this.state});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final baseColor = switch (state) {
      _BoxState.normal => const Color(0xFFFF8A00), // Orange
      _BoxState.alarm => const Color(0xFFFF3B30), // Red
      _BoxState.offline => isLight ? const Color(0xFFBFC5D2) : const Color(0xFF6B7280), // Grey
    };

    return Container(
      width: 14,
      height: 34,
      margin: const EdgeInsets.only(left: 6),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.35),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
