# Changelog

All notable changes to VCloud are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [Semantic Versioning](https://semver.org/).

## [Unreleased]
### Planned (see [docs/PLAN.md](docs/PLAN.md) M2)
- Remove hard-coded Supabase URL/anon-key defaults from `env.dart`; fail-fast on missing `--dart-define`.
- Tighten RLS: `conversations` insert must enforce `created_by = auth.uid()`.
- Message pagination; remove N+1 in conversation summaries.
- CI: `flutter analyze && flutter test` on every push.

## [1.1.0] - 2026-06-24
Premium UI/UX redesign to the "Vcloud Mobile" spec, plus documentation and a
toolchain-free build pipeline.

### Added
- **Design system** (`core/theme`): blue→indigo gradient brand, vivid per-feature
  accents, layered soft shadows with colored glow, gradient tokens & helpers.
- **Profile ("Tôi") screen** and `/profile` route; bottom nav becomes
  Home · Chat · Timesheet · Ticket · Tôi.
- **Motion/UX kit** (`shared/widgets/ui_kit.dart`): `PressableScale` (tap-scale +
  haptics), `GradientButton`, `AnimatedCount`.
- **Dependencies**: `flutter_animate` (entrance/micro animations), `lucide_icons`
  (modern line icon set).
- **Build pipeline**: Dockerized Flutter-web image (nginx) + `docker-compose.web.yml`;
  Android APK build recipe (release, arm64, debug-signed).
- **Documentation**: `docs/{PRD,ARCHITECTURE,PLAN,MOBILE_UX_OPTIONS}.md`, `AGENTS.md`,
  `CHANGELOG.md`; refreshed `README.md`.

### Changed
- All six feature screens rebuilt to the mockup; **Vietnamese UI** throughout.
- Gradient app bars; platform-adaptive page transitions (Cupertino on iOS, Zoom on Android).
- Login/Signup branded (VCloud logo) and localized.
- `.gitignore` now excludes build artifacts (`dist/`, `*.apk`, `*.aab`, `*.ipa`).

### Notes
- `flutter analyze`: 0 errors / 0 warnings.
- Supabase anon (publishable) key still defaulted in `env.dart` — scheduled for removal in M2.

## [1.0.0] - 2026-06-24
Initial MVP.

### Added
- Email/password **auth** with secure-storage session persistence.
- **Attendance**: geo-stamped check-in / check-out, live history.
- **Timesheet**: task logging by category & fixed duration.
- **Chat**: 1:1 + group conversations over Supabase Realtime; idempotent
  direct-conversation RPC.
- **Tickets**: self-assigned CRUD with optimistic status updates.
- **Dashboard**: today's check-in status, hours, open tickets, conversation count.
- **Row-Level Security** on all tables; `SECURITY DEFINER` helper fixes
  conversation-members policy recursion (migration `0002`).
