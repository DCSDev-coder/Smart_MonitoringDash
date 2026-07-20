import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import 'rack_console_update_installer.dart';

class RackConsoleUpdateManifest {
  const RackConsoleUpdateManifest({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.releaseNotes,
    required this.mandatory,
  });

  final int versionCode;
  final String versionName;
  final String apkUrl;
  final List<String> releaseNotes;
  final bool mandatory;

  factory RackConsoleUpdateManifest.fromJson(Map<String, dynamic> json) {
    final rawNotes = json['releaseNotes'];
    final notes = rawNotes is List
        ? rawNotes.map((item) => item.toString()).toList()
        : [
            if ((rawNotes ?? '').toString().trim().isNotEmpty)
              rawNotes.toString().trim(),
          ];

    return RackConsoleUpdateManifest(
      versionCode: _readInt(json['versionCode']),
      versionName: (json['versionName'] ?? '').toString().trim(),
      apkUrl: (json['apkUrl'] ?? '').toString().trim(),
      releaseNotes: notes,
      mandatory: _readBool(json['mandatory']),
    );
  }

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _readBool(Object? value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }
}

class RackConsoleUpdateStatus {
  const RackConsoleUpdateStatus({
    required this.currentVersion,
    this.latest,
    this.downloadedApkPath,
  });

  final RackConsoleAppVersion currentVersion;
  final RackConsoleUpdateManifest? latest;
  final String? downloadedApkPath;

  bool get hasUpdate =>
      latest != null && latest!.versionCode > currentVersion.versionCode;

  String get latestLabel => latest == null
      ? 'Not checked'
      : '${latest!.versionName} (${latest!.versionCode})';
}

class RackConsoleUpdateService {
  RackConsoleUpdateService({
    RackConsoleUpdateInstaller? installer,
    http.Client? client,
  })  : _installer = installer ?? RackConsoleUpdateInstaller(),
        _client = client ?? http.Client();

  final RackConsoleUpdateInstaller _installer;
  final http.Client _client;

  Future<RackConsoleUpdateStatus> currentStatus() async {
    return RackConsoleUpdateStatus(
      currentVersion: await _installer.currentVersion(),
    );
  }

  Future<RackConsoleUpdateStatus> checkForUpdate() async {
    final current = await _installer.currentVersion();
    final manifestUrl = AppConfig.updateManifestUrl;
    if (manifestUrl.isEmpty) {
      throw const RackConsoleUpdateException(
        'Update manifest URL is not configured.',
      );
    }

    final res = await _client.get(
      Uri.parse(manifestUrl),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw RackConsoleUpdateException(
        'Update check failed (${res.statusCode}).',
      );
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw const RackConsoleUpdateException('Invalid update manifest.');
    }

    final latest = RackConsoleUpdateManifest.fromJson(decoded);
    if (latest.versionCode <= 0 || latest.versionName.isEmpty) {
      throw const RackConsoleUpdateException(
        'Update manifest is missing version information.',
      );
    }
    if (latest.apkUrl.isEmpty) {
      throw const RackConsoleUpdateException(
        'Update manifest is missing apkUrl.',
      );
    }

    return RackConsoleUpdateStatus(
      currentVersion: current,
      latest: latest,
    );
  }

  Future<RackConsoleUpdateStatus> downloadUpdate(
    RackConsoleUpdateStatus status,
  ) async {
    final latest = status.latest;
    if (latest == null) {
      throw const RackConsoleUpdateException('Check for updates first.');
    }
    if (!status.hasUpdate) {
      throw const RackConsoleUpdateException('No update is available.');
    }

    final res = await _client
        .get(Uri.parse(latest.apkUrl))
        .timeout(const Duration(minutes: 3));
    if (res.statusCode != 200) {
      throw RackConsoleUpdateException(
        'APK download failed (${res.statusCode}).',
      );
    }

    final apkPath = await _installer.saveApkBytes(
      Uint8List.fromList(res.bodyBytes),
      'rackconsole-${latest.versionName}-${latest.versionCode}.apk',
    );
    return RackConsoleUpdateStatus(
      currentVersion: status.currentVersion,
      latest: latest,
      downloadedApkPath: apkPath,
    );
  }

  Future<void> installDownloadedUpdate(RackConsoleUpdateStatus status) async {
    final path = status.downloadedApkPath;
    if (path == null || path.trim().isEmpty) {
      throw const RackConsoleUpdateException('Download the update first.');
    }
    await _installer.installApk(path);
  }
}

class RackConsoleUpdateException implements Exception {
  const RackConsoleUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
