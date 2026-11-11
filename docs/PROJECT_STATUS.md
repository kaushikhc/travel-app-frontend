# Project status: Flutter client

Last updated: 2026-11-11

## Where things stand
- Scaffold with feature folders: auth, profile, trip, memories, capture, explore, navigation (about 3.7k lines).
- Wired to the API: email login and register, `/auth/check`, `/auth/logout`, `GET|PUT /profile/me`.
- Mock data only: trips, memories, capture, explore.
- Tests: one smoke widget test.

## Known gaps against backend v1
1. Google login reads `?token=&username=` from the redirect. Backend now sends `#/?code=...`, which must be exchanged with `POST /api/auth/exchange` within 60 seconds.
2. The JWT is held in memory only, so a refresh or app restart signs the user out. The signed-in user is a placeholder (`id: '1'`).
3. Router `redirect` has side effects (sets the token, starts profile loads), which caused past login routing loops.
4. Profile has no `timeZone`; there is no UTC-to-local display helper.
5. `TripModel` statuses (PLANNED/ONGOING/COMPLETED) differ from the backend (DRAFT/UPCOMING/ACTIVE/ARCHIVED).
6. Country list is hardcoded with made-up ids.
7. No v1 features yet: trips, memories, wishlist, collections, community, statistics, timeline.

## Plan (one PR each)
1. Backend PR in travel-app: `POST /api/auth/google` that verifies a Google ID token and returns the app JWT (for native Android sign-in).
2. Auth rework: explicit auth state machine, side-effect-free router with a dedicated web callback route, token in `flutter_secure_storage`, native Google sign-in on Android, code exchange on web, real user from `/profile/me`, redirect tests.
3. Profile `timeZone` (send device zone once), UTC-to-local helper, countries from the API.
4. Real data, one screen at a time: Trips, Memories/Capture, Explore/Wishlist, Community.

## Open items for Sam
- Android OAuth client in Google Cloud (package `com.travelapp.travel_app_frontend` + debug SHA-1).
- iOS on hold; Apple sign-in to be decided when iOS resumes.

## How to run
```
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<host>/api
flutter analyze && flutter test
```
