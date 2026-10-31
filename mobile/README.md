# RunFuel Android app

Flutter-based personal RunFuel client for Android.

## Current foundation milestone

- Five-tab app shell: Today, Training, Fuel, Coach, Progress.
- Local SQLite database created on device for activities, nutrition days, coaching reviews, and sync state.
- Backend URL saved locally.
- HTTPS backend health check against `/health`.
- Guided setup links to the canonical public repository, Vercel import, Upstash, and the deployment's `/settings` Token Manager.
- No service secrets or OpenAI API keys are collected or embedded in the APK.

## Important current limitations

This is the app foundation, not yet the connected release. Garmin/MFP sync, authenticated mobile API endpoints, OpenAI coaching, token-expiry detection, and Vercel administration are not implemented in this milestone. The app deliberately shows empty states rather than inventing data or reporting fake connections. The backend health check only verifies that `/health` responds; it does not prove Garmin or MyFitnessPal authentication works.

## Build

The GitHub Actions workflow builds an ARM64 release APK from this folder. It generates the standard Android platform scaffold during CI, then builds the Flutter app:

```bash
flutter create --platforms=android --project-name=runfuel --org=com.runfuel .
flutter pub get
flutter build apk --release --target-platform android-arm64
```

The APK is intended for a Samsung S22 (ARM64). The CI artifact is a test build; a private release signing key and update strategy should be configured before distributing a long-lived release.

## Canonical backend source

New self-hosted deployments must start from [minitombo/runfuel-mcp-public](https://github.com/minitombo/runfuel-mcp-public). Never silently point a new installation at somebody else's Vercel project, Redis database, or upstream credentials.
