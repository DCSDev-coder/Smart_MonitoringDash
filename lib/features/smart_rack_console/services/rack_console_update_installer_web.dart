import 'dart:typed_data';

class RackConsoleUpdateInstaller {
  Future<RackConsoleAppVersion> currentVersion() async {
    return const RackConsoleAppVersion(
      versionName: String.fromEnvironment(
        'APP_VERSION_NAME',
        defaultValue: 'Web build',
      ),
      versionCode: int.fromEnvironment('APP_VERSION_CODE'),
      packageName: 'web',
    );
  }

  Future<String> saveApkBytes(Uint8List bytes, String fileName) {
    throw UnsupportedError('APK installation is only available on Android.');
  }

  Future<void> installApk(String apkPath) {
    throw UnsupportedError('APK installation is only available on Android.');
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
