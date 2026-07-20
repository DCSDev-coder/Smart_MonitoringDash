import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/config/site_runtime_config.dart';
import '../../../core/controllers/global_status_poller.dart';
import '../../../core/network/adapter_api_service.dart';
import '../../../core/network/api_service.dart';
import '../../../core/network/cpanel_api_service.dart';
import '../../../core/utils/app_log.dart';
import '../models/smart_rack_console_snapshot.dart';

enum RackConsoleSupplementalSection {
  overview,
  power,
  ups,
  ac,
  pdu,
}

class SmartRackConsoleRepository extends ChangeNotifier {
  SmartRackConsoleRepository._();

  static final instance = SmartRackConsoleRepository._();

  final GlobalStatusPoller _poller = GlobalStatusPoller.instance;

  bool _started = false;
  bool _fetchingSupplemental = false;
  int? _activeSiteId;
  final Set<RackConsoleSupplementalSection> _requestedSections =
      <RackConsoleSupplementalSection>{};
  final Set<RackConsoleSupplementalSection> _loadedSections =
      <RackConsoleSupplementalSection>{};
  final Map<int, int> _upsNodeIdBySite = <int, int>{};
  final Map<int, int> _acNodeIdBySite = <int, int>{};
  final Map<int, int> _inletNodeIdBySite = <int, int>{};
  final Map<int, int> _outletNodeIdBySite = <int, int>{};
  DateTime? _lastSupplementalFetchAt;
  double? _totalMonthEnergyKwh;
  double? _capacityUsedPct;
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

  void start({
    Set<RackConsoleSupplementalSection> initialSections = const {
      RackConsoleSupplementalSection.overview
    },
  }) {
    _requestedSections.addAll(initialSections);
    if (_started) {
      _maybeRefreshSupplemental();
      return;
    }
    _started = true;
    _poller.addListener(_handlePollerChanged);
    _handlePollerChanged();
  }

  void stop() {
    if (!_started) return;
    _started = false;
    _poller.removeListener(_handlePollerChanged);
    _requestedSections.clear();
  }

  void requestSection(RackConsoleSupplementalSection section) {
    requestSections({section});
  }

  void requestSections(Set<RackConsoleSupplementalSection> sections) {
    final before = _requestedSections.length;
    _requestedSections.addAll(sections);
    if (_requestedSections.length == before) return;
    _maybeRefreshSupplemental();
  }

  void _handlePollerChanged() {
    notifyListeners();
    _maybeRefreshSupplemental();
  }

  void _maybeRefreshSupplemental() {
    final site = CpanelApiService.instance.currentSite;
    final siteId = SiteRuntimeConfig.siteId(site);
    if (siteId == null || !AdapterApiService.instance.isConfigured) {
      if (_hasSupplementalCache) {
        _clearSupplementalCache(siteId);
        notifyListeners();
      }
      return;
    }

    if (_activeSiteId != siteId) {
      _clearSupplementalCache(siteId);
    }

    if (_requestedSections.isEmpty) return;

    final now = DateTime.now();
    final hasUnloadedSections =
        _requestedSections.any((section) => !_loadedSections.contains(section));
    final shouldRefresh = hasUnloadedSections ||
        _lastSupplementalFetchAt == null ||
        now.difference(_lastSupplementalFetchAt!) >=
            const Duration(seconds: 30);
    if (!shouldRefresh || _fetchingSupplemental) return;

    _activeSiteId = siteId;
    unawaited(_refreshSupplemental(siteId, Set.of(_requestedSections)));
  }

  bool get _hasSupplementalCache =>
      _activeSiteId != null ||
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
      _upsStatusRows.isNotEmpty;

  void _clearSupplementalCache(int? siteId) {
    _activeSiteId = siteId;
    _loadedSections.clear();
    _lastSupplementalFetchAt = null;
    _totalMonthEnergyKwh = null;
    _capacityUsedPct = null;
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
    _inletNodeIdBySite.clear();
    _outletNodeIdBySite.clear();
  }

  Future<void> _refreshSupplemental(
    int siteId,
    Set<RackConsoleSupplementalSection> sections,
  ) async {
    if (sections.isEmpty) return;
    _fetchingSupplemental = true;
    try {
      final now = DateTime.now();
      final site = CpanelApiService.instance.currentSite;

      if (sections.contains(RackConsoleSupplementalSection.overview)) {
        final powerMonth = await AdapterApiService.instance.fetchPowerMonth(
          siteId: siteId,
        );
        final powerMonthResult =
            (powerMonth?['result'] as Map?)?.cast<String, dynamic>() ??
                const <String, dynamic>{};
        final totalMonthEnergyKwh =
            _readDouble(powerMonthResult, const ['Total', 'total']);

        final cabinetCapacity =
            await AdapterApiService.instance.fetchCabinetCapacity(
          siteId: siteId,
        );
        final cabinetCapacityResult =
            (cabinetCapacity?['result'] as Map?)?.cast<String, dynamic>();

        _totalMonthEnergyKwh =
            totalMonthEnergyKwh > 0 ? totalMonthEnergyKwh : null;
        _capacityUsedPct = _readOptionalDouble(
          cabinetCapacityResult,
          const ['usedPercent', 'used_percent', 'capacityUsedPct'],
        );
        _capacityBreakdown = _parseCapacityUInfo(cabinetCapacityResult);
      }

      Map<String, dynamic>? rackTelemetry;
      if (sections.contains(RackConsoleSupplementalSection.power) ||
          sections.contains(RackConsoleSupplementalSection.ups)) {
        rackTelemetry = await AdapterApiService.instance.fetchRackTelemetry(
          siteId: siteId,
          includeRaw: true,
        );
      }

      if (sections.contains(RackConsoleSupplementalSection.power)) {
        final inletNodeId = await _resolveInletNodeId(siteId, site);
        Map<String, dynamic>? inletPayload;
        if (inletNodeId != null) {
          inletPayload = await AdapterApiService.instance.fetchNodeWithMetric(
            siteId: siteId,
            nodeId: inletNodeId,
          );
        }
        final outletNodeId = await _resolveOutletNodeId(
          siteId,
          site,
          inletNodeId: inletNodeId,
        );
        Map<String, dynamic>? outletPayload;
        if (outletNodeId != null) {
          outletPayload = await AdapterApiService.instance.fetchNodeWithMetric(
            siteId: siteId,
            nodeId: outletNodeId,
          );
        }
        final powerRows = _parsePowerRows(
          rackTelemetry,
          inletPayload: inletPayload,
          inletNodeId: inletNodeId,
          outletPayload: outletPayload,
          outletNodeId: outletNodeId,
        );
        _powerInletRows = powerRows.$1;
        _powerOutletRows = powerRows.$2;
      }

      if (sections.contains(RackConsoleSupplementalSection.ups)) {
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
        _upsParameterRows = upsRows.$1;
        _upsStatusRows = upsRows.$2;
      }

      if (sections.contains(RackConsoleSupplementalSection.ac)) {
        final acNodeId = await _resolveAcNodeId(siteId, site);
        Map<String, dynamic>? acPayload;
        if (acNodeId != null) {
          acPayload = await AdapterApiService.instance.fetchNodeWithMetric(
            siteId: siteId,
            nodeId: acNodeId,
          );
        }
        final acRows = _parseAcRows(acPayload, acNodeId: acNodeId);
        _acMetricRows = acRows.$1;
        _acSettingRows = acRows.$2;
        _acStatusRows = acRows.$3;
        _acUnitStatus = acRows.$4;
        _acCompressorStatus = acRows.$5;
      }

      if (sections.contains(RackConsoleSupplementalSection.pdu)) {
        final pduNodeIds = await _resolvePduNodeIds(siteId, site);
        final pduBundles = <(
          List<ConsoleMetricRow>,
          List<ConsoleMetricRow>,
          List<ConsoleMetricRow>,
          List<Map<String, dynamic>>
        )>[];
        for (final nodeId in pduNodeIds.take(2)) {
          pduBundles.add(await _fetchPduSectionRows(siteId, nodeId));
        }
        while (pduBundles.length < 2) {
          pduBundles.add((const [], const [], const [], const []));
        }
        _powerPdu1MetricRows = pduBundles[0].$1;
        _powerPdu1StatusRows = pduBundles[0].$2;
        _powerPdu1SettingRows = pduBundles[0].$3;
        _powerPdu1Outlets = pduBundles[0].$4;
        _powerPdu2MetricRows = pduBundles[1].$1;
        _powerPdu2StatusRows = pduBundles[1].$2;
        _powerPdu2SettingRows = pduBundles[1].$3;
        _powerPdu2Outlets = pduBundles[1].$4;
      }

      _loadedSections.addAll(sections);
      _lastSupplementalFetchAt = now;
      notifyListeners();
    } catch (_) {
      _lastSupplementalFetchAt = DateTime.now();
    } finally {
      _fetchingSupplemental = false;
    }
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

  Future<
      (
        List<ConsoleMetricRow>,
        List<ConsoleMetricRow>,
        List<ConsoleMetricRow>,
        List<Map<String, dynamic>>
      )> _fetchPduSectionRows(
    int siteId,
    int nodeId,
  ) async {
    final adapterPayload = await AdapterApiService.instance.fetchNodeWithMetric(
      siteId: siteId,
      nodeId: nodeId,
    );
    final metricPayload =
        adapterPayload ?? await ApiService.instance.fetchNodeWithMetric(nodeId);
    final statusPayload = await AdapterApiService.instance.fetchNodeStatus(
          siteId: siteId,
          nodeId: nodeId,
        ) ??
        await ApiService.instance.fetchNodeStatus(nodeId);

    final metricRows = _parsePduMetricRows(metricPayload)
        .map((row) => row.copyWith(nodeId: nodeId))
        .toList();
    final statusRows = _parsePduStatusRows(
      statusPayload,
      view: false,
      nodeId: nodeId,
    );
    final settingRows = _parsePduSettingRows(
      metricPayload,
      nodeId: nodeId,
    );
    final outlets = _parsePduOutlets(metricPayload, statusPayload);

    AppLog.d(
      'PDU parse snapshot',
      tag: 'RackConsolePDU',
      fields: {
        'siteId': siteId,
        'nodeId': nodeId,
        'metricCount': metricRows.length,
        'statusCount': statusRows.length,
        'settingCount': settingRows.length,
        'outletCount': outlets.length,
        'readingOutlets':
            outlets.where((item) => item['hasReading'] == true).length,
        'activeOutlets': outlets.where((item) => item['isOn'] == true).length,
        'sampleMetricNames':
            metricRows.take(8).map((row) => row.label).toList(),
        'sampleStatusNames':
            statusRows.take(8).map((row) => row.label).toList(),
        'sampleSettingNames':
            settingRows.take(8).map((row) => row.label).toList(),
      },
    );

    return (metricRows, statusRows, settingRows, outlets);
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
          exactNames: const ['Rated Voltage', 'Voltage'],
          contains: const ['rated voltage', 'voltage'],
        ),
        fallbackLabel: 'Rated Voltage',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          records,
          exactNames: const ['Rated Current', 'Current'],
          contains: const ['rated current', 'current'],
        ),
        fallbackLabel: 'Rated Current',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          records,
          exactNames: const ['Rated Frequency', 'Frequency'],
          contains: const ['rated frequency', 'frequency'],
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
          exactNames: const ['Output Voltage', 'Voltage'],
          contains: const ['output voltage', 'dianyazhidanxiang'],
        ),
        fallbackLabel: 'Voltage',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          records,
          exactNames: const ['Output Current', 'Current'],
          contains: const ['output current', 'dianliuzhidanxiang'],
        ),
        fallbackLabel: 'Current',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          records,
          exactNames: const ['Active Power', 'active power(single-phase)'],
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
          exactNames: const ['Total Energy', 'Energy'],
          contains: const ['total energy', 'energy'],
        ),
        fallbackLabel: 'Total Energy',
      ),
      _consoleMetricFromRow(
        _findNormalizedRow(
          records,
          exactNames: const ['Frequency'],
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
    int? nodeId,
  }) {
    final records = _recordsFromPayload(payload)
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    if (records.isEmpty) return const [];

    final filtered =
        records.where((row) => _matchesPduSection(row, view)).toList();
    final chosen = filtered.isNotEmpty
        ? filtered
        : records.where((row) => _looksLikePduSectionRow(row, view)).toList();
    final resolved = chosen.isNotEmpty ? chosen : records;

    final rows = resolved
        .map(
          (row) => ConsoleMetricRow(
            label: row['name']?.toString().trim().isNotEmpty == true
                ? row['name'].toString().trim()
                : (row['statusType']?.toString().trim().isNotEmpty == true
                    ? row['statusType'].toString().trim()
                    : 'Status'),
            value: _displayStatusValue(row),
            isNormal: _isNormalStatus(_displayStatusValue(row)),
            metricCode: _rowMetricCode(row),
            nodeId: nodeId,
            rawValue: _rawValueForRow(row),
            writeMap: _rowWriteMap(row),
            isEditable: view && _isWritableRow(row),
          ),
        )
        .where((row) => row.value != '--')
        .toList();

    return rows;
  }

  List<ConsoleMetricRow> _parsePduSettingRows(
    Map<String, dynamic>? payload, {
    int? nodeId,
  }) {
    final records = _recordsFromPayload(payload)
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    if (records.isEmpty) return const [];

    final resolved = records.where((row) {
      final label = [
        row['name'],
        row['code'],
        row['metricTypeLibCode'],
      ]
          .where((item) => item != null)
          .map((item) => item.toString().toLowerCase())
          .join(' ');
      final hasWriteMap = _rowWriteMap(row)?.isNotEmpty == true;
      final writable = row['write'] == true || row['writable'] == true;
      return (hasWriteMap || writable) &&
          (label.contains('output control') ||
              label.contains('power on') ||
              label.contains('power off') ||
              label.contains('switch') ||
              label.contains('control') ||
              label.contains('setting') ||
              label.contains('reset'));
    }).toList();

    return resolved
        .map(
          (row) => ConsoleMetricRow(
            label: row['name']?.toString().trim().isNotEmpty == true
                ? row['name'].toString().trim()
                : 'Setting',
            value: _displayValueForRow(row) ?? '--',
            isNormal: _isNormalStatus(_displayValueForRow(row) ?? '--'),
            metricCode: _rowMetricCode(row),
            nodeId: nodeId,
            rawValue: _rawValueForRow(row),
            writeMap: _rowWriteMap(row),
            isEditable: _isWritableRow(row),
          ),
        )
        .where((row) => row.value != '--')
        .toList();
  }

  bool _matchesPduSection(Map<String, dynamic> row, bool view) {
    final rawView = row['view'];
    if (rawView is bool) {
      return rawView == view;
    }

    final viewText = rawView?.toString().trim().toLowerCase();
    if (viewText != null && viewText.isNotEmpty) {
      if (viewText == view.toString().toLowerCase()) {
        return true;
      }
      if (viewText == '1' || viewText == 'yes' || viewText == 'on') {
        return view;
      }
      if (viewText == '0' || viewText == 'no' || viewText == 'off') {
        return !view;
      }
    }

    return _looksLikePduSectionRow(row, view);
  }

  bool _looksLikePduSectionRow(Map<String, dynamic> row, bool view) {
    final label = [
      row['name'],
      row['statusType'],
      row['code'],
    ]
        .where((item) => item != null)
        .map((item) => item.toString().toLowerCase())
        .join(' ');

    if (view) {
      return label.contains('control') ||
          label.contains('setting') ||
          label.contains('reset') ||
          label.contains('power on') ||
          label.contains('power off') ||
          label.contains('enable') ||
          label.contains('switch');
    }

    return label.contains('status') ||
        label.contains('alarm') ||
        label.contains('breaker') ||
        label.contains('error') ||
        label.contains('warning') ||
        label.contains('normal');
  }

  List<Map<String, dynamic>> _parsePduOutlets(
    Map<String, dynamic>? metricPayload,
    Map<String, dynamic>? statusPayload,
  ) {
    final metricRecords = _recordsFromPayload(metricPayload)
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    final statusRecords = _recordsFromPayload(statusPayload)
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    if (metricRecords.isEmpty && statusRecords.isEmpty) {
      return const [];
    }

    final totalOutlets = _getMetricValue(
          metricRecords,
          exactNames: const ['Outlets'],
          contains: const ['outlets'],
        )?.round() ??
        16;

    final wattsByIndex = <int, double>{};
    final ampsByIndex = <int, double>{};
    final energyByIndex = <int, double>{};
    final isOnByIndex = <int, bool>{};

    for (final record in metricRecords) {
      final index = _extractOutletIndex(record);
      if (index == null) continue;
      final label = (record['name'] ?? record['code'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final value = _readRecordDouble(record);
      if (label.contains('active power')) {
        wattsByIndex[index] = value;
      } else if (label.contains('current')) {
        ampsByIndex[index] = value;
      } else if (label.contains('energy')) {
        energyByIndex[index] = value;
      }
    }

    for (final record in statusRecords) {
      final index = _extractOutletIndex(record);
      if (index == null) continue;
      final label = (record['name'] ?? record['statusType'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (!label.contains('output control')) continue;
      final status = _displayValueForRow(record)?.trim().toLowerCase();
      if (status == null || status.isEmpty) continue;
      isOnByIndex[index] =
          status == 'on' || status == '1' || status == 'enable';
    }

    final outlets = <Map<String, dynamic>>[];
    for (var index = 1; index <= totalOutlets; index++) {
      final watts = wattsByIndex[index] ?? (ampsByIndex[index] ?? 0.0) * 220.0;
      final amps = ampsByIndex[index] ?? 0.0;
      final hasReading = (watts > 0) || (amps > 0);
      final isOn = isOnByIndex[index] ?? hasReading;
      final energy = energyByIndex[index] ?? 0.0;
      outlets.add({
        'index': index,
        'isOn': isOn,
        'hasReading': hasReading,
        'watts': watts,
        'amps': amps,
        'energy': energy,
      });
    }

    return outlets;
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

  Future<int?> _resolveInletNodeId(
    int siteId,
    Map<String, dynamic>? site,
  ) async {
    final cached = _inletNodeIdBySite[siteId];
    if (cached != null) return cached;

    final configured = SiteRuntimeConfig.nodeIdForType(site, type: 'power');
    if (configured != null) {
      final payload = await AdapterApiService.instance.fetchNodeWithMetric(
        siteId: siteId,
        nodeId: configured,
      );
      if (_looksLikeInletPayload(payload)) {
        _inletNodeIdBySite[siteId] = configured;
        return configured;
      }
    }

    final candidates = await _discoverPowerEnvCandidates(siteId);
    candidates.sort(
      (a, b) => _inletCandidateScore(b).compareTo(_inletCandidateScore(a)),
    );
    for (final candidate in candidates) {
      final nodeId = _nodeIdFromCandidate(candidate);
      if (nodeId == null) continue;
      final payload = await AdapterApiService.instance.fetchNodeWithMetric(
        siteId: siteId,
        nodeId: nodeId,
      );
      if (!_looksLikeInletPayload(payload)) continue;
      _inletNodeIdBySite[siteId] = nodeId;
      AppLog.d(
        'Inlet node discovered',
        tag: 'RackConsolePower',
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

  Future<int?> _resolveOutletNodeId(
    int siteId,
    Map<String, dynamic>? site, {
    int? inletNodeId,
  }) async {
    final cached = _outletNodeIdBySite[siteId];
    if (cached != null) return cached;

    final candidates = await _discoverPowerEnvCandidates(siteId);
    candidates.sort(
      (a, b) => _outletCandidateScore(b).compareTo(_outletCandidateScore(a)),
    );
    for (final candidate in candidates) {
      final nodeId = _nodeIdFromCandidate(candidate);
      if (nodeId == null || nodeId == inletNodeId) continue;
      final payload = await AdapterApiService.instance.fetchNodeWithMetric(
        siteId: siteId,
        nodeId: nodeId,
      );
      if (!_looksLikeOutletPayload(payload)) continue;
      _outletNodeIdBySite[siteId] = nodeId;
      AppLog.d(
        'Outlet node discovered',
        tag: 'RackConsolePower',
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

  int _inletCandidateScore(Map<String, dynamic> record) {
    final name = (record['name'] ?? '').toString().toLowerCase();
    final typeName = (record['nodeTypeName'] ?? '').toString().toLowerCase();
    final typeCode = (record['nodeTypeCode'] ?? '').toString().toLowerCase();
    final typeId = int.tryParse(record['nodeTypeId']?.toString() ?? '');
    int score = 0;
    if (typeId == 14) score += 40;
    if (name == 'inlet') score += 60;
    if (name.contains('inlet')) score += 40;
    if (name.contains('incoming')) score += 20;
    if (typeName.contains('power')) score += 20;
    if (typeCode.contains('power')) score += 20;
    return score;
  }

  int _outletCandidateScore(Map<String, dynamic> record) {
    final name = (record['name'] ?? '').toString().toLowerCase();
    final typeName = (record['nodeTypeName'] ?? '').toString().toLowerCase();
    final typeCode = (record['nodeTypeCode'] ?? '').toString().toLowerCase();
    final typeId = int.tryParse(record['nodeTypeId']?.toString() ?? '');
    int score = 0;
    if (typeId == 14) score += 40;
    if (name == 'outlet') score += 60;
    if (name.contains('outlet')) score += 40;
    if (name.contains('output')) score += 24;
    if (name.contains('outgoing')) score += 20;
    if (typeName.contains('power')) score += 20;
    if (typeCode.contains('power')) score += 20;
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

  bool _looksLikeInletPayload(Map<String, dynamic>? payload) {
    if (payload == null) return false;
    final result = payload['result'];
    if (result is Map) {
      final name = (result['name'] ?? '').toString().trim().toLowerCase();
      if (name == 'inlet' || name.contains('inlet')) return true;
    }

    final records = _recordsFromPayload(payload)
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    if (records.isEmpty) return false;

    final codes = records
        .map((record) => (record['code'] ?? record['metricTypeLibCode'] ?? '')
            .toString()
            .trim()
            .toLowerCase())
        .where((code) => code.isNotEmpty)
        .toSet();

    return codes.any((code) =>
        code.contains('incomingline1') ||
        code.contains('incomingline2') ||
        code.contains('totalactivepowerincomingline') ||
        code.contains('phaseavoltageincomingline'));
  }

  bool _looksLikeOutletPayload(Map<String, dynamic>? payload) {
    if (payload == null) return false;
    final result = payload['result'];
    if (result is Map) {
      final name = (result['name'] ?? '').toString().trim().toLowerCase();
      if (name == 'outlet' || name.contains('outlet')) return true;
    }

    final records = _recordsFromPayload(payload)
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    if (records.isEmpty) return false;

    final codes = records
        .map((record) => (record['code'] ?? record['metricTypeLibCode'] ?? '')
            .toString()
            .trim()
            .toLowerCase())
        .where((code) => code.isNotEmpty)
        .toSet();

    return codes.any((code) =>
        code.contains('outgoingline1') ||
        code.contains('outgoingline2') ||
        code.contains('totalactivepoweroutgoingline') ||
        code.contains('phaseavoltageoutgoingline') ||
        code.contains('outputvoltage') ||
        code.contains('outputcurrent') ||
        code.contains('outputfrequency'));
  }

  (List<ConsoleMetricRow>, List<ConsoleMetricRow>) _parsePowerRows(
    Map<String, dynamic>? telemetry, {
    Map<String, dynamic>? inletPayload,
    int? inletNodeId,
    Map<String, dynamic>? outletPayload,
    int? outletNodeId,
  }) {
    final inlet = (telemetry?['inlet'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final pdu1 = (telemetry?['pdu1'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final pdu2 = (telemetry?['pdu2'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    final inletKw = _readDouble(inlet, const ['kw']);
    final pdu1Online = pdu1['online'] == true;
    final pdu2Online = pdu2['online'] == true;

    final inletRows = _parseInletRows(
      inletPayload,
      telemetry: telemetry,
      inletNodeId: inletNodeId,
    );

    final outletRows = _parseOutletRows(
      outletPayload,
      telemetry: telemetry,
      outletNodeId: outletNodeId,
    );

    if (!pdu1Online && !pdu2Online && inletKw <= 0) {
      return (inletRows, const []);
    }

    return (inletRows, outletRows);
  }

  List<ConsoleMetricRow> _parseOutletRows(
    Map<String, dynamic>? outletPayload, {
    required Map<String, dynamic>? telemetry,
    int? outletNodeId,
  }) {
    final payloadRecords = _recordsFromPayload(outletPayload)
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();

    if (payloadRecords.isNotEmpty) {
      AppLog.d(
        'Outlet parse snapshot',
        tag: 'RackConsolePower',
        fields: {
          'outletNodeId': outletNodeId,
          'recordCount': payloadRecords.length,
          'sampleNames': payloadRecords.take(8).map((r) => r['name']).toList(),
          'sampleCodes': payloadRecords
              .take(8)
              .map((r) => r['code'] ?? r['metricTypeLibCode'])
              .toList(),
        },
      );

      final sorted = [...payloadRecords]..sort(_compareNormalizedRows);
      return sorted
          .where((row) {
            final view = row['view'];
            return view == null || view == true;
          })
          .map(
            (row) => _consoleMetricFromRow(
              row,
              fallbackLabel: _fallbackLabelForRow(row, 'Parameter'),
            ).copyWith(nodeId: outletNodeId),
          )
          .where((row) => row.value != '--')
          .toList();
    }

    final pdu1 = (telemetry?['pdu1'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final pdu2 = (telemetry?['pdu2'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

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

    final pdu1Outlets = (pdu1['outlets'] as List?) ?? const [];
    final pdu2Outlets = (pdu2['outlets'] as List?) ?? const [];
    final pdu1OnCount =
        pdu1Outlets.where((e) => e is Map && e['isOn'] == true).length;
    final pdu2OnCount =
        pdu2Outlets.where((e) => e is Map && e['isOn'] == true).length;

    return <ConsoleMetricRow>[
      ...outletSummaryRows('PDU 1', pdu1, pdu1OnCount),
      ...outletSummaryRows('PDU 2', pdu2, pdu2OnCount),
    ];
  }

  List<ConsoleMetricRow> _parseInletRows(
    Map<String, dynamic>? inletPayload, {
    required Map<String, dynamic>? telemetry,
    int? inletNodeId,
  }) {
    final payloadRecords = _recordsFromPayload(inletPayload)
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    final inlet = (telemetry?['inlet'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final rawRecords = (inlet['records'] as List?) ?? const [];
    final records = payloadRecords.isNotEmpty
        ? payloadRecords
        : rawRecords
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList();

    if (records.isEmpty) {
      final inletKw = _readDouble(inlet, const ['kw']);
      final pdu1 = (telemetry?['pdu1'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final pdu2 = (telemetry?['pdu2'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      return <ConsoleMetricRow>[
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
          value: _readDouble(pdu1, const ['kw']) > 0
              ? '${_readDouble(pdu1, const ['kw']).toStringAsFixed(2)} kW'
              : '--',
        ),
        ConsoleMetricRow(
          label: 'PDU 2 Load',
          value: _readDouble(pdu2, const ['kw']) > 0
              ? '${_readDouble(pdu2, const ['kw']).toStringAsFixed(2)} kW'
              : '--',
        ),
      ].where((row) => row.value != '--').toList();
    }

    AppLog.d(
      'Inlet parse snapshot',
      tag: 'RackConsolePower',
      fields: {
        'inletNodeId': inletNodeId,
        'recordCount': records.length,
        'sampleNames': records.take(8).map((r) => r['name']).toList(),
        'sampleCodes': records
            .take(8)
            .map((r) => r['code'] ?? r['metricTypeLibCode'])
            .toList(),
      },
    );

    final sorted = [...records]..sort(_compareNormalizedRows);
    return sorted
        .where((row) {
          final view = row['view'];
          return view == null || view == true;
        })
        .map(
          (row) => _consoleMetricFromRow(
            row,
            fallbackLabel: _fallbackLabelForRow(row, 'Parameter'),
          ).copyWith(nodeId: inletNodeId),
        )
        .where((row) => row.value != '--')
        .toList();
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

    final metricRows = _mapAcMetricLikeRows(metricRowsRaw);
    final settingRows = _mapAcMetricLikeRows(settingRowsRaw);
    final statusRows = _mapAcStatusRows(statusRowsRaw);

    final unitStatus = _readNormalizedStatusText(
      statusRowsRaw,
      exactNames: const ['Unit Status'],
      contains: const ['unit status'],
      fallback: null,
    );
    final compressorStatus = _readNormalizedStatusText(
          statusRowsRaw,
          exactNames: const ['Compressor'],
          contains: const ['compressor'],
          fallback: null,
        ) ??
        _readNormalizedStatusText(
          statusRowsRaw,
          exactNames: const ['Compressor Status'],
          contains: const ['compressor status'],
          fallback: null,
        );

    final nodeScopedMetricRows =
        metricRows.map((row) => row.copyWith(nodeId: acNodeId)).toList();
    final nodeScopedSettingRows =
        settingRows.map((row) => row.copyWith(nodeId: acNodeId)).toList();
    final nodeScopedStatusRows =
        statusRows.map((row) => row.copyWith(nodeId: acNodeId)).toList();

    return (metricRowsRaw.isEmpty &&
            statusRowsRaw.isEmpty &&
            settingRowsRaw.isEmpty)
        ? (const [], const [], const [], null, null)
        : (
            nodeScopedMetricRows,
            nodeScopedSettingRows,
            nodeScopedStatusRows,
            unitStatus,
            compressorStatus,
          );
  }

  List<ConsoleMetricRow> _mapAcMetricLikeRows(
    List<Map<String, dynamic>> rows,
  ) {
    final sorted = [...rows]..sort(_compareNormalizedRows);
    return sorted
        .map(
          (row) => _consoleMetricFromRow(
            row,
            fallbackLabel: _fallbackLabelForRow(row, 'Parameter'),
          ),
        )
        .where((row) => row.value != '--')
        .toList();
  }

  List<ConsoleMetricRow> _mapAcStatusRows(
    List<Map<String, dynamic>> rows,
  ) {
    final sorted = [...rows]..sort(_compareNormalizedRows);
    return sorted
        .map(
          (row) => ConsoleMetricRow(
            label: _fallbackLabelForRow(row, 'Status'),
            value: _displayStatusValue(row),
            isNormal: _isNormalStatus(_displayStatusValue(row)),
            metricCode: _rowMetricCode(row),
            rawValue: _rawValueForRow(row),
            writeMap: _rowWriteMap(row),
            isEditable: _isWritableRow(row),
          ),
        )
        .where((row) => row.value != '--')
        .toList();
  }

  int _compareNormalizedRows(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final aOrder = (a['orderNo'] is num)
        ? (a['orderNo'] as num).toDouble()
        : double.infinity;
    final bOrder = (b['orderNo'] is num)
        ? (b['orderNo'] as num).toDouble()
        : double.infinity;
    if (aOrder != bOrder) return aOrder.compareTo(bOrder);
    final aName = _fallbackLabelForRow(a, '').toLowerCase();
    final bName = _fallbackLabelForRow(b, '').toLowerCase();
    return aName.compareTo(bName);
  }

  String _fallbackLabelForRow(
    Map<String, dynamic>? row,
    String fallback,
  ) {
    if (row == null) return fallback;
    final label = (row['name'] ?? row['statusType'] ?? row['code'] ?? '')
        .toString()
        .trim();
    return label.isEmpty ? fallback : label;
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

  List<ConsoleBreakdownItem> _parseCapacityUInfo(
    Map<String, dynamic>? result,
  ) {
    final cabinetItems = result?['cabinetItemUInfo'];
    if (cabinetItems is! List || cabinetItems.isEmpty) return const [];

    final parsed = <ConsoleBreakdownItem>[];
    for (final item in cabinetItems) {
      if (item is! Map) continue;
      final label = (item['name'] ?? item['itemName'] ?? item['label'] ?? '')
          .toString()
          .trim();
      final percentage = _readDouble(
        item.cast<String, dynamic>(),
        const ['usedPercent', 'used_percent', 'capacityUsedPct'],
      );
      if (label.isEmpty) continue;
      parsed.add(
        ConsoleBreakdownItem(
          label: label,
          percentage: percentage.clamp(0.0, 100.0).toDouble(),
        ),
      );
    }
    return parsed..sort((a, b) => b.percentage.compareTo(a.percentage));
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

  double? _readOptionalDouble(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  List<dynamic> _recordsFromPayload(Map<String, dynamic>? payload) {
    if (payload == null) return const [];
    final result = payload['result'];
    if (result is List) {
      return List<dynamic>.from(result);
    }
    if (result is Map) {
      final map = result.cast<String, dynamic>();
      for (final key in const ['metrics', 'records', 'list', 'data']) {
        final value = map[key];
        if (value is List) return List<dynamic>.from(value);
      }
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

  String? _readNormalizedStatusText(
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
    return _displayStatusValue(row);
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
      metricCode: row == null ? null : _rowMetricCode(row),
      rawValue: row == null ? null : _rawValueForRow(row),
      writeMap: row == null ? null : _rowWriteMap(row),
      isEditable: _isWritableRow(row),
    );
  }

  String? _rowMetricCode(Map<String, dynamic> row) {
    final code = (row['code'] ??
            row['metricTypeLibCode'] ??
            row['statusTypeCode'] ??
            row['statusType'] ??
            row['name'] ??
            '')
        .toString()
        .trim();
    return code.isEmpty ? null : code;
  }

  String? _rawValueForRow(Map<String, dynamic> row) {
    final raw = row['value'] ?? row['val'] ?? row['writerVal'];
    if (raw is num) return raw.toString();
    final text = raw?.toString().trim();
    if (text != null && text.isNotEmpty && text.toLowerCase() != 'null') {
      return text;
    }
    final valueStr = row['valueStr']?.toString().trim();
    if (valueStr != null &&
        valueStr.isNotEmpty &&
        valueStr.toLowerCase() != 'null') {
      return valueStr;
    }
    return null;
  }

  Map<String, String>? _rowWriteMap(Map<String, dynamic> row) {
    final raw = row['writeMap'];
    if (raw is! Map) return null;
    final map = <String, String>{};
    raw.forEach((key, value) {
      final k = key?.toString().trim();
      final v = value?.toString().trim();
      if (k != null && k.isNotEmpty && v != null && v.isNotEmpty) {
        map[k] = v;
      }
    });
    return map.isEmpty ? null : map;
  }

  bool _isWritableRow(Map<String, dynamic>? row) {
    if (row == null) return false;
    if (row['write'] == true || row['writable'] == true) return true;
    final text = [
      row['code'],
      row['metricTypeLibCode'],
      row['statusTypeCode'],
      row['name'],
      row['statusType'],
    ]
        .where((item) => item != null)
        .map((item) => item.toString().toLowerCase())
        .join(' ');
    return text.contains('control') ||
        text.contains('setting') ||
        text.contains('reset') ||
        text.contains('enable') ||
        text.contains('disable') ||
        text.contains('power on') ||
        text.contains('power off') ||
        text.contains('switch') ||
        text.contains('mode');
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

  double _readRecordDouble(Map<String, dynamic> record) {
    final value = record['value'] ?? record['val'] ?? record['writerVal'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  int? _extractOutletIndex(Map<String, dynamic> record) {
    final label =
        (record['name'] ?? record['statusType'] ?? record['code'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    final match = RegExp(r'outlet\s*(\d+)').firstMatch(label);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  double? _getMetricValue(
    List<Map<String, dynamic>> records, {
    List<String> prefixes = const [],
    List<String> exactNames = const [],
    List<String> contains = const [],
  }) {
    final record = _findRecord(
      records,
      prefixes: prefixes,
      exactNames: exactNames,
      contains: contains,
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

  Future<Map<String, dynamic>?> writeSetting({
    required ConsoleMetricRow row,
    required Object value,
    String? pin,
  }) async {
    final site = CpanelApiService.instance.currentSite;
    final siteId = SiteRuntimeConfig.siteId(site);
    final nodeId = row.nodeId;
    final metricCode = row.metricCode?.trim() ?? '';
    if (siteId == null || nodeId == null || metricCode.isEmpty) {
      return null;
    }

    if (AdapterApiService.instance.isConfigured) {
      if (pin != null && pin.trim().isNotEmpty) {
        return AdapterApiService.instance.writeNodeMetricWithUserPin(
          siteId: siteId,
          nodeId: nodeId,
          metricTypeLibCode: metricCode,
          value: value,
          pin: pin.trim(),
        );
      }
      return AdapterApiService.instance.writeNodeMetric(
        siteId: siteId,
        nodeId: nodeId,
        metricTypeLibCode: metricCode,
        value: value,
      );
    }

    return ApiService.instance.writeNodeMetric(
      nodeId: nodeId,
      metricTypeLibCode: metricCode,
      value: value,
    );
  }

  Future<void> refreshNow({
    Set<RackConsoleSupplementalSection>? sections,
  }) async {
    final site = CpanelApiService.instance.currentSite;
    final siteId = SiteRuntimeConfig.siteId(site);
    if (siteId == null || !AdapterApiService.instance.isConfigured) return;
    final targetSections = sections ?? Set.of(_requestedSections);
    _requestedSections.addAll(targetSections);
    await _refreshSupplemental(siteId, targetSections);
  }

  Future<void> refreshSections(
    Set<RackConsoleSupplementalSection> sections,
  ) {
    return refreshNow(sections: sections);
  }

  SmartRackConsoleSnapshot currentSnapshot() {
    final base = SmartRackConsoleSnapshot.fromPoller(_poller);
    return base.copyWith(
      totalMonthEnergyKwh: _totalMonthEnergyKwh,
      capacityUsedPct: _capacityUsedPct,
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
