# VCloud — Employee Productivity App

Flutter + Supabase app: **chat · attendance · timesheet · tickets · dashboard**.
Vietnamese UI, premium mobile design, ready to integrate with Odoo as a headless backend.

## Stack
- **Flutter** 3.44+ / Dart 3.12+ · Material 3, Impeller
- **Supabase** — auth · Postgres · Realtime · Row-Level Security
- **Riverpod** (state) · **GoRouter** (navigation)
- **flutter_animate** + **lucide_icons** (motion & iconography)

## Documentation
| Doc | Purpose |
|---|---|
| [docs/PRD.md](docs/PRD.md) | Product requirements (what & why) |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Technical architecture (how) |
| [docs/PLAN.md](docs/PLAN.md) | Roadmap & status (when) |
| [docs/MOBILE_UX_OPTIONS.md](docs/MOBILE_UX_OPTIONS.md) | Native-feel framework analysis |
| [AGENTS.md](AGENTS.md) | Onboarding for agents & devs (commands, gotchas) |
| [CHANGELOG.md](CHANGELOG.md) | Release history (Keep a Changelog) |

## Run

### Native (best experience)
```bash
flutter pub get
flutter run \
  --dart-define=VCLOUD_SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=VCLOUD_SUPABASE_ANON_KEY=sb_publishable_XXX
```

### Web in Docker (no local toolchain)
```bash
docker compose -f docker-compose.web.yml up --build   # → http://localhost:8080
```

### Android APK
See [AGENTS.md › Build Android APK](AGENTS.md#build-android-apk) → `dist/vcloud.apk`.

> The anon (publishable) key is the *non-secret* client key; RLS is the security
> boundary. Still, prefer `--dart-define` over committed defaults (tracked in PLAN M2).

## Supabase bootstrap
1. SQL editor → run `supabase/migrations/0001_init.sql`, then `0002_fix_conversation_members_recursion.sql`.
2. Auth → Providers → Email: disable "Confirm email" (MVP only).
3. Auth → URL config: add `vcloud://login-callback`.

## Project layout
```
lib/
  core/      config · theme · router · utils · error
  shared/    models · widgets (app_scaffold, ui_kit, ...)
  features/  auth · chat · attendance · timesheet · ticket · home · profile
             each as {data, application, presentation}
supabase/migrations/   schema + RLS (source of truth)
docker/                Flutter-web image + nginx config
docs/                  PRD · ARCHITECTURE · PLAN · UX options
```

## Verify
```bash
flutter analyze   # target: 0 errors / 0 warnings
flutter test
```
