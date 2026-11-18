import 'package:flutter/material.dart';

/// Central store for all application-wide constants.
class AppConstants {
  AppConstants._();

  // Server
  /// Fallback IP used if no Server IP is provided.
  static const String defaultBaseUrl = '219.92.246.237';

  // Auth Endpoints
  static const String loginPath = '/itom/sys/login';

  // Data Polling Endpoints
  static const String sysInfoPath = '/itom/sys/global/setting/sysInfo';
  static const String cabinetEnvPath = '/itom/assets/cabinet/cabinetEnv';
  static const String tempHumTopNPath =
      '/itom/server/dataTest/cabinetTempHumTopN';
  static const String environmentPath = '/itom/assets/cabinet/environment';
  static const String deviceStatusPath =
      '/itom/monitor/collectControlNode/byTypeForStatus';
  static const String alarmByLevelPath = '/itom/monitor/alarm/byLevel';
  static const String alarmRecoveryPath = '/itom/monitor/alarm/forRecovery';
  static const String alarmLastNPath = '/itom/monitor/alarm/last5WithCabinet';
  static const String cabinetStatsPath =
      '/itom/assets/cabinet/statisticsForStatus';
  static const String deviceStatsPath =
      '/itom/assets/device/statisticsForStatus';
  static const String cabinetForAlarmPath =
      '/itom/assets/cabinet/forAlarmByRange';
  static const String pueCheckPath = '/itom/monitor/pueRegion/checkPue';
  static const String pueCurrentPath = '/itom/monitor/pueRegion/getCurrentPue';
  static const String pueRegionAllPath = '/itom/monitor/pueRegion/getAll';
  static const String getPowerPath = '/itom/monitor/pueRegion/getPower';
  static const String findMonitorDataPath =
      '/itom/monitor/collectControlNode/byTypeForStatus';
  static const String getWithMetricPath =
      '/itom/monitor/collectControlNode/getWithMetric';
  static const String getStatusPath =
      '/itom/monitor/collectControlNode/getStatus';
  static const String listMetricPath =
      '/itom/monitor/collectControlNode/listMetric';
  static const String writeMetricPath =
      '/itom/monitor/collectControlNode/writeMetric';
  static const String listPowerEnvPath =
      '/itom/monitor/collectControlNode/view/listPowerEnv';
  static const String rangeDataPath = '/itom/server/dataTest/range';

  // Resource Capacity & Door Endpoints
  static const String redisInfoPath = '/itom/sys/actuator/redis/info';
  static const String redisMemoryPath = '/itom/sys/actuator/redis/memoryInfo';
  static const String gateListPath = '/itom/access/gate/listByLocationId';
  static const String cabinetDoorListPath =
      '/itom/access/cabinet/mangeListByLocationId';
  static const String openCloseDoorPath = '/itom/access/log/openClose';
  static const String accessLogPath = '/itom/access/log/list';

  static const String xSignGetPowerToday = '5001D427E80676284EA058A7556F65B9';
  static const String xSignGetPowerMonth = 'CBA99513ABC9F1C2687F04C2AD0AD860';

  static const Duration pollInterval = Duration(seconds: 15);

  static const String keyAccessToken = 'x_access_token';
  static const String keyUsername = 'username';

  static const double headerContentHeight = 56.0;
  static const double headerMargin = 8.0;
  static double headerHeight(BuildContext context) =>
      headerContentHeight + (headerMargin * 2);


  static bool hasCriticalBanner = false;

  static double headerClearance(BuildContext context, {bool? hasCritical}) {
    final media = MediaQuery.of(context);
    final statusBar = media.padding.top;
    final critical = hasCritical ?? hasCriticalBanner;

    final useSidebarHeader = media.size.width >= 600;
    if (useSidebarHeader) {
      return 6.0;
    }

    const headerTopPadding = 10.0;
    const headerBottomPadding = 10.0;
    return statusBar +
        headerTopPadding +
        headerContentHeight +
        headerBottomPadding +
        4.0 +
        (critical ? 60.0 : 0.0);
  }

  // Misc
  static String timestamp() =>
      (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
}
