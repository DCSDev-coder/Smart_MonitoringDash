import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/config/site_runtime_config.dart';
import '../../../core/controllers/global_status_poller.dart';
import '../../../core/network/adapter_api_service.dart';
import '../../../core/network/api_service.dart';
import '../../../core/network/cpanel_api_service.dart';
import '../../../core/utils/app_log.dart';
import '../models/smart_rack_console_snapshot.dart';

class SmartRackConsoleRepository extends ChangeNotifier {
  SmartRackConsoleRepository._();

  static final instance = SmartRackConsoleRepository._();

  final GlobalStatusPoller _poller = GlobalStatusPoller.instance;

  bool _started = false;
  bool _fetchingSupplemental = false;
  int? _activeSiteId;
  final Map<int, int> _upsNodeIdBySite = <int, int>{};
  final Map<int, int> _acNodeIdBySite = <int, int>{};
  DateTime? _lastSupplementalFetchAt;
  double? _totalMonthEnergyKwh;
  List<ConsoleBreakdownItem> _capacityBreakdown = const [];
  List<ConsoleMetricRow> _powerInletRows = const [];
  List<ConsoleMetricRow> _powerOutletRows = const [];
  List<Map<String, dynamic>> _powerPdu1Outlets = const [];
  List<Map<String, dynamic>> _powerPdu2Outlets = const [];
  List<ConsoleMetricRow> _powerPdu1MetricRows = const [];
  List<ConsoleMetricRow> _powerPdu1StatusRows = const [];
  List<ConsoleMetricRow> _powerPdu1SettingRows = const [];
  List<ConsoleMetricRow> _powerPdu2MetricRows = const [];
  List<ConsoleMetricRow> _powerPdu2StatusRows = const [];
  List<ConsoleMetricRow> _powerPdu2SettingRows = const [];
  List<ConsoleMetricRow> _acMetricRows = const [];
  List<ConsoleMetricRow> _acSettingRows = const [];
  List<ConsoleMetricRow> _acStatusRows = const [];
  String? _acUnitStatus;
  String? _acCompressorStatus;
  List<ConsoleMetricRow> _upsParameterRows = const [];
  List<ConsoleMetricRow> _upsStatusRows = const [];

  void start() {
    if (_started) return;
    _started = true;
    _poller.addListener(_handlePollerChanged);
    _handlePollerChanged();
  }

  void stop() {
    if (!_started) return;
    _started = false;
    _poller.removeListener(_handlePollerChanged);
  }

  void _handlePollerChanged() {
    notifyListeners();
    _maybeRefreshSupplemental();
  }

  void _maybeRefreshSupplemental() {
    final site = CpanelApiService.instance.currentSite;
    final siteId = SiteRuntimeConfig.siteId(site);
    if (siteId == null || !AdapterApiService.instance.isConfigured) {
      if (_activeSiteId != null ||
          _totalMonthEnergyKwh != null ||
          _capacityBreakdown.isNotEmpty ||
          _powerInletRows.isNotEmpty ||
          _powerOutletRows.isNotEmpty ||
          _powerPdu1Outlets.isNotEmpty ||
          _powerPdu2Outlets.isNotEmpty ||
          _powerPdu1MetricRows.isNotEmpty ||
          _powerPdu1StatusRows.isNotEmpty ||
          _powerPdu1SettingRows.isNotEmpty ||
          _powerPdu2MetricRows.isNotEmpty ||
          _powerPdu2StatusRows.isNotEmpty ||
          _powerPdu2SettingRows.isNotEmpty ||
          _acMetricRows.isNotEmpty ||
          _acSettingRows.isNotEmpty ||
          _acStatusRows.isNotEmpty ||
          _acUnitStatus != null ||
          _acCompressorStatus != null ||
          _upsParameterRows.isNotEmpty ||
          _upsStatusRows.isNotEmpty) {
        _activeSiteId = siteId;
        _totalMonthEnergyKwh = null;
        _capacityBreakdown = const [];
        _powerInletRows = const [];
        _powerOutletRows = const [];
        _powerPdu1Outlets = const [];
        _powerPdu2Outlets = const [];
        _powerPdu1MetricRows = const [];
        _powerPdu1StatusRows = const [];
        _powerPdu1SettingRows = const [];
        _powerPdu2MetricRows = const [];
        _powerPdu2StatusRows = const [];
        _powerPdu2SettingRows = const [];
        _acMetricRows = const [];
        _acSettingRows = const [];
        _acStatusRows = const [];
        _acUnitStatus = null;
        _acCompressorStatus = null;
        _upsParameterRows = const [];
        _upsStatusRows = const [];
        _upsNodeIdBySite.clear();
        _acNodeIdBySite.clear();
        notifyListeners();
      }
      return;
    }

    final now = DateTime.now();
    final shouldRefresh = _activeSiteId != siteId ||
        _lastSupplementalFetchAt == null ||
        now.difference(_lastSupplementalFetchAt!) >=
            const Duration(seconds: 30);
    if (!shouldRefresh || _fetchingSupplemental) return;

    _activeSiteId = siteId;
    unawaited(_refreshSupplemental(siteId));
  }

  Future<void> _refreshSupplemental(int siteId) async {
    _fetchingSupplemental = true;
    try {
      final powerMonth = await AdapterApiService.instance.fetchPowerMonth(
        siteId: siteId,
      );
      final powerMonthResult =
          (powerMonth?['result'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
      final totalMonthEnergyKwh =
          _readDouble(powerMonthResult, const ['Total', 'total']);

      final now = DateTime.now();
      final cabinetPower = await AdapterApiService.instance.fetchCabinetPower(
        siteId: siteId,
        startTime:
            now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
        endTime: now.millisecondsSinceEpoch,
      );
      final capacityBreakdown =
          _parseCapacityBreakdown(cabinetPower?['result'] as List?);
      final rackTelemetry = await AdapterApiService.instance.fetchRackTelemetry(
        siteId: siteId,
        includeRaw: true,
      );
      final powerRows = _parsePowerRows(rackTelemetry);
      final powerOutlets = _parsePowerOutlets(rackTelemetry);
      final site = CpanelApiService.instance.currentSite;
      final upsNodeId = await _resolveUpsNodeId(siteId, site);
      Map<String, dynamic>? upsPayload;
      if (upsNodeId != null) {
        upsPayload = await AdapterApiService.instance.fetchNodeWithMetric(
          siteId: siteId,
          nodeId: upsNodeId,
        );
      }
      final upsRows = _parseUpsRows(
        rackTelemetry,
        upsPayload: upsPayload,
        upsNodeId: upsNodeId,
      );
      final acNodeId = await _resolveAcNodeId(siteId, site);
      Map<String, dynamic>? acPayload;
      if (acNodeId != null) {
        acPayload = await AdapterApiService.instance.fetchNodeWithMetric(
          siteId: siteId,
          nodeId: acNodeId,
        );
      }
      final acRows = _parseAcRows(acPayload, acNodeId: acNodeId);

      final pduNodeIds = await _resolvePduNodeIds(siteId, site);
      final pduBundles = <(
        List<ConsoleMetricRow>,
        List<ConsoleMetricRow>,
        List<ConsoleMetricRow>
      )>[];
      for (final nodeId in pduNodeIds.take(2)) {
        pduBundles.add(await _fetchPduSectionRows(siteId, nodeId));
      }
      while (pduBundles.length < 2) {
        pduBundles.add((const [], const [], const []));
      }

      _totalMonthEnergyKwh =
          totalMonthEnergyKwh > 0 ? totalMonthEnergyKwh : null;
      _capacityBreakdown = capacityBreakdown;
      _powerInletRows = powerRows.$1;
      _powerOutletRows = powerRows.$2;
      _powerPdu1Outlets = powerOutlets.$1;
      _powerPdu2Outlets = powerOutlets.$2;
      _powerPdu1MetricRows = pduBundles[0].$1;
      _powerPdu1StatusRows = pduBundles[0].$2;
      _powerPdu1SettingRows = pduBundles[0].$3;
      _powerPdu2MetricRows = pduBundles[1].$1;
      _powerPdu2StatusRows = pduBundles[1].$2;
      _powerPdu2SettingRows = pduBundles[1].$3;
      _acMetricRows = acRows.$1;
      _acSettingRows = acRows.$2;
      _acStatusRows = acRows.$3;
      _acUnitStatus = acRows.$4;
      _acCompressorStatus = acRows.$5;
      _upsParameterRows = upsRows.$1;
      _upsStatusRows = upsRows.$2;
      _lastSupplementalFetchAt = now;
      notifyListeners();
    } catch (_) {
      _lastSupplementalFetchAt = DateTime.now();
    } finally {
      _fetchingSupplemental = false;
    }
  }

  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)
      _parsePowerOutlets(Map<String, dynamic>? telemetry) {
    final pdu1 = (telemetry?['pdu1'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final pdu2 = (telemetry?['pdu2'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    List<Map<String, dynamic>> normalizeOutlets(List outlets) {
      return outlets.whereType<Map>().map((item) {
        final map = item.cast<String, dynamic>();
        final index = map['index'] is num
            ? (map['index'] as num).toInt()
            : int.tryParse(map['index']?.toString() ?? '');
        final watts = _readDouble(map, const ['watts', 'power']);
        return <String, dynamic>{
          'index': index,
          'isOn': map['isOn'] == true,
          'watts': watts,
        };
      }).where((item) => item['index'] != null).toList();
    }

    return (
      normalizeOutlets((pdu1['outlets'] as List?) ?? const []),
      normalizeOutlets((pdu2['outlets'] as List?) ?? const []),
    );
  }

  Future<List<int>> _resolvePduNodeIds(
    int siteId,
    Map<String, dynamic>? site,
  ) async {
    final seen = <int>{};
    final ordered = <int>[];

    final configured = SiteRuntimeConfig.nodeIdForType(site, type: 'pdu');
    if (configured != null && seen.add(configured)) {
      ordered.add(configured);
    }

    final candidates = await _discoverPowerEnvCandidates(siteId);
    final pduCandidates = candidates.where(_looksLikePduCandidate).toList()
      ..sort((a, b) {
        final aKey = _pduCandidateSortKey(a);
        final bKey = _pduCandidateSortKey(b);
        if (aKey != bKey) return aKey.compareTo(bKey);
        final aId = _nodeIdFromCandidate(a) ?? 0;
        final bId = _nodeIdFromCandidate(b) ?? 0;
        return aId.compareTo(bId);
      });

    for (final candidate in pduCandidates) {
      final nodeId = _nodeIdFromCandidate(candidate);
      if (nodeId == null || !seen.add(nodeId)) continue;
      ordered.add(nodeId);
      if (ordered.length >= 2) break;
    }

    return ordered;
  }

  bool _looksLikePduCandidate(Map<String, dynamic> record) {
    final name = (record['name'] ?? '').toString().toLowerCase();
    final typeName = (record['nodeTypeName'] ?? '').toString().toLowerCase();
    final typeCode = (record['nodeTypeCode'] ?? '').toString().toLowerCase();
    final typeId = int.tryParse(record['nodeTypeId']?.toString() ?? '');
    return typeId == 17 ||
        name.contains('pdu') ||
        typeName.contains('pdu') ||
        typeCode.contains('pdu');
  }

  int _pduCandidateSortKey(Map<String, dynamic> record) {
    final name = (record['name'] ?? '').toString().toLowerCase();
    final match = RegExp(r'(\d+)').firstMatch(name);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '') ?? 9999;
    }
    return 9999;
  }

  Future<(
    List<ConsoleMetricRow>,
    List<ConsoleMetricRow>,
    List<ConsoleMetricRow>
  )> _fetchPduSectionRows(
    int siteId,
    int nodeId,
  ) async {
    final adapterPayload = await AdapterApiService.instance.fetchNodeWithMetric(
      siteId: siteId,
      nodeId: nodeId,
    );
    final metricPayload = adapterPayload ??
        await ApiService.instance.fetchNodeWithMetric(nodeId);
    final statusPayload = await ApiService.instance.fetchNodeStatus(nodeId);

    final metricRows = _parsePduMetricRows(metricPayload);
    final statusRows = _parsePduStatusRows(statusPayload, view: false);
    final settingRows = _parsePduStatusRows(statusPayload, view: true);

    AppLog.d(
      'PDU parse snapshot',
      tag: 'RackConsolePDU',
      fields: {
        'siteId': siteId,
        'nodeId': nodeId,
        'metricCount': metricRows.length,
        'statusCount': statusRows.length,
        'settingCount': settingRows.length,
        'sampleMetricNames':
            metricRows.take(8).map((row) => row.label).toList(),
        'sampleStatusNames':
            statusRows.take(8).map((row) => row.label).toList(),
        'sampleSettingNames':
            settingRows.take(8).map((row) => row.label).toList(),
      },
    );

    return (metricRows, statusRows, settingRows);
  }

  List<ConsoleMetricRow> _parsePduMetricRows(
    Map<String, dynamic>? payload,
  ) {
    final records = _recordsFromPayload(payload)
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    if (records.isEmpty) return const [];

    final rows = <ConsoleMetricRow>[
      _consoleMetricFromRow(
        _findNormalizedRow(
          records,
          exactNames: const ['Offline State'],
          contains: const ['offline state'],
        ),
        fallbackLabel: 'Offline State',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          records,
          exactNames: const ['Rated Voltage'],
          contains: const ['rated voltage'],
        ),
        fallbackLabel: 'Rated Voltage',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          records,
          exactNames: const ['Rated Current'],
          contains: const ['rated current'],
        ),
        fallbackLabel: 'Rated Current',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          records,
          exactNames: const ['Rated Frequency'],
          contains: const ['rated frequency'],
        ),
        fallbackLabel: 'Rated Frequency',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          records,
          exactNames: const ['Outlets'],
          contains: const ['outlets'],
        ),
        fallbackLabel: 'Outlets',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          records,
          exactNames: const ['Voltage'],
          contains: const ['dianyazhidanxiang'],
        ),
        fallbackLabel: 'Voltage',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          records,
          exactNames: const ['Current'],
          contains: const ['dianliuzhidanxiang'],
        ),
        fallbackLabel: 'Current',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          records,
          exactNames: const ['active power(single-phase)'],
          contains: const ['active power'],
        ),
        fallbackLabel: 'Active Power',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          records,
          exactNames: const ['reactive power(single-phase)'],
          contains: const ['reactive power'],
        ),
        fallbackLabel: 'Reactive Power',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          records,
          exactNames: const ['power factor(single-phase)'],
          contains: const ['power factor'],
        ),
        fallbackLabel: 'Power Factor',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          records,
          exactNames: const ['Total Energy'],
          contains: const ['total energy'],
        ),
        fallbackLabel: 'Total Energy',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          records,
          exactNames: const ['frequency'],
          contains: const ['frequency'],
        ),
        fallbackLabel: 'frequency',
      ),
    ];

    return rows.where((row) => row.value != '--').toList();
  }

  List<ConsoleMetricRow> _parsePduStatusRows(
    Map<String, dynamic>? payload, {
    required bool view,
  }) {
    final records = _recordsFromPayload(payload)
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .where((row) => row['view'] == view)
        .toList();
    if (records.isEmpty) return const [];

    final rows = records
        .map(
          (row) => ConsoleMetricRow(
            label: row['name']?.toString().trim().isNotEmpty == true
                ? row['name'].toString().trim()
                : (row['statusType']?.toString().trim().isNotEmpty == true
                    ? row['statusType'].toString().trim()
                    : 'Status'),
            value: _displayStatusValue(row),
            isNormal: _isNormalStatus(_displayStatusValue(row)),
          ),
        )
        .where((row) => row.value != '--')
        .toList();

    return rows;
  }

  String _displayStatusValue(Map<String, dynamic> row) {
    final valueStr = row['status']?.toString().trim();
    if (valueStr != null &&
        valueStr.isNotEmpty &&
        valueStr.toLowerCase() != 'null') {
      return valueStr;
    }
    return _displayValueForRow(row) ?? '--';
  }

  Future<int?> _resolveUpsNodeId(
    int siteId,
    Map<String, dynamic>? site,
  ) async {
    final cached = _upsNodeIdBySite[siteId];
    if (cached != null) return cached;

    final configured = SiteRuntimeConfig.nodeIdForType(site, type: 'ups');
    if (configured != null) {
      final payload = await AdapterApiService.instance.fetchNodeWithMetric(
        siteId: siteId,
        nodeId: configured,
      );
      if (_looksLikeUpsPayload(payload)) {
        _upsNodeIdBySite[siteId] = configured;
        return configured;
      }
    }

    final candidates = await _discoverPowerEnvCandidates(siteId);
    candidates
        .sort((a, b) => _upsCandidateScore(b).compareTo(_upsCandidateScore(a)));
    for (final candidate in candidates) {
      final nodeId = _nodeIdFromCandidate(candidate);
      if (nodeId == null) continue;
      final payload = await AdapterApiService.instance.fetchNodeWithMetric(
        siteId: siteId,
        nodeId: nodeId,
      );
      if (!_looksLikeUpsPayload(payload)) continue;
      _upsNodeIdBySite[siteId] = nodeId;
      AppLog.d(
        'UPS node discovered',
        tag: 'RackConsoleUPS',
        fields: {
          'siteId': siteId,
          'nodeId': nodeId,
          'name': candidate['name'],
          'nodeTypeName': candidate['nodeTypeName'],
          'nodeTypeCode': candidate['nodeTypeCode'],
          'nodeTypeId': candidate['nodeTypeId'],
        },
      );
      return nodeId;
    }

    return null;
  }

  Future<int?> _resolveAcNodeId(
    int siteId,
    Map<String, dynamic>? site,
  ) async {
    final cached = _acNodeIdBySite[siteId];
    if (cached != null) return cached;

    final configured = SiteRuntimeConfig.nodeIdForType(site, type: 'air');
    if (configured != null) {
      final payload = await AdapterApiService.instance.fetchNodeWithMetric(
        siteId: siteId,
        nodeId: configured,
      );
      if (_looksLikeAcPayload(payload)) {
        _acNodeIdBySite[siteId] = configured;
        return configured;
      }
    }

    final candidates = await _discoverPowerEnvCandidates(siteId);
    candidates
        .sort((a, b) => _acCandidateScore(b).compareTo(_acCandidateScore(a)));
    for (final candidate in candidates) {
      final nodeId = _nodeIdFromCandidate(candidate);
      if (nodeId == null) continue;
      final payload = await AdapterApiService.instance.fetchNodeWithMetric(
        siteId: siteId,
        nodeId: nodeId,
      );
      if (!_looksLikeAcPayload(payload)) continue;
      _acNodeIdBySite[siteId] = nodeId;
      AppLog.d(
        'AC node discovered',
        tag: 'RackConsoleAC',
        fields: {
          'siteId': siteId,
          'nodeId': nodeId,
          'name': candidate['name'],
          'nodeTypeName': candidate['nodeTypeName'],
          'nodeTypeCode': candidate['nodeTypeCode'],
          'nodeTypeId': candidate['nodeTypeId'],
        },
      );
      return nodeId;
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> _discoverPowerEnvCandidates(
      int siteId) async {
    final candidates = <Map<String, dynamic>>[];
    final seenIds = <int>{};

    Future<void> collect(String? name) async {
      final res = await AdapterApiService.instance.fetchPowerEnvNodes(
        siteId: siteId,
        name: name,
        pageSize: 100,
      );
      final records = (res?['result']?['records'] as List?) ?? const [];
      for (final item in records) {
        if (item is! Map) continue;
        final map = item.cast<String, dynamic>();
        final nodeId = _nodeIdFromCandidate(map);
        if (nodeId == null || !seenIds.add(nodeId)) continue;
        candidates.add(map);
      }
    }

    await collect('*ups*');
    await collect('*UPS*');
    await collect(null);
    return candidates;
  }

  int? _nodeIdFromCandidate(Map<String, dynamic> candidate) {
    final id = candidate['id'] ?? candidate['nodeId'] ?? candidate['node_id'];
    if (id is num) return id.toInt();
    return int.tryParse(id?.toString() ?? '');
  }

  int _upsCandidateScore(Map<String, dynamic> record) {
    final name = (record['name'] ?? '').toString().toLowerCase();
    final typeName = (record['nodeTypeName'] ?? '').toString().toLowerCase();
    final typeCode = (record['nodeTypeCode'] ?? '').toString().toLowerCase();
    final typeId = int.tryParse(record['nodeTypeId']?.toString() ?? '');
    int score = 0;
    if (typeId == 4) score += 50;
    if (name == 'ups') score += 30;
    if (name.contains('ups')) score += 24;
    if (name.contains('battery')) score += 8;
    if (typeName == 'ups') score += 30;
    if (typeName.contains('ups')) score += 20;
    if (typeName.contains('uninterrupt')) score += 12;
    if (typeCode.contains('ups')) score += 20;
    if (typeCode.contains('battery')) score += 8;
    return score;
  }

  int _acCandidateScore(Map<String, dynamic> record) {
    final name = (record['name'] ?? '').toString().toLowerCase();
    final typeName = (record['nodeTypeName'] ?? '').toString().toLowerCase();
    final typeCode = (record['nodeTypeCode'] ?? '').toString().toLowerCase();
    final typeId = int.tryParse(record['nodeTypeId']?.toString() ?? '');
    int score = 0;
    if (typeId == 15) score += 50;
    if (name == 'ac') score += 30;
    if (name.contains('ac')) score += 20;
    if (name.contains('air')) score += 20;
    if (typeName == 'ac') score += 30;
    if (typeName.contains('ac')) score += 20;
    if (typeName.contains('air')) score += 20;
    if (typeCode == 'air') score += 30;
    if (typeCode.contains('air')) score += 20;
    return score;
  }

  bool _looksLikeUpsPayload(Map<String, dynamic>? payload) {
    final records = _recordsFromPayload(payload)
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    if (records.isEmpty) return false;

    final envOnlyCodes = <String>{
      'device_temperature',
      'device_humidity',
      'device_online',
    };
    final codes = records
        .map((record) => (record['code'] ?? record['metricTypeLibCode'] ?? '')
            .toString()
            .trim()
            .toLowerCase())
        .where((code) => code.isNotEmpty)
        .toSet();
    if (codes.isEmpty) return false;
    if (codes.every(envOnlyCodes.contains)) return false;

    final indicators = <String>[
      'ups',
      'battery',
      'voltage',
      'frequency',
      'loadratio',
      'workingmode',
      'mainspower',
      'promptsound',
    ];
    return codes.any((code) => indicators.any(code.contains));
  }

  bool _looksLikeAcPayload(Map<String, dynamic>? payload) {
    if (payload == null) return false;
    final result = payload['result'];
    if (result is Map) {
      final typeCode =
          (result['nodeTypeCode'] ?? '').toString().trim().toLowerCase();
      final typeName =
          (result['nodeTypeName'] ?? '').toString().trim().toLowerCase();
      if (typeCode == 'air' || typeName == 'ac') return true;
    }

    final normalized = payload['normalized'];
    if (normalized is! Map) return false;
    final rows = (normalized['rows'] as List?) ?? const [];
    final codes = rows
        .whereType<Map>()
        .map((row) => (row['code'] ?? row['metricTypeLibCode'] ?? '')
            .toString()
            .trim()
            .toLowerCase())
        .where((code) => code.isNotEmpty)
        .toSet();
    if (codes.isEmpty) return false;
    return codes.any((code) =>
        code.contains('air_') ||
        code.contains('return_air') ||
        code.contains('compressor') ||
        code.contains('shidusheding') ||
        code.contains('fengji'));
  }

  (List<ConsoleMetricRow>, List<ConsoleMetricRow>) _parsePowerRows(
    Map<String, dynamic>? telemetry,
  ) {
    final inlet = (telemetry?['inlet'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final pdu1 = (telemetry?['pdu1'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final pdu2 = (telemetry?['pdu2'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    final inletKw = _readDouble(inlet, const ['kw']);
    final pdu1Kw = _readDouble(pdu1, const ['kw']);
    final pdu2Kw = _readDouble(pdu2, const ['kw']);
    final pdu1Amps = _readDouble(pdu1, const ['amps']);
    final pdu2Amps = _readDouble(pdu2, const ['amps']);
    final pdu1Online = pdu1['online'] == true;
    final pdu2Online = pdu2['online'] == true;

    final pdu1Outlets = (pdu1['outlets'] as List?) ?? const [];
    final pdu2Outlets = (pdu2['outlets'] as List?) ?? const [];
    final pdu1OnCount =
        pdu1Outlets.where((e) => e is Map && e['isOn'] == true).length;
    final pdu2OnCount =
        pdu2Outlets.where((e) => e is Map && e['isOn'] == true).length;

    final inletRows = <ConsoleMetricRow>[
      ConsoleMetricRow(
        label: 'Offline State',
        value: (inlet['online'] == true) ? 'Normal' : 'Offline',
        isNormal: inlet['online'] == true,
      ),
      ConsoleMetricRow(
        label: 'Total Input Power',
        value: inletKw > 0 ? '${inletKw.toStringAsFixed(2)} kW' : '--',
      ),
      ConsoleMetricRow(
        label: 'PDU 1 Load',
        value: pdu1Kw > 0 ? '${pdu1Kw.toStringAsFixed(2)} kW' : '--',
      ),
      ConsoleMetricRow(
        label: 'PDU 2 Load',
        value: pdu2Kw > 0 ? '${pdu2Kw.toStringAsFixed(2)} kW' : '--',
      ),
      ConsoleMetricRow(
        label: 'PDU 1 Current',
        value: pdu1Amps > 0 ? '${pdu1Amps.toStringAsFixed(2)} A' : '--',
      ),
      ConsoleMetricRow(
        label: 'PDU 2 Current',
        value: pdu2Amps > 0 ? '${pdu2Amps.toStringAsFixed(2)} A' : '--',
      ),
    ];

    List<ConsoleMetricRow> outletSummaryRows(
      String label,
      Map<String, dynamic> pdu,
      int activeCount,
    ) {
      final kw = _readDouble(pdu, const ['kw']);
      final amps = _readDouble(pdu, const ['amps']);
      final outlets = (pdu['outlets'] as List?) ?? const [];
      final totalCount = outlets.length;
      final topOutlet = _topOutlet(outlets);
      return [
        ConsoleMetricRow(
          label: '$label Status',
          value: pdu['online'] == true ? 'Normal' : 'Offline',
          isNormal: pdu['online'] == true,
        ),
        ConsoleMetricRow(
          label: '$label Total Power',
          value: kw > 0 ? '${kw.toStringAsFixed(2)} kW' : '--',
        ),
        ConsoleMetricRow(
          label: '$label Total Current',
          value: amps > 0 ? '${amps.toStringAsFixed(2)} A' : '--',
        ),
        ConsoleMetricRow(
          label: '$label Active Outlets',
          value: totalCount > 0 ? '$activeCount / $totalCount' : '--',
        ),
        ConsoleMetricRow(
          label: '$label Top Outlet',
          value: topOutlet ?? '--',
        ),
      ];
    }

    final outletRows = <ConsoleMetricRow>[
      ...outletSummaryRows('PDU 1', pdu1, pdu1OnCount),
      ...outletSummaryRows('PDU 2', pdu2, pdu2OnCount),
    ];

    if (!pdu1Online && !pdu2Online && inletKw <= 0) {
      return (const [], const []);
    }

    return (inletRows, outletRows);
  }

  (List<ConsoleMetricRow>, List<ConsoleMetricRow>) _parseUpsRows(
    Map<String, dynamic>? rackTelemetry, {
    Map<String, dynamic>? upsPayload,
    int? upsNodeId,
  }) {
    final inlet = (rackTelemetry?['inlet'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final payloadRecords = _recordsFromPayload(upsPayload)
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    final rawRecords = (inlet['records'] as List?) ?? const [];
    var records = payloadRecords.isNotEmpty
        ? payloadRecords
        : rawRecords
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList();
    if (records.isEmpty) {
      final raw = (rackTelemetry?['raw'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final rawInlet = (raw['inlet'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      records = _recordsFromPayload(rawInlet)
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
    }

    if (records.isEmpty && inlet.isEmpty) {
      return (const [], const []);
    }

    final outputVoltage = _getMetricValue(
      records,
      prefixes: const [
        'outputvoltagevaluesinglephase_',
        'output_voltage_single_phase',
        'outputvoltage',
        'ups_output_voltage',
        'dianyazhidanxiang',
      ],
      exactNames: const ['Output Voltage', 'Voltage'],
    );
    final outputLoadRatio = _getMetricValue(
      records,
      prefixes: const [
        'outputloadratio',
        'loadratio',
        'ups_load_ratio',
        'load_ratio',
      ],
      exactNames: const ['Output Load Ratio', 'Load Ratio'],
    );
    final inputVoltage = _getMetricValue(
      records,
      prefixes: const [
        'inputvoltagevaluesinglephase_',
        'input_voltage_single_phase',
        'inputvoltage',
        'voltagevaluesinglephase_',
        'voltage',
        'dianyazhidanxiang',
      ],
      exactNames: const ['Input Voltage', 'Voltage'],
    );
    final inputFrequency = _getMetricValue(
      records,
      prefixes: const [
        'inputfrequency',
        'input_frequency',
        'frequencyvalue',
        'frequency',
        'ac_frequency',
        'edingpinlv',
      ],
      exactNames: const ['Input Frequency', 'Frequency', 'Rated Frequency'],
    );

    final inletOnline = inlet['online'] == true;
    final inletKw = _readDouble(inlet, const ['kw']);
    final effectiveInputVoltage = inputVoltage ?? outputVoltage;
    final effectiveOutputVoltage =
        outputVoltage ?? (inletOnline ? effectiveInputVoltage : null);
    final effectiveOutputLoadRatio =
        outputLoadRatio ?? _deriveLoadRatio(inletKw, effectiveInputVoltage);

    AppLog.d(
      'UPS parse snapshot',
      tag: 'RackConsoleUPS',
      fields: {
        'upsNodeId': upsNodeId,
        'recordCount': records.length,
        'inletOnline': inletOnline,
        'inletKw': inletKw,
        'outputVoltage': outputVoltage,
        'outputLoadRatio': outputLoadRatio,
        'inputVoltage': inputVoltage,
        'inputFrequency': inputFrequency,
        'debugCodes': (rackTelemetry?['debug'] as Map?)?['inletCodes'],
        'sampleNames': records.take(8).map((r) => r['name']).toList(),
        'sampleCodes': records
            .take(8)
            .map((r) => r['code'] ?? r['metricTypeLibCode'])
            .toList(),
      },
    );

    final parameterRows = <ConsoleMetricRow>[
      ConsoleMetricRow(
        label: 'Output Voltage',
        value: _formatMetric(effectiveOutputVoltage, unit: 'V', decimals: 0),
      ),
      ConsoleMetricRow(
        label: 'Output Load Ratio',
        value: _formatMetric(effectiveOutputLoadRatio, unit: '%', decimals: 0),
      ),
      ConsoleMetricRow(
        label: 'Offline State',
        value: inletOnline ? 'Normal' : 'Offline',
        isNormal: inletOnline,
      ),
      ConsoleMetricRow(
        label: 'Input Voltage',
        value: _formatMetric(effectiveInputVoltage, unit: 'V', decimals: 2),
      ),
      ConsoleMetricRow(
        label: 'Input Frequency',
        value: _formatMetric(inputFrequency, unit: 'Hz', decimals: 0),
      ),
    ].where((row) => row.value != '--').toList();

    final workingMode = _readStatusText(
      records,
      exactNames: const ['Working mode'],
      contains: const ['working mode', 'work mode'],
      fallback: inletOnline ? 'Online' : 'Offline',
    );
    final upsStatus = _readStatusText(
      records,
      exactNames: const ['UPS status', 'Status'],
      contains: const ['ups status'],
      fallback: inletOnline ? 'Normal' : 'Offline',
    );
    final workingCondition = _readStatusText(
      records,
      exactNames: const ['Working condition'],
      contains: const ['working condition'],
      fallback: upsStatus,
    );
    final selfInspection = _readStatusText(
      records,
      exactNames: const ['Self inspection'],
      contains: const ['self inspection', 'self-check'],
      fallback: '--',
    );
    final promptSound = _readStatusText(
      records,
      exactNames: const ['Prompt sound'],
      contains: const ['prompt sound', 'buzzer'],
      fallback: '--',
    );
    final mainsPower = _readStatusText(
      records,
      exactNames: const ['Mains power'],
      contains: const ['mains power', 'utility power'],
      fallback: inletOnline ? 'Normal' : 'Offline',
    );
    final powerOn = _readStatusText(
      records,
      exactNames: const ['Power on'],
      contains: const ['power on'],
      fallback: inletOnline ? 'Normal' : 'Offline',
    );
    final battery = _readStatusText(
      records,
      exactNames: const ['Battery'],
      contains: const ['battery'],
      fallback: '--',
    );

    final statusRows = <ConsoleMetricRow>[
      ConsoleMetricRow(
        label: 'Working mode',
        value: workingMode,
        isNormal: _isNormalStatus(workingMode),
      ),
      ConsoleMetricRow(
        label: 'UPS status',
        value: upsStatus,
        isNormal: _isNormalStatus(upsStatus),
      ),
      ConsoleMetricRow(
        label: 'Working condition',
        value: workingCondition,
        isNormal: _isNormalStatus(workingCondition),
      ),
      ConsoleMetricRow(
        label: 'Self inspection',
        value: selfInspection,
        isNormal: _isNormalStatus(selfInspection),
      ),
      ConsoleMetricRow(
        label: 'Prompt sound',
        value: promptSound,
        isNormal: _isNormalStatus(promptSound),
      ),
      ConsoleMetricRow(
        label: 'Mains power',
        value: mainsPower,
        isNormal: _isNormalStatus(mainsPower),
      ),
      ConsoleMetricRow(
        label: 'Power on',
        value: powerOn,
        isNormal: _isNormalStatus(powerOn),
      ),
      ConsoleMetricRow(
        label: 'Battery',
        value: battery,
        isNormal: _isNormalStatus(battery),
      ),
    ].where((row) => row.value != '--').toList();

    return (parameterRows, statusRows);
  }

  (
    List<ConsoleMetricRow>,
    List<ConsoleMetricRow>,
    List<ConsoleMetricRow>,
    String?,
    String?
  ) _parseAcRows(
    Map<String, dynamic>? acPayload, {
    int? acNodeId,
  }) {
    final normalized =
        (acPayload?['normalized'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final sections =
        (normalized['sections'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};

    final metricRowsRaw = (sections['metric'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => row.cast<String, dynamic>())
        .toList();
    final settingRowsRaw = (sections['setting'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => row.cast<String, dynamic>())
        .toList();
    final statusRowsRaw = (sections['status'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => row.cast<String, dynamic>())
        .toList();

    AppLog.d(
      'AC parse snapshot',
      tag: 'RackConsoleAC',
      fields: {
        'acNodeId': acNodeId,
        'metricCount': metricRowsRaw.length,
        'settingCount': settingRowsRaw.length,
        'statusCount': statusRowsRaw.length,
        'sampleMetricNames':
            metricRowsRaw.take(8).map((r) => r['name']).toList(),
        'sampleSettingCodes':
            settingRowsRaw.take(8).map((r) => r['code']).toList(),
        'sampleStatusNames':
            statusRowsRaw.take(8).map((r) => r['name']).toList(),
      },
    );

    final metricRows = <ConsoleMetricRow>[
      _consoleMetricFromRow(
        _findNormalizedRow(
          metricRowsRaw,
          exactNames: const ['Supply air temp'],
          contains: const ['supply air temp', 'outlet temperature'],
        ),
        fallbackLabel: 'Supply air temp',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          metricRowsRaw,
          exactNames: const ['Return air temp'],
          contains: const ['return air temp', 'return temperature'],
        ),
        fallbackLabel: 'Return air temp',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          metricRowsRaw,
          exactNames: const ['Return air humidity'],
          contains: const ['return air humidity', 'return humidity'],
        ),
        fallbackLabel: 'Return air humidity',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          metricRowsRaw,
          exactNames: const ['Compressor speed'],
          contains: const ['compressor speed'],
        ),
        fallbackLabel: 'Compressor speed',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          metricRowsRaw,
          exactNames: const ['Indoor fan speed'],
          contains: const ['indoor fan speed', 'fan speed'],
        ),
        fallbackLabel: 'Indoor fan speed',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          metricRowsRaw,
          exactNames: const ['Outdoor fan speed'],
          contains: const ['outdoor fan speed'],
        ),
        fallbackLabel: 'Outdoor fan speed',
      ),
    ].where((row) => row.value != '--').toList();

    final settingRows = <ConsoleMetricRow>[
      _consoleMetricFromRow(
        _findNormalizedRow(
          settingRowsRaw,
          exactNames: const ['Reset'],
          contains: const ['reset'],
        ),
        fallbackLabel: 'Reset',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          settingRowsRaw,
          exactNames: const ['Power on/off'],
          contains: const ['power on/off'],
        ),
        fallbackLabel: 'Power on/off',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          settingRowsRaw,
          exactNames: const ['Supply air temp setting'],
          contains: const ['supply air temp setting'],
        ),
        fallbackLabel: 'Supply air temp setting',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          settingRowsRaw,
          exactNames: const ['Return air temp setting'],
          contains: const ['return air temp setting'],
        ),
        fallbackLabel: 'Return air temp setting',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          settingRowsRaw,
          exactNames: const ['Humd setting'],
          contains: const ['humd setting', 'humidity setting'],
        ),
        fallbackLabel: 'Humd setting',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          settingRowsRaw,
          exactNames: const ['Supply Air High Humd Alarm'],
          contains: const ['supply air high humd alarm'],
        ),
        fallbackLabel: 'Supply Air High Humd Alarm',
      ),
    ].where((row) => row.value != '--').toList();

    final statusRows = <ConsoleMetricRow>[
      _consoleMetricFromRow(
        _findNormalizedRow(
          statusRowsRaw,
          exactNames: const ['Electric Heater Status'],
          contains: const ['electric heater status'],
        ),
        fallbackLabel: 'Electric Heater Status',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          statusRowsRaw,
          exactNames: const ['Electric Heater'],
          contains: const ['electric heater'],
        ),
        fallbackLabel: 'Electric Heater',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          statusRowsRaw,
          exactNames: const ['Current operating state'],
          contains: const ['current operating state'],
        ),
        fallbackLabel: 'Current operating state',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          statusRowsRaw,
          exactNames: const ['Compressor Status'],
          contains: const ['compressor status'],
        ),
        fallbackLabel: 'Compressor Status',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          statusRowsRaw,
          exactNames: const ['Water pump'],
          contains: const ['water pump'],
        ),
        fallbackLabel: 'Water pump',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          statusRowsRaw,
          exactNames: const ['Temp control'],
          contains: const ['temp control'],
        ),
        fallbackLabel: 'Temp control',
      ),
    ].where((row) => row.value != '--').toList();

    final unitStatus = _readNormalizedText(
      statusRowsRaw,
      exactNames: const ['Unit Status'],
      contains: const ['unit status'],
      fallback: null,
    );
    final compressorStatus = _readNormalizedText(
          statusRowsRaw,
          exactNames: const ['Compressor'],
          contains: const ['compressor'],
          fallback: null,
        ) ??
        _readNormalizedText(
          statusRowsRaw,
          exactNames: const ['Compressor Status'],
          contains: const ['compressor status'],
          fallback: null,
        );

    return (metricRowsRaw.isEmpty &&
            statusRowsRaw.isEmpty &&
            settingRowsRaw.isEmpty)
        ? (const [], const [], const [], null, null)
        : (
            metricRows,
            settingRows,
            statusRows,
            unitStatus,
            compressorStatus,
          );
  }

  String? _topOutlet(List outlets) {
    Map<String, dynamic>? best;
    double bestWatts = 0;
    for (final item in outlets) {
      if (item is! Map) continue;
      final watts = _readDouble(
        item.cast<String, dynamic>(),
        const ['watts', 'power'],
      );
      if (watts > bestWatts) {
        bestWatts = watts;
        best = item.cast<String, dynamic>();
      }
    }
    if (best == null || bestWatts <= 0) return null;
    final index = best['index']?.toString() ?? '?';
    return 'Outlet $index (${bestWatts.toStringAsFixed(0)} W)';
  }

  List<ConsoleBreakdownItem> _parseCapacityBreakdown(List? raw) {
    if (raw == null || raw.isEmpty) return const [];

    final first = raw.first;
    if (first is! Map) return const [];
    final itemPowers = first['itemPowers'];
    if (itemPowers is! List || itemPowers.isEmpty) return const [];

    final parsed = <({String label, double power})>[];
    for (final item in itemPowers) {
      if (item is! Map) continue;
      final label = (item['name'] ?? item['itemName'] ?? item['label'] ?? '')
          .toString()
          .trim();
      final power = _readDouble(
        item.cast<String, dynamic>(),
        const ['power', 'value', 'trendVal'],
      );
      if (label.isEmpty || power <= 0) continue;
      parsed.add((label: label, power: power));
    }
    if (parsed.isEmpty) return const [];

    final total = parsed.fold<double>(0, (sum, item) => sum + item.power);
    if (total <= 0) return const [];

    return parsed
        .map(
          (item) => ConsoleBreakdownItem(
            label: item.label,
            percentage: (item.power / total) * 100,
          ),
        )
        .toList()
      ..sort((a, b) => b.percentage.compareTo(a.percentage));
  }

  double _readDouble(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  List<dynamic> _recordsFromPayload(Map<String, dynamic>? payload) {
    if (payload == null) return const [];
    final result = payload['result'];
    if (result is! Map) return const [];
    final map = result.cast<String, dynamic>();
    for (final key in const ['metrics', 'records', 'list', 'data']) {
      final value = map[key];
      if (value is List) return List<dynamic>.from(value);
    }
    return const [];
  }

  Map<String, dynamic>? _findNormalizedRow(
    List<Map<String, dynamic>> rows, {
    List<String> exactNames = const [],
    List<String> contains = const [],
  }) {
    final normalizedExact = exactNames.map((e) => e.toLowerCase()).toList();
    final normalizedContains = contains.map((e) => e.toLowerCase()).toList();
    for (final row in rows) {
      final code = (row['code'] ?? row['metricTypeLibCode'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final name = (row['name'] ?? '').toString().trim().toLowerCase();
      if (normalizedExact.any((exact) => name == exact || code == exact)) {
        return row;
      }
      if (normalizedContains
          .any((needle) => name.contains(needle) || code.contains(needle))) {
        return row;
      }
    }
    return null;
  }

  String? _readNormalizedText(
    List<Map<String, dynamic>> rows, {
    List<String> exactNames = const [],
    List<String> contains = const [],
    required String? fallback,
  }) {
    final row = _findNormalizedRow(
      rows,
      exactNames: exactNames,
      contains: contains,
    );
    if (row == null) return fallback;
    return _displayValueForRow(row) ?? fallback;
  }

  ConsoleMetricRow _consoleMetricFromRow(
    Map<String, dynamic>? row, {
    required String fallbackLabel,
  }) {
    final value = row == null ? '--' : (_displayValueForRow(row) ?? '--');
    final label = row?['name']?.toString().trim();
    return ConsoleMetricRow(
      label: (label == null || label.isEmpty) ? fallbackLabel : label,
      value: value,
      isNormal: _isNormalStatus(value),
    );
  }

  String? _displayValueForRow(Map<String, dynamic> row) {
    final valueStr = row['valueStr']?.toString().trim();
    if (valueStr != null &&
        valueStr.isNotEmpty &&
        valueStr.toLowerCase() != 'null') {
      return valueStr;
    }

    final value = row['value'] ?? row['val'] ?? row['writerVal'];
    final unit = row['codeUnit']?.toString().trim() ?? '';
    if (value is num) {
      final decimals = value % 1 == 0 ? 0 : 1;
      final formatted = value.toStringAsFixed(decimals);
      return unit.isEmpty ? formatted : '$formatted $unit';
    }
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty && text.toLowerCase() != 'null') {
      return unit.isEmpty ? text : '$text $unit';
    }
    return null;
  }

  double? _getMetricValue(
    List<Map<String, dynamic>> records, {
    List<String> prefixes = const [],
    List<String> exactNames = const [],
  }) {
    final record = _findRecord(
      records,
      prefixes: prefixes,
      exactNames: exactNames,
    );
    if (record == null) return null;
    final value = record['value'] ?? record['val'] ?? record['writerVal'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  Map<String, dynamic>? _findRecord(
    List<Map<String, dynamic>> records, {
    List<String> prefixes = const [],
    List<String> exactNames = const [],
    List<String> contains = const [],
  }) {
    final normalizedPrefixes = prefixes.map((e) => e.toLowerCase()).toList();
    final normalizedExact = exactNames.map((e) => e.toLowerCase()).toList();
    final normalizedContains = contains.map((e) => e.toLowerCase()).toList();

    for (final record in records) {
      final code = (record['code'] ?? record['metricTypeLibCode'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final name = (record['name'] ?? '').toString().trim().toLowerCase();
      final label = name.isNotEmpty ? name : code;

      final prefixMatch = normalizedPrefixes.any(
        (prefix) => code.startsWith(prefix) || name.startsWith(prefix),
      );
      final exactMatch = normalizedExact.any(
        (exact) => code == exact || name == exact,
      );
      final containsMatch = normalizedContains.any(
        (needle) => label.contains(needle),
      );

      if (prefixMatch || exactMatch || containsMatch) {
        return record;
      }
    }
    return null;
  }

  String _readStatusText(
    List<Map<String, dynamic>> records, {
    List<String> exactNames = const [],
    List<String> contains = const [],
    required String fallback,
  }) {
    final record = _findRecord(
      records,
      exactNames: exactNames,
      contains: contains,
    );
    if (record == null) return fallback;

    final valueStr = record['valueStr']?.toString().trim();
    if (valueStr != null && valueStr.isNotEmpty) {
      return valueStr;
    }

    final raw = record['value'] ??
        record['val'] ??
        record['writerVal'] ??
        record['valueStr'];
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim();
    }
    if (raw is num) {
      if (raw == 1) return 'Normal';
      if (raw == 0) return 'Offline';
      return raw.toString();
    }
    return fallback;
  }

  double? _deriveLoadRatio(double inletKw, double? inputVoltage) {
    if (inletKw <= 0) return null;
    if (inputVoltage != null && inputVoltage > 0) {
      final amps = (inletKw * 1000) / inputVoltage;
      const ratedCurrent = 32.0;
      final ratio = (amps / ratedCurrent) * 100;
      if (ratio > 0) return ratio.clamp(0.0, 100.0);
    }
    return null;
  }

  String _formatMetric(double? value,
      {required String unit, int decimals = 2}) {
    if (value == null) return '--';
    final formatted = value.toStringAsFixed(decimals);
    return '$formatted $unit';
  }

  bool _isNormalStatus(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'normal' ||
        normalized == 'online' ||
        normalized == 'close' ||
        normalized == 'on' ||
        normalized == 'yes' ||
        normalized == 'enabled';
  }

  SmartRackConsoleSnapshot currentSnapshot() {
    final base = SmartRackConsoleSnapshot.fromPoller(_poller);
    return base.copyWith(
      totalMonthEnergyKwh: _totalMonthEnergyKwh,
      capacityBreakdown: _capacityBreakdown,
      powerInletRows: _powerInletRows,
      powerOutletRows: _powerOutletRows,
      powerPdu1Outlets: _powerPdu1Outlets,
      powerPdu2Outlets: _powerPdu2Outlets,
      powerPdu1MetricRows: _powerPdu1MetricRows,
      powerPdu1StatusRows: _powerPdu1StatusRows,
      powerPdu1SettingRows: _powerPdu1SettingRows,
      powerPdu2MetricRows: _powerPdu2MetricRows,
      powerPdu2StatusRows: _powerPdu2StatusRows,
      powerPdu2SettingRows: _powerPdu2SettingRows,
      acMetricRows: _acMetricRows,
      acSettingRows: _acSettingRows,
      acStatusRows: _acStatusRows,
      acUnitStatus: _acUnitStatus,
      acCompressorStatus: _acCompressorStatus,
      upsParameterRows: _upsParameterRows,
      upsStatusRows: _upsStatusRows,
    );
  }
}
