# Project status: Flutter client

Last updated: 2026-11-11 (choose a username after the first Google sign-in)

## Where things stand
- Scaffold with feature folders: auth, profile, trip, memories, capture, explore, navigation.
- Profile sends the device IANA time zone (`flutter_timezone`) whenever it differs from the server's; countries come from `GET /api/places/countries` (`CountryPicker`, searchable).
- Profile photo: picking a photo uploads it straight away through the media API (`MediaRepository.uploadPhoto`: `POST /api/media/uploads`, PUT the bytes to the signed URL with a plain Dio, `POST /api/media/{id}/complete`), and saving sends `photoMediaId` (needs backend kaushikhc/travel-app#37). The profile's `photoUrl` is the signed link to show. Never send base64 in `photoUrl`; the backend rejects it.
- Birthday: `BirthdayPicker` (day, month, year dropdowns; no impossible or future dates), sent as `yyyy-MM-dd` (`ApiDate`). There is no Age input: the server works out `age` from the birthday. Birthday is only returned by `GET /profile/me`, so other travelers never see it.
- First Google sign-in: when `/profile/me` says `usernameChosen: false`, the router sends the traveler to `ChooseUsernameView` (before profile setup). They pick a username and an optional password, or skip to keep the Google email. `AuthNotifier.chooseUsername` swaps in the new token the server returns (needs backend kaushikhc/travel-app#39).
- Wired to the API: email login and register, Google sign-in (native on Android via `POST /api/auth/google`, redirect plus `POST /api/auth/exchange` on web), `/auth/check`, `/auth/logout`, `GET|PUT /profile/me`.
- Home tab (`TripsView`) on real data: `GET /api/trips/home` (current trip with day progress, upcoming, drafts) and `GET /api/statistics/me` (countries, trips, memories), with loading, empty and error states. `TripModel` uses the backend statuses (DRAFT/UPCOMING/ACTIVE/ARCHIVED).
- Mock data only: memories, capture, explore. Trip covers: `TripResponse` carries only `coverMediaId` (Sam's call); the app fetches the signed link with `GET /api/media/{id}` (`mediaUrlProvider`), lazily per card, reused for 50 minutes because links expire after the backend's 1-hour download TTL. Add a batch endpoint only if a screen ever shows many covers.
- Tests: 41 (choose username, photo upload, birthday picker and dates, media link caching, router redirect rules, auth notifier, time parsing, countries, time zone sync, trip model, Home view, smoke test). `flutter analyze` clean; `flutter build web` OK. Android build not yet verified on a device.

## Auth design (PR "Auth rework")
- `AuthNotifier` (`features/auth/presentation/auth_state.dart`) owns the session: states checking, unauthenticated, loading, authenticated, error. At start it restores the token from `TokenStorage` (`core/storage`, flutter_secure_storage) and checks it with `/auth/check`: rejected tokens are dropped, an unreachable server keeps the session.
- `ProfileNotifier` rebuilds on sign-in and sign-out and loads `/profile/me` itself.
- The router's redirect is `authRedirect` (`core/router/auth_redirect.dart`), a pure function of auth state, profile state and URL. It never changes state, which is what broke routing before.
- Web Google callback: `/#/?code=...` renders `GoogleCallbackView`, which exchanges the code; a race with session restore is handled (the newer sign-in wins).
- Android Google: `NativeGoogleSignInGateway` (google_sign_in 7) needs `--dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>`, plus an Android OAuth client in Google Cloud for the package name and signing SHA-1.

## Known gaps against backend v1
1. Done in the auth rework: code exchange, persisted token, real user, side-effect-free router.
2. No global 401 handling yet: if a token expires mid-session, calls fail until the next start. Add a dio interceptor that signs out on 401.
3. No v1 features yet beyond Home: trip detail and create/edit, memories, wishlist, collections, community, statistics, timeline.

## Plan (one PR each)
1. Done: backend `POST /api/auth/google` (kaushikhc/travel-app#35, merged).
2. Done: auth rework (#1): explicit auth state machine, side-effect-free router with a dedicated web callback route, token in `flutter_secure_storage`, native Google sign-in on Android, code exchange on web, real user from `/profile/me`, redirect tests.
3. Done: profile `timeZone` sync, `ApiTime` UTC helpers, countries from the API.
4. Real data, one screen at a time: Home done; next trip detail and create/edit, then Memories/Capture, Explore/Wishlist, Community.

## Branching
Until the MVP is ready, PRs go to `main`. After that, all development goes to `develop` only (Sam, 2026-11-11).

## Open items for Sam
- Android OAuth client in Google Cloud (package `com.travelapp.travel_app_frontend` + debug SHA-1).
- iOS on hold; Apple sign-in to be decided when iOS resumes.

## How to run
- Backend CORS allows only the `Authorization`, `Content-Type` and `Accept` headers. Don't add other default headers for non-ngrok hosts, or browser calls fail as "could not reach the server".
- Photo uploads in dev go to the local S3 server from the backend's `docker compose up -d` (localhost:9090). The signed upload URL points at localhost, so uploads work from the PC only, not from another device over ngrok. For the deployed web build, the R2 bucket needs a CORS rule for the app's origin.
- PC, Chrome: `flutter run -d chrome --web-port 8080` (port 8080 is where the backend sends Google sign-in back; on localhost the app calls `http://localhost/api`).
- Android emulator: `--dart-define=API_BASE_URL=http://10.0.2.2/api` (10.0.2.2 is the PC). Debug builds allow plain http for this; release builds need https.

```
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<host>/api --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>
flutter analyze && flutter test
```
