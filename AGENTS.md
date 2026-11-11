# AGENTS.md

Entry point for any AI agent or developer working on this repo. Read this, then `docs/PROJECT_STATUS.md`.

## What this is
The Flutter client for the Travel App. The backend lives in
[kaushikhc/travel-app](https://github.com/kaushikhc/travel-app) (branch `develop`). The API contract the
app must follow is `docs/v1_api_changes.md` in that repo; the product backbone and decisions log are
in its `docs/` folder too.

## Targets
- Android: primary.
- Web: minimal build for backend testing and big-screen viewing.
- iOS: on hold (no Apple sign-in, no iOS OAuth client yet). Keep platform-specific code isolated so it can be added later.

## Conventions
- Clean Architecture per feature: `lib/features/<feature>/{data,domain,presentation}`; shared code in `lib/core`.
- State: Riverpod (`flutter_riverpod` 3, `Notifier`). Routing: `go_router`. HTTP: `dio` via `lib/core/network/api_client.dart`.
- Strict null safety, immutable models, explicit types.
- The router's `redirect` must only read state, never change it. Side effects belong in notifiers.
- The API returns UTC timestamps, often without an offset. Parse them with `ApiTime.parseUtc` (`lib/core/time/api_time.dart`), never `DateTime.parse`, and format with the `ApiTime.format*` helpers, which convert to the device zone.
- Never commit secrets. The API base URL comes from `--dart-define=API_BASE_URL=...`.

## Working rules
- Write code only when the product owner (Sam) has authorized the change.
- Keep `docs/PROJECT_STATUS.md` out of feature PRs (Sam, 2026-11-11: it caused merge conflicts). Put status updates in their own small PR, cut fresh from the base branch, and check the doc against what is actually merged first.
- Cut each PR fresh from `main`; never stack PRs on other PR branches.
- **Once the MVP is ready (Sam's rule, 2026-11-11), all development goes to a `develop` branch only**: cut PRs from `develop` and target `develop`, like the backend. `main` then only receives merges from `develop`.
- Before pushing: `flutter analyze` and `flutter test` pass.
