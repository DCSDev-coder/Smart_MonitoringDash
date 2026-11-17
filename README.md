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

## Architecture & Recent Features

### 1. Backup Recovery Email & 6-Digit Email OTP Verification
- **Email Registration:** Users register their own personal backup recovery email in **Settings > Recovery Email** (or via first-login reminder dialog).
- **Cryptographic OTP Codes:** Critical actions require requesting a 6-digit email verification code:
  - **Reset Password** (from login via `Forgot Password` or in-app Settings)
  - **Change Username** (directly from profile pencil icon in Settings)
  - **Set Door PIN** (in-app Door Access PIN configuration)
- **Manual Request Workflow:** Codes are dispatched only when the user explicitly clicks **Request Code**, avoiding unintentional email delivery. Codes expire after 15 minutes (`DATE_ADD(NOW(), INTERVAL 15 MINUTE)`).

### 2. Credential Separation & Web Monitoring Access Gating
- **Dahua Hardware Isolation:** Dahua controller hardware credentials (`site_user`, `site_pass`) are kept strictly separated from portal user logins (`users` table). Hardware passwords are never exposed in user interface cards.
- **Monitoring Web Gating (`can_access_monitoring_web`):** The React/Vite web monitoring interface (`monitoring_dashboard`) is restricted to the primary DCS HQ company (`MONITORING_WEB_COMPANY_SITE_ID`, site `1`). Non-DCS users are blocked with `403 Forbidden`. DCS administrators can selectively toggle web access for individual team members in **Manage Users**.

### 3. Dynamic Telemetry & 90-Day Maintenance Automation
- **Multi-Sensor Door Environment:** Automatically discovers and pairs multiple door contacts (2, 4, or more) matching `temp-hum-top-n` telemetry rather than assuming a single front/rear pair.
- **Dynamic PUE:** Calculates real-time Power Usage Effectiveness directly from active hardware draw, removing obsolete manual sliders and simulator inputs.
- **90-Day Servicing Cycle:** Computes next required maintenance as exactly `+90 days` from `sites.last_maintenance` and synchronizes service updates back to cPanel via `action=update_maintenance`.

### 4. UI Polish & Native Safety
- **Unboxed Logo Display:** Settings overlay renders company logos without rigid square bounding boxes (`220x110` max container, `BoxFit.contain`), preserving clean visual aspect ratios.
- **Deferred Controller Disposal:** All modal and dialog `TextEditingController` instances defer disposal until dialog dismissal animations complete, preventing `TextEditingController was used after being disposed` crashes.
- **Responsive Layouts:** PUE trend chips and metric tags utilize `Wrap` layouts to prevent `RenderFlex` overflow errors on compact phone viewports.

## Current Release State

- Flutter source version in [pubspec.yaml](pubspec.yaml): `1.0.1+8`
- Latest iOS TestFlight upload: `1.0.1 (11)` (`Runner` scheme)
- Android standard/main release output: `build/app/outputs/flutter-apk/app-standard-release.apk`
