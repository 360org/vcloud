# AGENTS.md — orientation for AI agents & developers

Onboarding for anyone (human or agent) working on VCloud. Read this first.

## What this is
VCloud — employee productivity app (Flutter + Supabase): chat · attendance ·
timesheet · tickets · dashboard. Vietnamese UI, premium mobile design.
See [docs/PRD.md](docs/PRD.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md),
[docs/PLAN.md](docs/PLAN.md).

## Golden rules
1. **Presentation never touches Supabase.** Go through `features/<f>/data/*_repository.dart`.
2. **Keep `flutter analyze` at 0 errors / 0 warnings** before committing.
3. **Secrets via `--dart-define`**, never hard-code in committed files (the existing
   default in `env.dart` is a known M2 cleanup item — don't add more).
4. **DB changes = a new `supabase/migrations/NNNN_*.sql`**, never ad-hoc SQL.
5. Match the surrounding code's style, comment density, and naming.

## Layout
```
lib/
  core/        env · supabase client · theme (design tokens) · router · utils · error
  shared/      models · widgets (app_scaffold, ui_kit, empty/error/loading)
  features/<f>/{data, application, presentation}
supabase/migrations/   schema + RLS (source of truth)
docs/            PRD · ARCHITECTURE · PLAN · MOBILE_UX_OPTIONS
```

## Architecture & data flow

Three-layer, feature-first architecture:

```
presentation (screens/widgets)
    │ watches providers, dispatches actions
    ▼
application (Riverpod providers/controllers)
    │ calls repository methods, invalidates providers
    ▼
data (*_repository.dart)
    │ wraps Supabase.instance.client
    ▼
Supabase (auth · Postgres · Realtime · RLS)
```

**Key patterns observed in code:**

- **Repository facade**: every `data/*_repository.dart` takes an optional
  `SupabaseClient? client` (defaults to `Supabase.instance.client`) — this
  enables testing/swapping.
- **Realtime = snapshot + refetch**: streams fetch once, subscribe to
  `postgres_changes`, and re-fetch on any change. Channel names are unique
  per user/resource (e.g. `tickets-${userId}`, `msg-$conversationId`).
  Cleanup via `_client.removeChannel(channel)` in `onCancel`.
- **Optimistic updates**: tickets use a `*OverrideProvider` pattern — patch
  the local list immediately, fire the API, roll back on failure.
- **Failure type**: `core/error/failure.dart` — lightweight `Failure(message)`
  thrown from repositories, caught in controllers/screens. Use
  `describeError(e)` to extract the message.

## State management (Riverpod)

- `AsyncNotifierProvider` for auth source of truth (`authControllerProvider`).
- `StreamProvider.autoDispose` for live lists (conversations, tickets, etc.).
- Plain `Provider` for derived view-models (`homeSummaryProvider`, `openTicketsCountProvider`).
- Actions are thin `Provider`-exposed classes (`*ActionsProvider`) that call the repo
  then `ref.invalidate(...)`.
- Private providers prefixed with `_` (e.g. `_authRepoProvider`).

## Routing (GoRouter)

- Single `routerProvider` in `core/router/app_router.dart`.
- Redirect guard reads `authControllerProvider`:
  - loading → `/splash`; signed-out → `/login`; signed-in on auth/splash → `/home`.
- `_AuthListenable` bridges the async auth provider into GoRouter's `refreshListenable`.
- Tab shell in `AppScaffold` — maps current location to one of
  `Home · Chat · Timesheet · Ticket · Tôi`; hides the bar on detail/auth routes.
- Platform-adaptive page transitions: Cupertino slide on iOS, Zoom on Android.

## Design system ("Refined Tech Luxury")

All design tokens live in `core/theme/app_theme.dart`. The visual language uses
**midnight gradients**, **glassmorphism**, and **per-feature accent gradients**.

- **Palette** (`AppColors`): midnight base (`#0F1629`, `#1A2340`), glass tints
  (`surfaceGlass`, `textMuted`), per-feature gradient pairs (`primaryGrad`,
  `attendanceGrad`, `timesheetGrad`, `ticketGrad`, `chatGrad`, `successGrad`,
  `dangerGrad`).
- **Text** (`AppTextStyles`): `headline`, `title`, `body`, `caption`, `muted`
  with consistent sizes/weights on white-on-dark backgrounds.
- **Surfaces**: `glassDecoration()` / `GlassCard` — semi-transparent containers
  with subtle border and blur. `GradientHeader` for section headers.
- **Widgets** (`shared/widgets/ui_kit.dart`): `GlassCard`, `GradientHeader`,
  `GradientBadge`, `StatTile`, `PressableScale`, `GradientButton`, `AnimatedCount`.
- **Shared widgets** (`shared/widgets/`): `AppScaffold` (gradient AppBar, glass
  bottom nav with gradient pill on selected tab), `EmptyState`, `ErrorView`,
  `LoadingView` — all use glass containers and gradient accents.
- **Animations** (`flutter_animate`): staggered `fadeIn + slideY` on Home,
  `fadeIn` with delays on Attendance/Profile. Preserved existing breathing pulse
  on check-in circle.
- **Pattern**: when adding new screens, use `GlassCard` for content containers,
  `GradientBadge` for status pills, gradient pairs from `AppColors` for accents.
  Avoid opaque white backgrounds — use glass tints instead.

## Models & enums

- Models are immutable classes with `const` constructors and `fromMap` factories
  mapping **snake_case** Postgres columns to **camelCase** Dart fields.
- Postgres enums (`TicketStatus`, `TimesheetCategory`, `TimesheetDuration`)
  are Dart enums with a `*Db` extension providing `dbValue` (PascalCase string
  matching Postgres), `label`, and `static fromDb(String)`.
- Models live in `lib/shared/models/` — shared across features.

## Linter rules (analysis_options.yaml)

Based on `flutter_lints` plus:
- `prefer_const_constructors: true`
- `prefer_const_constructors_in_immutables: true`
- `prefer_const_declarations: true`
- `prefer_final_locals: true`
- `always_declare_return_types: true`
- `require_trailing_commas: true`

**Always use `const` constructors and trailing commas** — the linter enforces this.

## Design system

- Tokens in `lib/core/theme/app_theme.dart` (`AppColors`, `cardDecoration`,
  gradients, `glow` helper).
- Brand: vivid blue→indigo gradient (`AppColors.brand`); per-feature accent colors.
- Use `cardDecoration()` for all card containers — don't invent new decorations.
- `AppColors.soft(color)` for tinted backgrounds, `AppColors.glow(color)` for shadows.
- Motion/UX kit in `lib/shared/widgets/ui_kit.dart`: `PressableScale` (tap-scale +
  haptics), `GradientButton`, `AnimatedCount`.
- Entrance animations via `flutter_animate` (`.animate().fadeIn().slideY()`).
- Icons: `lucide_flutter` (modern line set) — not Material icons in new code.

## UI conventions

- All screens use `AppScaffold` for consistent app bar + bottom nav.
- Vietnamese UI text throughout (not English).
- Shared widgets: `EmptyState`, `ErrorView`, `LoadingView` — use them instead of
  ad-hoc placeholders.
- `UserAvatar` in `app_scaffold.dart` for user initials/avatar circles.
- `Dates` utility in `core/utils/date_format.dart` for all date formatting.

## Commands

### Analyze / test (host, if Flutter installed)
```bash
flutter pub get
flutter analyze
flutter test
```

### No local Flutter? Use Docker (this repo's standard)
> Public Flutter images ship Dart 3.12.0 but the project targets ^3.12.2. Builds
> relax the SDK floor **inside the container only** — host pubspec stays intact.

**Run web (no toolchain needed):**
```bash
docker compose -f docker-compose.web.yml up --build   # → http://localhost:8080
```

**Analyze in Docker:**
```bash
docker run --rm -v "$PWD":/src:ro ghcr.io/cirruslabs/flutter:stable bash -c '
  cp -r /src /app && cd /app && rm -rf build .dart_tool pubspec.lock
  sed -i "s/\^3\.12\.2/'"'"'>=3.12.0 <4.0.0'"'"'/" pubspec.yaml
  flutter pub get >/dev/null && flutter analyze lib'
```

### Build Android APK
Release, debug-signed, arm64 → `dist/vcloud.apk`. The Docker VM must fit Gradle's
heap (the template sets `-Xmx8G`; lower it for an 8 GB VM or the daemon is OOM-killed):
```bash
docker run --rm -v "$PWD":/src:ro -v "$PWD/dist":/out ghcr.io/cirruslabs/flutter:stable bash -c '
  set -e; cp -r /src /app && cd /app && rm -rf build .dart_tool pubspec.lock
  sed -i "s/\^3\.12\.2/'"'"'>=3.12.0 <4.0.0'"'"'/" pubspec.yaml
  sed -i "s|^org.gradle.jvmargs=.*|org.gradle.jvmargs=-Xmx3G -XX:MaxMetaspaceSize=512m|" android/gradle.properties
  flutter pub get >/dev/null
  flutter build apk --release --target-platform android-arm64
  mkdir -p /out && cp build/app/outputs/flutter-apk/app-release.apk /out/vcloud.apk'
```

## Testing

- `test/widget_test.dart` is a minimal smoke test (no Supabase dependency).
- Full app tests require `Supabase.initialize` — use integration tests or mock the client.
- Repository constructors accept optional `SupabaseClient?` for testability.
- No CI pipeline yet (planned in M2).

## Gotchas
- **`flutter build web` feels web-like** — that's the web target, not the framework.
  Real native feel = `flutter run` on a device / the APK above. See docs/MOBILE_UX_OPTIONS.md.
- **Service worker caches the web bundle** — after a rebuild, unregister SW + clear
  caches (or hard-reload) or you'll see the old bundle.
- **RLS recursion (42P17)** was fixed via a `SECURITY DEFINER` helper in migration 0002 —
  don't reintroduce self-referencing policies on `conversation_members`.
- **Tickets are self-assigned only** (code + RLS) — cross-user assignment is M4.
- **`passkeys_bundle.js` in `web/`** must load synchronously before the Flutter engine
  — the transitive `passkeys` package requires `window.PasskeyAuthenticator` at boot.
- **`web/index.html` script tag** — the `<script src="flutter_bootstrap.js" async>`
  opening tag must be properly closed (`</script>`); a missing `">"` swallows the
  bootstrap and the app shows only the blue background.
- **Dart SDK gap** — project targets `^3.12.2` but Docker images ship `3.12.0`.
  Docker builds use `sed` to relax this inside the container only; never change the
  host `pubspec.yaml` SDK constraint.
- **Attendance model** — `latitude`/`longitude` columns map to `checkoutLat`/`checkoutLng`
  in the Dart model (the schema reuses those columns for checkout location).
- **Dark theme** — `buildDarkTheme()` currently returns `buildLightTheme()` (design
  spec is light-only). Don't assume dark mode works.

## Backend setup (Supabase)
1. Run `supabase/migrations/0001_init.sql` then `0002_fix_conversation_members_recursion.sql`.
2. Auth → Providers → Email: disable "Confirm email" (MVP only).
3. Auth → URL config: add `vcloud://login-callback`.

## Adding a new feature
1. Create `lib/features/<name>/{data, application, presentation}/`.
2. Add a model in `lib/shared/models/` with `fromMap` factory (snake_case → camelCase).
3. Add a repository in `data/` — constructor takes `SupabaseClient?`, wraps queries.
4. Add providers in `application/` — `StreamProvider.autoDispose` for lists, actions class.
5. Add screens in `presentation/` — extend `ConsumerWidget`, use `AppScaffold`.
6. Add routes in `core/router/app_router.dart`.
7. Add a DB migration if schema changes are needed.
