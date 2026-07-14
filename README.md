# DCS Smart Rack Dashboard

Flutter application for the DCS Smart Monitoring mobile app.

## Run The Standard / Main App

The standard app is the default variant.

From [`Smart_MonitoringDash`](</Users/marketingdeveloper/DCStack/Smart Monitoring/Smart_MonitoringDash>), run:

```bash
flutter pub get
flutter run --dart-define-from-file=.env.json --dart-define=APP_VARIANT=main
```

If you want the shortest version, this also runs the standard app because `main` is already the default:

```bash
flutter run --dart-define-from-file=.env.json
```

## Run The Rack Console App

```bash
flutter run --dart-define-from-file=.env.json --dart-define=APP_VARIANT=rack_console
```

## Useful Examples

Run on Chrome:

```bash
flutter run -d chrome --dart-define-from-file=.env.json --dart-define=APP_VARIANT=main
```

Run on a connected iPhone:

```bash
flutter run -d ios --dart-define-from-file=.env.json --dart-define=APP_VARIANT=main
```

If you want to run on a physical iPhone from the terminal:

1. Connect the iPhone by USB and unlock it.
2. Tap `Trust This Computer` on the iPhone if prompted.
3. Make sure Developer Mode is enabled on the phone.
4. From `Smart_MonitoringDash`, run:

```bash
flutter devices
flutter run -d <iphone-device-id> --dart-define-from-file=.env.json --dart-define=APP_VARIANT=main
```

If the iPhone does not show up, run `flutter doctor -v` and confirm Xcode/iOS signing is ready.

Run on a connected Android device:

```bash
flutter run -d android --dart-define-from-file=.env.json --dart-define=APP_VARIANT=main
```

## Build Examples

Android APK for the standard / main app:

```bash
flutter build apk --release --dart-define-from-file=.env.json --dart-define=APP_VARIANT=main
```

iOS build for the standard / main app:

```bash
flutter build ios --release --dart-define-from-file=.env.json --dart-define=APP_VARIANT=main
```

## Variant Notes

- `APP_VARIANT=main` = standard / main application
- `APP_VARIANT=rack_console` = rack console application
- If `APP_VARIANT` is not provided, the app defaults to `main`

This behavior comes from [`lib/core/config/app_config.dart`](</Users/marketingdeveloper/DCStack/Smart Monitoring/Smart_MonitoringDash/lib/core/config/app_config.dart>).

## Config Notes

- `.env.json` is used for runtime Dart defines
- `CPANEL_BASE_URL` defaults to `https://dcstack.my/api/index.php`
- `CPANEL_ASSET_BASE_URL` defaults to `https://dcstack.my/`
- `ADAPTER_BASE_URL` is optional
- Recommended production domain split:
  - `https://www.dcstack.my` = landing page
  - `https://dcstack.my` = Smart Monitoring app
  - `https://adapter.dcstack.my` = adapter API
- For Flutter Web, the browser origin must be included in the adapter's `CORS_ALLOWED_ORIGINS` value or the dashboard/API reads will fail and the app may appear offline.

## Current App Version

The current Flutter app version in [`pubspec.yaml`](</Users/marketingdeveloper/DCStack/Smart Monitoring/Smart_MonitoringDash/pubspec.yaml>) is:

- `1.0.1+8`
