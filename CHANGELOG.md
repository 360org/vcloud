# Changelog

All notable changes to VCloud are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [Semantic Versioning](https://semver.org/).

## [Unreleased]
### Added
- Add `SPEC.md`, `ARCH.md`, and `implementation_plan.md` for the Odoo Mobile API migration workflow.
- Add Odoo API client/session storage using JWT bearer auth from `/api/v1/auth/login`.
- Add mobile dashboard summary wiring for Home counters, mobile avatar rendering,
  ticket activity history, chat direct/group/archive actions, auth me/refresh/logout,
  and project task completion endpoint support.

### Changed
- Replace Odoo API runtime integration with Odoo Mobile API repositories for auth, attendance, chat, tickets, timesheets, and tasks.
- Update `AGENTS.md` so every new feature follows `/spec -> /plan -> /build -> /test -> /review -> /ship`.
- Map Discuss/mobile chat API fields (`ChatChannel`, `MessageInfo`) into app
  chat models and wire mark-read through the mobile message endpoint.
- Map mobile chat read-state fields for previews, unread badges, and message
  read metadata; split the chat list into direct and group tabs.

### Fixed
- Fix mojibake chat repository failure messages and keep unsupported direct/group
  creation as explicit Vietnamese `Failure`s until the API exposes mobile
  endpoints for them.
- Refresh chat detail and conversation preview metadata after sending messages,
  and mark conversations read through the channel-level mobile endpoint.
- Replace abandoned `lucide_icons` (0.257.0) with actively maintained `lucide_flutter` (^1.20.0) to fix compilation error on Flutter 3.44+ (`IconData` is now `final`).
- Fix `ListTile` background color/ink splash visibility by wrapping Containers with `Material(type: MaterialType.transparency)` in profile and timesheet list screens; further replaced `ListTile` with `InkWell` + `Row` or `Padding` + `Row` inside `GlassCard`/`glassDecoration()` to fully eliminate runtime assertions across profile, home, and timesheet screens.
- Fix missing `lucide_flutter` import in profile screen causing `LucideIcons` undefined errors.
- Fix missing `odoo_api_client` import in ticket detail and chat detail screens; replace undefined `currentUserId()` with `Odoo API.instance.client.auth.currentUser?.id`.
- Fix white background issues in chat screens (bubbles, composer, avatars).

### Changed
- **"Refined Tech Luxury" UI redesign** across all primary screens:
  - New design system: midnight gradient palette (`#0F1629` / `#1A2340`), per-feature gradient pairs, glass morphism tokens (`glassDecoration`, `AppTextStyles`).
  - Shared widgets rebuilt: `AppScaffold` (gradient AppBar, glass bottom nav with gradient pill), `GlassCard`, `GradientHeader`, `GradientBadge`, `StatTile`, `EmptyState`, `ErrorView`, `LoadingView`.
  - Home screen: gradient header, glass check-in card, gradient StatTile widgets, staggered entrance animations.
  - Attendance screen: live clock with seconds, gradient circle check-in button, glass location card, **shows check-in time after successful check-in**.
  - Timesheet list: glass summary card, gradient category pills with icons, **add-form moved to top with load-more for today's entries**.
  - Ticket list: glass tab bar with gradient indicator, gradient FAB, **2-status system (Đang xử lý / Hoàn thành) with swipe-to-complete**.
  - Ticket detail: **comment section with real-time updates and composer**.
  - Profile: dark gradient header, glass settings card with colored icon chips.
  - Login/Signup/Splash: dark gradient backgrounds, glass form cards, gradient brand logo.
  - Chat: **removed FAB, inline bottom sheet for new conversations, fixed white background issues**.
- Entrance animations via `flutter_animate`: staggered `fadeIn + slideY` on Home, `fadeIn` with delays on Attendance and Profile.

### Added
- Migration 0003: `ticket_comments` table with Odoo access rules policies for ticket discussions.
- `TicketComment` model and `TicketCommentRepository` for real-time comment streams.
- `ticketCommentsProvider` and `ticketCommentActionsProvider` in ticket controller.

### Planned (see [docs/PLAN.md](docs/PLAN.md) M2)
- Remove hard-coded Odoo API URL/anon-key defaults from `env.dart`; fail-fast on missing `--dart-define`.
- Tighten Odoo access rules: `conversations` insert must enforce `created_by = auth.uid()`.
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
- **Dependencies**: `flutter_animate` (entrance/micro animations), `lucide_flutter`
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
- Odoo API anon (publishable) key still defaulted in `env.dart` — scheduled for removal in M2.

## [1.0.0] - 2026-06-24
Initial MVP.

### Added
- Email/password **auth** with secure-storage session persistence.
- **Attendance**: geo-stamped check-in / check-out, live history.
- **Timesheet**: task logging by category & fixed duration.
- **Chat**: 1:1 + group conversations over Odoo API refresh; idempotent
  direct-conversation RPC.
- **Tickets**: self-assigned CRUD with optimistic status updates.
- **Dashboard**: today's check-in status, hours, open tickets, conversation count.
- **Odoo access rules** on all tables; `SECURITY DEFINER` helper fixes
  conversation-members policy recursion (migration `0002`).
