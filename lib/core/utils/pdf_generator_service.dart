import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/network/cpanel_api_service.dart';
import '../../core/network/adapter_api_service.dart';
import '../../core/network/api_service.dart';
import '../../core/config/site_runtime_config.dart';

class PdfGeneratorService {
  PdfGeneratorService._();
  static final PdfGeneratorService instance = PdfGeneratorService._();

  Future<void> generateAndDownloadA4Report({
    required DateTime startDate,
    required DateTime endDate,
    required bool includeEnvironment,
    required bool includePower,
    required bool includeAlarms,
    required bool includeDoorLogs,
  }) async {
    final pdf = pw.Document();

    final ttf = pw.Font.helvetica();
    final ttfBold = pw.Font.helveticaBold();

    final siteName =
        CpanelApiService.instance.currentSite?['site_name']?.toString() ??
            'Smart Rack';
    final reportDateRange =
        '${DateFormat('MMM dd, yyyy').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}';

    // 2. Data Fetching
    final startTimeMs = startDate.millisecondsSinceEpoch;
    final endTimeMs = endDate.millisecondsSinceEpoch;
    final siteId =
        SiteRuntimeConfig.siteId(CpanelApiService.instance.currentSite);

    bool shouldUseAdapter = false;
    if (siteId != null) {
      final mode = CpanelApiService.instance.currentSite?['edge_adapter_mode']
              ?.toString() ??
          '1';
      final isOnline = CpanelApiService
              .instance.currentSite?['edge_adapter_status']
              ?.toString() ==
          'online';
      shouldUseAdapter = (mode == '1' && isOnline);
    }

    // --- ALARMS ---
    List<Map<String, dynamic>> alarmsList = [];
    if (includeAlarms) {
      Map<String, dynamic>? res;
      if (shouldUseAdapter && siteId != null) {
        res = await AdapterApiService.instance.fetchReportAlarms(
          siteId: siteId,
          startTime: startTimeMs,
          endTime: endTimeMs,
          page: 1,
          pageSize: 100,
        );
      } else {
        res = await ApiService.instance.fetchReportAlarms(
          startTime: startTimeMs,
          endTime: endTimeMs,
        );
      }
      alarmsList =
          (res?['result']?['records'] as List?)?.cast<Map<String, dynamic>>() ??
              [];
    }

    // --- DOOR LOGS ---
    List<Map<String, dynamic>> doorLogsList = [];
    Map<int, String> localDoorNames = {};
    if (includeDoorLogs) {
      Map<String, dynamic>? res;
      if (shouldUseAdapter && siteId != null) {
        res = await AdapterApiService.instance.fetchAccessLogs(
          siteId: siteId,
          startTime: startTimeMs,
          endTime: endTimeMs,
          accessType: '1',
        );

        final doorsRes =
            await AdapterApiService.instance.fetchDoors(siteId: siteId);
        int front = 0;
        int back = 0;
        final rawDoors = doorsRes?['result'];
        final List doorList = rawDoors is List
            ? rawDoors
            : (rawDoors is Map
                ? ((rawDoors['detailList'] as List?) ??
                    (rawDoors['detail_list'] as List?) ??
                    (rawDoors['accessList'] as List?) ??
                    (rawDoors['doorList'] as List?) ??
                    const [])
                : const []);
        for (final d in doorList) {
          if (d is! Map) continue;
          final loc =
              (d['location_in_rack'] ?? d['accessName'] ?? d['name'] ?? '')
                  .toString()
                  .toLowerCase();
          final idRaw = d['id'] ?? d['accessId'] ?? d['access_id'];
          final dId = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw');
          if (dId == null) continue;
          if (loc.contains('front')) {
            front += 1;
            localDoorNames[dId] = 'Front $front';
          } else {
            back += 1;
            localDoorNames[dId] = 'Back $back';
          }
        }
      } else {
        res = await ApiService.instance.fetchDoorAccessLogs(accessType: '1');
      }

      final dynamic resultData = res?['result'];
      final rawLogs = _extractAccessLogRows(resultData);

      for (final log in rawLogs) {
        final ch = int.tryParse(log['channel']?.toString() ?? '');
        final name = log['accessName']?.toString();
        if (ch != null && name != null && name.isNotEmpty) {
          localDoorNames[ch] = name;
        }
      }

      List<Map<String, dynamic>> cpanelLogs = [];
      if (!shouldUseAdapter && siteId != null) {
        final remoteLogs =
            await CpanelApiService.instance.fetchRemoteAccessLogs(
          siteId: siteId,
          startTime: startTimeMs,
          endTime: endTimeMs,
        );

        for (final cLog in remoteLogs) {
          final dId = int.tryParse(cLog['door_id']?.toString() ?? '');
          String doorName = 'Door $dId';
          if (dId != null && localDoorNames.containsKey(dId)) {
            doorName = localDoorNames[dId]!;
          }

          cpanelLogs.add({
            'opTime': cLog['created_at'],
            'opUser': cLog['username'],
            'accessName': doorName,
            'channel': cLog['door_id'],
            'opMethod': 'Remote Web',
          });
        }
      }

      doorLogsList = rawLogs.where((log) {
        final timeStr = log['opTime']?.toString() ?? '';
        final dt = DateTime.tryParse(timeStr);
        if (dt == null) return true;
        final ms = dt.millisecondsSinceEpoch;
        if (ms < startTimeMs || ms > endTimeMs) return false;

        final u = (log['opUser'] ??
                    log['openUser'] ??
                    log['userName'] ??
                    log['username'])
                ?.toString()
                .toLowerCase() ??
            '';
        if (u == 'superadmin' || u == 'admin' || u == 'remote open') {
          return false;
        }
        return true;
      }).toList();

      doorLogsList.addAll(cpanelLogs);
      doorLogsList.sort((a, b) {
        final ta = _formatTime(a['opTime'] ?? a['created_at']);
        final tb = _formatTime(b['opTime'] ?? b['created_at']);
        return tb.compareTo(ta); // Descending
      });
    }

    double itPower = 0.0;
    double totalPower = 0.0;
    if (includePower && siteId != null) {
      Map<String, dynamic>? energyRes;
      if (shouldUseAdapter) {
        energyRes =
            await AdapterApiService.instance.fetchPowerMonth(siteId: siteId);
      } else {
        final cabinetId =
            SiteRuntimeConfig.cabinetId(CpanelApiService.instance.currentSite);
        if (cabinetId != null) {
          energyRes = await ApiService.instance.fetchPowerMonth(id: cabinetId);
        }
      }
      final pwMap = energyRes?['result'] as Map<String, dynamic>? ?? {};

      itPower = double.tryParse((pwMap['IT Device'] ??
                      pwMap['IT DEVICE'] ??
                      pwMap['IT'] ??
                      pwMap['it_power'] ??
                      pwMap['itPower'])
                  ?.toString() ??
              '0') ??
          0.0;
      totalPower = double.tryParse((pwMap['Total'] ??
                      pwMap['TOTAL'] ??
                      pwMap['total_power'] ??
                      pwMap['totalPower'])
                  ?.toString() ??
              '0') ??
          0.0;
    }

    final double coolingPower =
        (totalPower > itPower) ? (totalPower - itPower) : 0.0;
    final double pueValue =
        (itPower > 0 && totalPower > 0) ? (totalPower / itPower) : 1.00;

    // 3. Layout the PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // HEADER
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('SMART RACK ANALYTICS',
                          style: pw.TextStyle(
                              font: ttfBold,
                              fontSize: 24,
                              color: PdfColors.blue900)),
                      pw.SizedBox(height: 4),
                      pw.Text('Comprehensive Data Report',
                          style: pw.TextStyle(
                              font: ttf,
                              fontSize: 14,
                              color: PdfColors.grey700)),
                    ]),
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Site: $siteName',
                          style: pw.TextStyle(font: ttfBold, fontSize: 12)),
                      pw.Text('Date Range: $reportDateRange',
                          style: pw.TextStyle(
                              font: ttf,
                              fontSize: 10,
                              color: PdfColors.grey600)),
                      pw.Text(
                          'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                          style: pw.TextStyle(
                              font: ttf,
                              fontSize: 10,
                              color: PdfColors.grey600)),
                    ]),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(thickness: 2, color: PdfColors.blue900),
            pw.SizedBox(height: 24),

            // ENVIRONMENT SECTION
            if (includeEnvironment) ...[
              pw.Text('Environment Metrics (24H Trend)',
                  style: pw.TextStyle(
                      font: ttfBold, fontSize: 18, color: PdfColors.blue800)),
              pw.SizedBox(height: 8),
              pw.Container(
                height: 150,
                child: pw.Chart(
                  grid: pw.CartesianGrid(
                    xAxis: pw.FixedAxis([0, 4, 8, 12, 16, 20, 24]),
                    yAxis: pw.FixedAxis([0, 20, 40, 60, 80, 100]),
                  ),
                  datasets: [
                    pw.LineDataSet(
                      color: PdfColors.redAccent,
                      lineWidth: 2,
                      data: const [
                        pw.PointChartValue(0, 22.0),
                        pw.PointChartValue(4, 21.5),
                        pw.PointChartValue(8, 23.0),
                        pw.PointChartValue(12, 24.5),
                        pw.PointChartValue(16, 23.8),
                        pw.PointChartValue(20, 22.5),
                        pw.PointChartValue(24, 22.0),
                      ],
                    ),
                    pw.LineDataSet(
                      color: PdfColors.blueAccent,
                      lineWidth: 2,
                      isCurved: true,
                      data: const [
                        pw.PointChartValue(0, 45.0),
                        pw.PointChartValue(4, 46.0),
                        pw.PointChartValue(8, 44.0),
                        pw.PointChartValue(12, 42.0),
                        pw.PointChartValue(16, 43.5),
                        pw.PointChartValue(20, 45.5),
                        pw.PointChartValue(24, 45.0),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Container(
                      width: 10, height: 10, color: PdfColors.redAccent),
                  pw.SizedBox(width: 4),
                  pw.Text('Temperature (°C)',
                      style: pw.TextStyle(font: ttf, fontSize: 10)),
                  pw.SizedBox(width: 16),
                  pw.Container(
                      width: 10, height: 10, color: PdfColors.blueAccent),
                  pw.SizedBox(width: 4),
                  pw.Text('Humidity (%)',
                      style: pw.TextStyle(font: ttf, fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 24),
            ],

            // POWER SECTION
            if (includePower) ...[
              pw.Text('Power & Efficiency',
                  style: pw.TextStyle(
                      font: ttfBold, fontSize: 18, color: PdfColors.blue800)),
              pw.SizedBox(height: 8),
              pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(8))),
                  child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricBox('IT Power',
                            '${itPower.toStringAsFixed(2)} kW', ttf, ttfBold),
                        _buildMetricBox(
                            'Other / Cooling',
                            '${coolingPower.toStringAsFixed(2)} kW',
                            ttf,
                            ttfBold),
                        _buildMetricBox(
                            'Total Power',
                            '${totalPower.toStringAsFixed(2)} kW',
                            ttf,
                            ttfBold),
                        _buildMetricBox(
                            'PUE', pueValue.toStringAsFixed(2), ttf, ttfBold),
                      ])),
              pw.SizedBox(height: 24),
              _buildFullWidthChart(
                  'Total Power Trend',
                  'Power (kW)',
                  'Time (Hours)',
                  const [
                    pw.PointChartValue(0, 520),
                    pw.PointChartValue(4, 530),
                    pw.PointChartValue(8, 550),
                    pw.PointChartValue(12, 540),
                    pw.PointChartValue(16, 560),
                    pw.PointChartValue(20, 551),
                    pw.PointChartValue(24, 545),
                  ],
                  PdfColors.orange,
                  ttf,
                  ttfBold,
                  [0, 200, 400, 600, 800]),
              pw.SizedBox(height: 32),
              _buildFullWidthChart(
                  'Other / Cooling Power Trend',
                  'Power (kW)',
                  'Time (Hours)',
                  const [
                    pw.PointChartValue(0, 300),
                    pw.PointChartValue(4, 315),
                    pw.PointChartValue(8, 330),
                    pw.PointChartValue(12, 325),
                    pw.PointChartValue(16, 340),
                    pw.PointChartValue(20, 334),
                    pw.PointChartValue(24, 330),
                  ],
                  PdfColors.redAccent,
                  ttf,
                  ttfBold,
                  [0, 100, 200, 300, 400]),
              pw.SizedBox(height: 24),
            ],

            // ALARMS SECTION
            if (includeAlarms) ...[
              pw.Text('Alarm History (${alarmsList.length} events)',
                  style: pw.TextStyle(
                      font: ttfBold, fontSize: 18, color: PdfColors.blue800)),
              pw.SizedBox(height: 8),
              if (alarmsList.isEmpty)
                pw.Text('No alarms recorded in this date range.',
                    style: pw.TextStyle(
                        font: ttf,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey600))
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Date/Time', 'Alarm Type', 'Severity', 'Status'],
                  data: alarmsList.map((a) {
                    final startTime =
                        _formatTime(a['occurrenceTime'] ?? a['createTime']);
                    final isResolved = a['recoveryTime'] != null ||
                        a['recoverTime'] != null ||
                        a['alarmStatus']?.toString() == '2';
                    final resolveTimeStr = isResolved
                        ? _formatTime(a['recoveryTime'] ?? a['recoverTime'],
                            dateOnly: true)
                        : '';
                    final statusStr =
                        isResolved ? 'Resolved on $resolveTimeStr' : 'Ongoing';

                    return [
                      startTime,
                      a['alarmName']?.toString() ??
                          a['alarmItemName']?.toString() ??
                          a['alarmTypeName']?.toString() ??
                          a['alarmType']?.toString() ??
                          'Unknown',
                      a['alarmLevel']?.toString() == '1'
                          ? 'Critical'
                          : 'Warning',
                      statusStr,
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(
                      font: ttfBold, color: PdfColors.white, fontSize: 10),
                  headerDecoration:
                      const pw.BoxDecoration(color: PdfColors.blue900),
                  cellStyle: pw.TextStyle(font: ttf, fontSize: 9),
                  cellAlignment: pw.Alignment.centerLeft,
                  oddRowDecoration:
                      const pw.BoxDecoration(color: PdfColors.grey100),
                  border:
                      pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                ),
              pw.SizedBox(height: 24),
            ],

            // DOOR LOGS SECTION
            if (includeDoorLogs) ...[
              pw.Text('Door Access Logs (${doorLogsList.length} events)',
                  style: pw.TextStyle(
                      font: ttfBold, fontSize: 18, color: PdfColors.blue800)),
              pw.SizedBox(height: 8),
              if (doorLogsList.isEmpty)
                pw.Text('No door access events recorded in this date range.',
                    style: pw.TextStyle(
                        font: ttf,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey600))
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Date/Time', 'User', 'Door', 'Method'],
                  data: doorLogsList.map((log) {
                    final timeRaw = log['opTime'] ??
                        log['createTime'] ??
                        log['occurrenceTime'];
                    final time = _formatTime(timeRaw);
                    final user = (log['opUser'] ??
                                log['openUser'] ??
                                log['userName'] ??
                                log['username'])
                            ?.toString() ??
                        'Unknown';
                    final ch = int.tryParse(log['channel']?.toString() ?? '');
                    final door = ch != null
                        ? (localDoorNames[ch] ?? 'Door $ch')
                        : 'Unknown Door';
                    final method = log['opMethod']?.toString() ?? 'PIN/Card';
                    return [time, user, door, method];
                  }).toList(),
                  headerStyle: pw.TextStyle(
                      font: ttfBold, color: PdfColors.white, fontSize: 10),
                  headerDecoration:
                      const pw.BoxDecoration(color: PdfColors.blueGrey800),
                  cellStyle: pw.TextStyle(font: ttf, fontSize: 9),
                  cellAlignment: pw.Alignment.centerLeft,
                  oddRowDecoration:
                      const pw.BoxDecoration(color: PdfColors.grey100),
                  border:
                      pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                ),
              pw.SizedBox(height: 24),
            ],
          ];
        },
      ),
    );

    final bytes = await pdf.save();

    final formattedDate = DateFormat('yyyyMMdd').format(DateTime.now());
    final cleanSiteName = siteName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Report_${cleanSiteName}_$formattedDate.pdf',
    );
  }

  pw.Widget _buildMetricBox(
      String label, String value, pw.Font ttf, pw.Font ttfBold) {
    return pw.Column(children: [
      pw.Text(value,
          style: pw.TextStyle(
              font: ttfBold, fontSize: 16, color: PdfColors.blue900)),
      pw.SizedBox(height: 4),
      pw.Text(label,
          style:
              pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700)),
    ]);
  }

  pw.Widget _buildFullWidthChart(
    String title,
    String yAxisLabel,
    String xAxisLabel,
    List<pw.PointChartValue> data,
    PdfColor color,
    pw.Font ttf,
    pw.Font ttfBold,
    List<double> yAxisTicks,
  ) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  font: ttfBold, fontSize: 14, color: PdfColors.blue800)),
          pw.SizedBox(height: 12),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Transform.rotateBox(
              angle: -1.5708, // -90 degrees in radians
              child: pw.Text(yAxisLabel,
                  style: pw.TextStyle(
                      font: ttfBold, fontSize: 10, color: PdfColors.grey700)),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
                child: pw.Column(children: [
              pw.Container(
                height: 140,
                child: pw.Chart(
                  grid: pw.CartesianGrid(
                    xAxis: pw.FixedAxis([0, 4, 8, 12, 16, 20, 24]),
                    yAxis: pw.FixedAxis(yAxisTicks),
                  ),
                  datasets: [
                    pw.LineDataSet(
                      color: color,
                      lineWidth: 2,
                      isCurved: true,
                      data: data,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(xAxisLabel,
                  style: pw.TextStyle(
                      font: ttfBold, fontSize: 10, color: PdfColors.grey700)),
            ]))
          ]),
        ]);
  }

  List<Map<String, dynamic>> _extractAccessLogRows(dynamic resultData) {
    if (resultData == null) return [];
    if (resultData is List) return resultData.cast<Map<String, dynamic>>();
    if (resultData is Map<String, dynamic>) {
      if (resultData.containsKey('records') && resultData['records'] is List) {
        return (resultData['records'] as List).cast<Map<String, dynamic>>();
      }
      if (resultData.containsKey('pageData') &&
          resultData['pageData'] is List) {
        return (resultData['pageData'] as List).cast<Map<String, dynamic>>();
      }
      if (resultData.containsKey('rows') && resultData['rows'] is List) {
        return (resultData['rows'] as List).cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  String _formatTime(dynamic rawTime, {bool dateOnly = false}) {
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

      // If it's a numeric string, try parsing as epoch
      if (dt == null && double.tryParse(s) != null) {
        final v = double.parse(s).toInt();
        dt = v > 2000000000
            ? DateTime.fromMillisecondsSinceEpoch(v)
            : DateTime.fromMillisecondsSinceEpoch(v * 1000);
      }
    }

    if (dt == null) return '--';
    return DateFormat(dateOnly ? 'MMM dd, yyyy' : 'MMM dd, yyyy HH:mm')
        .format(dt);
  }
}
