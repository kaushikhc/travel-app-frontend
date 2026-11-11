# travel_app_frontend

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Environments (dev / qa / prod)

The backend base URL is chosen at build time with `--dart-define-from-file`. One file per
environment lives in `env/` (public values only, **never put secrets there**):

| Env  | File            | Backend                                   |
|------|-----------------|-------------------------------------------|
| dev  | `env/dev.json`  | `http://localhost/api` (port 80)          |
| qa   | `env/qa.json`   | ngrok URL (edit the file if it changes)   |
| prod | `env/prod.json` | placeholder, to be decided                |

```bash
# dev: web or emulator (use http://10.0.2.2/api for the Android emulator)
flutter run -d chrome --web-port 8080 --dart-define-from-file=env/dev.json

# qa: installable APK that talks to the ngrok backend
flutter build apk --dart-define-from-file=env/qa.json

# prod: once env/prod.json has the real URL
flutter build apk --release --dart-define-from-file=env/prod.json
```

Add `--dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>` for native Android Google sign-in.
A single value can be overridden with `--dart-define=API_BASE_URL=...` passed after the file.
In the browser, a page served from `localhost` or an ngrok host still uses that host automatically.
