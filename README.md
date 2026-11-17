# DCS Smart Rack Dashboard

Flutter application for the DCS Smart Monitoring mobile/desktop/web app and the DCS Rack Console.

## Quick Setup (`.env.json`)

Create `.env.json` in `Smart_MonitoringDash/` (gitignored via `.env.*`):

```json
{
  "APP_VARIANT": "main",
  "CPANEL_BASE_URL": "https://portal.dcstack.my/api/index.php",
  "CPANEL_ASSET_BASE_URL": "https://portal.dcstack.my/",
  "ADAPTER_BASE_URL": "https://adapter.dcstack.my"
}
```

Then install dependencies:

```bash
flutter pub get
```

## Run The Standard / Main App

```bash
flutter run --dart-define-from-file=.env.json --dart-define=APP_VARIANT=main
```

(`APP_VARIANT` defaults to `main` if omitted.)

## Run The Rack Console App

```bash
flutter run --dart-define-from-file=.env.json --dart-define=APP_VARIANT=rack_console
```

- **Auth requirement:** Live login to `rack_console` requires a portal account whose site has `is_kiosk = 1` (standard user accounts are restricted to `main`, and kiosk accounts are restricted to `rack_console`).
- **Demo / UI preview (no login required):**
  ```bash
  flutter run -d chrome --dart-define-from-file=.env.json --dart-define=APP_VARIANT=rack_console --dart-define=DEMO_MODE=true
  ```

## Platform Examples

### macOS Desktop (no browser CORS)
```bash
flutter run -d macos --dart-define-from-file=.env.json --dart-define=APP_VARIANT=main
```

### Chrome (Flutter Web)
Use a fixed port (`5050`) so the browser origin matches `CORS_ALLOWED_ORIGINS` on the adapter:
```bash
flutter run -d chrome --web-port=5050 --dart-define-from-file=.env.json --dart-define=APP_VARIANT=main
```
> **CORS note:** If Chrome shows dashboard cards as `Offline`, `http://localhost:5050` is missing from `CORS_ALLOWED_ORIGINS` on the target adapter (`https://adapter.dcstack.my` or local `http://localhost:3000`).

### Connected iPhone
1. Connect the iPhone by USB and unlock it.
2. Tap `Trust This Computer` on the iPhone if prompted.
3. Enable Developer Mode on the iPhone.
4. Run:
   ```bash
   flutter devices
   flutter run -d <iphone-device-id> --dart-define-from-file=.env.json --dart-define=APP_VARIANT=main
   ```

### Connected Android Device
```bash
flutter run -d android --flavor standard --dart-define-from-file=.env.json --dart-define=APP_VARIANT=main
```

## Build Examples

### Android APK (Standard / Main)
```bash
flutter clean
flutter pub get
flutter build apk --release --flavor standard --dart-define-from-file=.env.json --dart-define=APP_VARIANT=main
```

### Android APK (Rack Console)
```bash
flutter clean
flutter pub get
flutter build apk --release --flavor rackconsole --dart-define-from-file=.env.json --dart-define=APP_VARIANT=rack_console
```

### iOS IPA (Standard / Main)
```bash
flutter clean
flutter pub get
flutter build ipa --release --build-number=11 --dart-define-from-file=.env.json --dart-define=APP_VARIANT=main --dart-define=ADAPTER_BASE_URL=https://adapter.dcstack.my
```

## Config Notes

- Config keys are defined in [app_config.dart](lib/core/config/app_config.dart).
- `CPANEL_BASE_URL` defaults to `https://portal.dcstack.my/api/index.php` (do **not** use `https://dcstack.my/api/index.php`, which serves the web app HTML without API CORS headers).
- `CPANEL_ASSET_BASE_URL` defaults to `https://portal.dcstack.my/`.
- `ADAPTER_BASE_URL` points to `https://adapter.dcstack.my` in production (or `http://localhost:3000` for a local Node adapter).
- Production domain split:
  - `https://www.dcstack.my` = landing page
  - `https://dcstack.my` = Smart Monitoring web app
  - `https://portal.dcstack.my` = cPanel PHP API & assets
  - `https://adapter.dcstack.my` = adapter API

## Current Release State

- Flutter source version in [pubspec.yaml](pubspec.yaml): `1.0.1+8`
- Latest iOS TestFlight upload: `1.0.1 (11)` (`Runner` scheme)
- Android standard/main release output: `build/app/outputs/flutter-apk/app-standard-release.apk`
