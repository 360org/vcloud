# VCloud — Development Plan

> Roadmap & status. Pairs with [PRD.md](PRD.md) (requirements) and
> [ARCHITECTURE.md](ARCHITECTURE.md) (how). Status as of 2026-06-24.

Legend: ✅ done · 🔄 in progress · ⬜ planned

## Milestones

### M0 — MVP core ✅
Auth, geo check-in/out, timesheet, 1:1 + group chat (realtime), ticket CRUD,
dashboard, RLS on all tables, idempotent direct-conversation RPC.

### M1 — UI/UX redesign (Vcloud Mobile spec) ✅
- ✅ Design system: blue/green → premium blue→indigo gradient, vivid accents, glow shadows.
- ✅ Shell: bottom nav `Home · Chat · Timesheet · Ticket · Tôi`, gradient app bars.
- ✅ 6 screens rebuilt to the mockup + Profile (Tôi) screen, Vietnamese throughout.
- ✅ Motion layer: `flutter_animate` entrances, `PressableScale` + haptics,
  `AnimatedCount`, lucide icons, platform-adaptive page transitions.
- ✅ Dockerized web build + screenshots; Android APK pipeline.

### M1.1 — UI fixes & enhancements ✅
- ✅ Check-in screen: show check-in time after successful check-in.
- ✅ Timesheet: move add-form to top, limit today's entries with "Xem thêm" load-more.
- ✅ Chat: remove FAB, inline bottom sheet for new conversations, fix white background.
- ✅ Tickets: 2-status system (Đang xử lý / Hoàn thành), swipe-to-complete like Microsoft To-Do.
- ✅ Ticket detail: add comment section with real-time updates and composer.
- ✅ Migration 0003: `ticket_comments` table with RLS policies.
- ✅ Fix all `ListTile` inside `GlassCard`/`glassDecoration()` — replaced with `InkWell` + `Row` or `Padding` + `Row` to eliminate "ink splashes may be invisible" assertions (profile, home, timesheet screens).
- ✅ Added missing `Material(type: MaterialType.transparency)` wrapper on `new_chat_screen.dart` ListTile.

### M2 — Production hardening ⬜ (next)
- ⬜ Remove hard-coded Supabase URL/anon-key defaults from `env.dart` + README; fail-fast.
- ⬜ Tighten RLS: `conversations` insert must enforce `created_by = auth.uid()`.
- ⬜ Message pagination (load latest 50 + load-more) — `watchMessages` loads full history today.
- ⬜ Kill N+1 in `_fetchSummaries` (one last-message query per conversation).
- ⬜ CI: `flutter analyze && flutter test` on every push.
- ⬜ Re-enable email confirmation for production.

### M3 — Engagement ⬜
- ⬜ Read receipts / unread badges (schema `messages.read_by` exists, unused).
- ⬜ Analytics instrumentation (no events today): `check_in`, `timesheet_added`,
  `message_sent`, `ticket_*`, screen views.
- ⬜ Push notifications (FCM/APNs) for new message / assigned ticket.

### M4 — Team features ⬜
- ⬜ Cross-user ticket assignment (today self-assigned only, in code + RLS).
- ⬜ Manager/team dashboard + role model.
- ⬜ Geofence validation for attendance (`offices`/`hr.work.location`).

### M5 — Odoo integration ⬜
- ⬜ `OdooClient` (JSON-RPC) in `core/`.
- ⬜ Re-implement repositories against Odoo models (see ARCHITECTURE §9).
- ⬜ Bind calendar & leave (currently UI shells) to `calendar.event` / `hr.leave`.

## Requirement priorities (from PRD)

- **P0 (shipped):** auth, check-in/out, timesheet, chat, tickets, RLS, dashboard.
- **P1 (M2/M3):** pagination, read receipts, N+1 fix, secret hygiene, RLS insert fix.
- **P2 (M4/M5):** ticket assignment, manager views, geofence, push, rich chat, Odoo.

## Working agreements

- Every change must keep `flutter analyze` at **0 errors / 0 warnings**.
- Backend changes go through `supabase/migrations/*` (never ad-hoc SQL).
- Secrets via `--dart-define`, never committed (see [AGENTS.md](../AGENTS.md)).
- Presentation never imports Supabase — go through a repository.
