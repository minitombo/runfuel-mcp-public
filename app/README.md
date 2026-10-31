# RunFuel Android app

Flutter Android client foundation for the public RunFuel project.

## Current status

This is the first UI foundation, not a connected production app yet.

Implemented:
- Six-tab dark dashboard shell: Home, Training, Coach, Nutrition, Health, Settings.
- Manual-sync-first UX (sync intentionally reports that the backend adapter is not connected).
- Backend base-URL setting saved locally.
- Token-manager deep link derived from the user's own backend URL.
- Local file/photo selection UI for health records. Files are **not uploaded** in this foundation.
- No credentials, API keys, cookies or maintainer deployment URLs are embedded.

Not yet implemented:
- Authenticated mobile API endpoints and app pairing.
- Garmin and MyFitnessPal sync.
- OpenAI Responses API proxy and tool-calling.
- Encrypted local health-record vault and secure upload.
- Real token-expiry checks and notifications.
- Vercel/GitHub provisioning wizard.
- Production data persistence and tests.

## Build locally

Install the Flutter stable SDK and Android toolchain, then:

```bash
cd app
flutter pub get
flutter run
flutter build apk --release
```

The GitHub Actions workflow at `.github/workflows/android-apk.yml` builds an APK artifact from this source using a generated Android platform scaffold.

## Privacy

Do not add secrets to this repository or the APK. Health documents selected in this foundation remain local and are not sent to any server or AI provider.
