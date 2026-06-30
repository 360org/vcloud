# VCloud — Architecture

> Technical reference for the VCloud Flutter app. Pairs with [PRD.md](PRD.md)
> (what & why) and [PLAN.md](PLAN.md) (when).

## 1. High-level

```
┌──────────────────────────── Flutter app (iOS · Android · Web) ────────────────────────────┐
│  presentation  ──watch──▶  application (Riverpod)  ──calls──▶  data (repositories)         │
│   (screens/widgets)          (controllers/providers)            (Supabase client facade)    │
└───────────────────────────────────────────────┬───────────────────────────────────────────┘
                                                 │ JSON / Realtime / Auth
                                   ┌─────────────▼──────────────┐
                                   │  Supabase                  │
                                   │  auth · Postgres · Realtime│
                                   │  Row-Level Security (RLS)  │
                                   └────────────────────────────┘
```

The backend is **swappable** — see [§7 Odoo integration](#7-odoo-integration-plan).

## 2. Layered, feature-first structure

Each feature owns three layers; nothing in `presentation` talks to Supabase directly.

```
lib/
  core/        config (env, supabase client) · theme · router · utils · error
  shared/      models · widgets (app_scaffold, ui_kit, empty/error/loading)
  features/<feature>/
    data/          repository — the only layer that touches Supabase
    application/   Riverpod providers/controllers — state + use-cases
    presentation/  screens & widgets — watch providers, render, dispatch actions
```

Features: `auth · chat · attendance · timesheet · ticket · home · profile`.

## 3. State management — Riverpod

- `AsyncNotifierProvider` for the auth source of truth (`authControllerProvider`).
- `StreamProvider.autoDispose` for live lists (conversations, tickets, timesheets, attendance).
- Plain `Provider` for derived view-models (`homeSummaryProvider`, `openTicketsCountProvider`).
- Actions are thin `Provider`-exposed classes (`*ActionsProvider`) that call the repo then `ref.invalidate(...)`.

## 4. Routing — GoRouter

- Single `routerProvider`; redirect guard reads `authControllerProvider`:
  - loading → `/splash`; signed-out → `/login`; signed-in on auth/splash → `/home`.
- `_AuthListenable` bridges the async auth provider into GoRouter's `refreshListenable`.
- Tab shell lives in `AppScaffold`, which maps the current location to one of
  `Home · Chat · Timesheet · Ticket · Tôi` and hides the bar on detail/auth routes.
- Platform-adaptive page transitions (Cupertino slide on iOS, Zoom on Android).

## 5. Data & realtime patterns

- **Repository facade**: every feature's `data/*_repository.dart` wraps `Supabase.instance.client`.
- **Realtime = snapshot + refetch**: each stream fetches once, subscribes to
  `postgres_changes`, and re-fetches on any change. Simple and correct; a known
  scaling cost (see PRD P1 — N+1 in conversation summaries).
- **Models** are immutable, with `fromMap` factories mapping snake_case rows.

## 6. Security — Row-Level Security

- RLS is the security boundary, **not** the anon key (which is publishable).
- Per-table policies restrict rows to the owner / conversation members.
- `am_conversation_member()` is a `SECURITY DEFINER` helper that breaks the
  policy-recursion (Postgres 42P17) fixed in `supabase/migrations/0002_*`.
- Migrations are the source of truth: `supabase/migrations/000{1,2}_*.sql`.

## 7. Design system

- Tokens in `lib/core/theme/app_theme.dart` (`AppColors`, `cardDecoration`, gradients, `glow`).
- Brand: vivid blue→indigo gradient; vivid per-feature accents; layered soft shadows.
- Motion/UX kit in `lib/shared/widgets/ui_kit.dart`: `PressableScale` (tap-scale +
  haptics), `GradientButton`, `AnimatedCount`. Entrance animations via `flutter_animate`.
- Icons: `lucide_flutter` (modern line set).

## 8. Build & deploy

| Target | Command | Notes |
|---|---|---|
| Web (Docker) | `docker compose -f docker-compose.web.yml up --build` → `:8080` | nginx serves `build/web`; no host toolchain needed |
| Android APK (Docker) | see [AGENTS.md](../AGENTS.md#build-android-apk) | release, debug-signed, arm64 |
| Native dev | `flutter run --dart-define=...` | real device = real feel |

> **Toolchain note:** the project targets Dart `^3.12.2`; public Flutter images
> ship `3.12.0`. Docker builds relax the SDK floor **inside the container only**
> (host `pubspec` untouched). See AGENTS.md.

## 9. Odoo integration plan

The app is **headless-backend-agnostic**. To integrate Odoo as the system of record:

1. Add an `OdooClient` (JSON-RPC) alongside the Supabase client in `core/`.
2. Re-implement each `*_repository.dart` against Odoo models
   (`hr.attendance`, `account.analytic.line`/timesheets, `project.task`/tickets,
   `mail.channel`/chat, `res.users`/profiles) — **the presentation/application
   layers stay unchanged** because they depend on the repository interface, not Supabase.
3. Map Odoo records → existing immutable models in `shared/models`.
4. Calendar & leave (currently UI shells) bind to `calendar.event` / `hr.leave`.
5. Office geofence binds to `hr.work.location`.

This is why the repository facade boundary matters: **swapping backends is a
`data/` change, not an app rewrite.**
