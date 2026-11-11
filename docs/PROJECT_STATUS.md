# Project status: Flutter client

Last updated: 2026-11-11 (Home tab on real data)

## Where things stand
- Scaffold with feature folders: auth, profile, trip, memories, capture, explore, navigation.
- Profile sends the device IANA time zone (`flutter_timezone`) whenever it differs from the server's; countries come from `GET /api/places/countries` (`CountryPicker`, searchable).
- Wired to the API: email login and register, Google sign-in (native on Android via `POST /api/auth/google`, redirect plus `POST /api/auth/exchange` on web), `/auth/check`, `/auth/logout`, `GET|PUT /profile/me`.
- Home tab (`TripsView`) on real data: `GET /api/trips/home` (current trip with day progress, upcoming, drafts) and `GET /api/statistics/me` (countries, trips, memories), with loading, empty and error states. `TripModel` uses the backend statuses (DRAFT/UPCOMING/ACTIVE/ARCHIVED).
- Mock data only: memories, capture, explore. Trip cover images are not shown yet (only `coverMediaId` comes back; needs a media URL lookup).
- Tests: 29 (router redirect rules, auth notifier, time parsing, countries, time zone sync, trip model, Home view, smoke test). `flutter analyze` clean; `flutter build web` OK. Android build not yet verified on a device.

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
```
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<host>/api --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>
flutter analyze && flutter test
```
