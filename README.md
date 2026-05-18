# Smart Rack Dashboard

Flutter dashboard app for monitoring and managing the Dahua eCTRL-IS Smart Rack (PUE/temperature trends, device health).

## Quick Start

```bash
flutter pub get
flutter run
```

## Backend URL (Portal API)

By default the app talks to the production portal:

- `https://dcstack.my/api/index.php` (API)
- `https://dcstack.my/` (assets)

Override at build/run time using `--dart-define`:

```bash
flutter run \
  --dart-define=CPANEL_BASE_URL="https://YOUR_DOMAIN/api/index.php" \
  --dart-define=CPANEL_ASSET_BASE_URL="https://YOUR_DOMAIN/"
```

PowerShell:

```powershell
flutter run `
  --dart-define=CPANEL_BASE_URL="https://YOUR_DOMAIN/api/index.php" `
  --dart-define=CPANEL_ASSET_BASE_URL="https://YOUR_DOMAIN/"
```

## Build

```bash
flutter build apk --release
flutter build appbundle --release
```



