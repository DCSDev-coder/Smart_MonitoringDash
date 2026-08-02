import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class RackConsoleUpdateInstaller {
  static const MethodChannel _channel =
      MethodChannel('my.dcstack.smartrack.console/updater');

  Future<RackConsoleAppVersion> currentVersion() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'getCurrentVersion',
    );
    return RackConsoleAppVersion(
      versionName: result?['versionName']?.toString() ?? 'Unknown',
      versionCode: _readInt(result?['versionCode']),
      packageName: result?['packageName']?.toString(),
    );
  }

  Future<String> saveApkBytes(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${dir.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> installApk(String apkPath) async {
    await _channel.invokeMethod<void>('installApk', {'apkPath': apkPath});
  }

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class RackConsoleAppVersion {
  const RackConsoleAppVersion({
    required this.versionName,
    required this.versionCode,
    this.packageName,
  });

  final String versionName;
  final int versionCode;
  final String? packageName;
}
