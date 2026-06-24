# VCloud — Product Requirements Document (MVP)

> **Status:** Reverse-engineered from the existing codebase (`v1.0.0+1`) on 2026-06-24.
> Sections grounded in shipped code are marked ✅; assumptions/hypotheses are marked 🔶 and need product validation.
>
> **Stack:** Flutter 3.x · Dart 3.12+ · Supabase (auth · Postgres · Realtime · RLS) · Riverpod · GoRouter
> **Platforms in repo:** Android, iOS, Web, Windows

---

## 1. Problem Statement

Small in-house teams (e.g. an ERP/CRM services company) juggle attendance, daily work logging, internal chat, and task tracking across 3–4 disconnected tools (Zalo for chat, a spreadsheet for timesheets, paper/HR app for attendance, email for tasks). Context is fragmented, managers have no single view of "who's working on what today", and employees waste minutes per day switching apps. VCloud consolidates the four highest-frequency daily actions — **check-in/out, log time, chat, track tickets** — into one mobile app with a single dashboard.

🔶 *Evidence basis is currently assumed.* Before scaling investment, validate with: how many tools the target team uses today, and how much time/friction the fragmentation actually costs.

---

## 2. Goals

1. ✅ **One app for the daily loop** — an employee can check in, log a timesheet entry, send a chat, and update a ticket without leaving VCloud.
2. 🔶 **Reduce attendance friction** — geo-stamped check-in/out replaces manual attendance; target **≥80% of active employees check in via the app daily** within 30 days of rollout.
3. 🔶 **Make timesheets actually get filled** — target **≥70% of working days have at least one timesheet entry** per active user.
4. ✅ **Real-time visibility** — chat, tickets, attendance and timesheets all update live (Supabase Realtime) so a manager's dashboard reflects current state without refresh.
5. 🔶 **Single dashboard** — the home screen surfaces today's status (checked-in elapsed time, today's logged minutes, open tickets, recent conversations) at a glance.

---

## 3. Non-Goals (this version)

1. **Payroll / HR system of record** — VCloud records attendance and time, but does not compute pay, leave balances, or integrate with payroll. *(Separate, regulated initiative.)*
2. **Cross-user task assignment** — tickets are self-created and self-assigned only (`created_by = assigned_to = me`, enforced in code and RLS). Delegating work to a teammate is **out of scope for v1**. *(Requires assignment + notification model; see Open Questions.)*
3. **Geofencing / fraud prevention** — check-in captures lat/lng but does **not** validate the user is at an approved office location, nor prevent spoofing. *(Trust-based MVP.)*
4. **Rich chat** — no attachments, images, voice, reactions, edit/delete, or typing indicators. Text-only, 1–4000 chars.
5. **Admin / manager console** — no role hierarchy, no team-wide reporting views, no user management UI. Every user sees only their own data + shared conversations.
6. **Offline mode** — the app assumes connectivity; no local queue/sync.

---

## 4. Target Users

- **Primary — Field/office employee:** checks in/out, logs time against categories (ERP/CRM/Meeting/Support/Other), chats with colleagues, tracks their own tickets.
- 🔶 **Secondary — Team lead (future):** wants visibility across the team. *Not served by v1* (no manager views) — listed to guide architecture.

---

## 5. User Stories

### Authentication ✅
- As an employee, I want to sign up with email/password and a display name so that I have an identity in the app. *(A `profiles` row is auto-created via DB trigger on signup.)*
- As an employee, I want to stay logged in across app restarts so that I don't re-enter credentials daily. *(Session persisted in Keychain/EncryptedSharedPreferences via `SecureLocalStorage`.)*
- As an employee, I want to be routed to login or home automatically based on my auth state. *(GoRouter redirect guard.)*

### Attendance ✅
- As an employee, I want to check in with one tap so that my start time and location are recorded.
- As an employee, I want to check out so that my session is closed and elapsed time is captured.
- As an employee, I want to see my recent attendance history, updating live.
- *Edge:* As an employee, if location services/permission are off, I want a clear message telling me how to fix it. *(Tailored failure messages per denial case.)*
- *Edge:* As an employee, I cannot check out if I have no open check-in. *("No open check-in to close.")*

### Timesheet ✅
- As an employee, I want to log a task with a category and a fixed duration (15m/30m/1h/2h) against a date so that my work is recorded quickly.
- As an employee, I want to see today's total logged minutes on my dashboard.
- As an employee, I want my recent entries sorted by worked date.

### Chat ✅
- As an employee, I want to start a 1:1 conversation with a colleague so we can message directly. *(Idempotent via `create_direct_conversation` RPC — reuses an existing 1:1 if present.)*
- As an employee, I want to create a group conversation with multiple members.
- As an employee, I want to send and receive text messages in real time.
- As an employee, I want my conversation list ordered by most-recent activity with a last-message preview.

### Tickets ✅
- As an employee, I want to create a ticket (title + optional description) so I can track a task.
- As an employee, I want to move a ticket through Todo → Doing → Done with an immediate (optimistic) UI update.
- As an employee, I want to delete a ticket I created.
- As an employee, I want to see a count of my open tickets on the dashboard.

### Dashboard ✅
- As an employee, I want a single home screen summarizing my check-in status + elapsed time, today's minutes, open ticket count, and conversation count.

---

## 6. Requirements

### Must-Have (P0) — shipped ✅
| # | Requirement | Acceptance Criteria |
|---|---|---|
| P0-1 | Email/password auth with persistent session | Given valid credentials, when I sign in, then I land on `/home` and remain signed in after a cold restart. Wrong credentials show "Wrong email or password." |
| P0-2 | Auto profile provisioning | Given a new signup, then a `profiles` row exists with `display_name` (from metadata or email prefix). |
| P0-3 | Geo check-in/out | Given location permission granted, when I check in, then an `attendance` row with `checkin_time` + `checkin_lat/lng` is created. Check-out closes the latest open row and stamps `checkout_time` + location. |
| P0-4 | Timesheet entry | When I submit task name (1–120 chars) + category + duration, then a `timesheets` row for `worked_date` is created and appears in my list live. |
| P0-5 | 1:1 + group chat, realtime | When I send a message, then it persists and appears for all members within the realtime latency window; conversation list re-sorts by latest activity. |
| P0-6 | Ticket CRUD + status flow | I can create, change status (optimistic), and delete my tickets; changes reflect live. |
| P0-7 | Row-Level Security on all tables | A user can only read/write their own attendance, timesheets, tickets, and conversations they're a member of. *(Enforced by RLS policies; `am_conversation_member()` SECURITY DEFINER helper avoids policy recursion.)* |
| P0-8 | Dashboard summary | Home shows live check-in status/elapsed, today's minutes, open tickets, conversation count. |

### Nice-to-Have (P1) — gaps to close
| # | Requirement | Rationale / Acceptance |
|---|---|---|
| P1-1 | **Message pagination** | `watchMessages` currently loads *entire* history with no limit. Load latest 50 + "load more" so long chats don't bloat memory. |
| P1-2 | **Unread / read receipts** | Schema has `messages.read_by jsonb` but nothing writes/reads it. Mark-as-read + unread badge on conversation list. |
| P1-3 | **Eliminate N+1 in conversation list** | `_fetchSummaries` runs one last-message query per conversation. Replace with a single window-function query or RPC. |
| P1-4 | **Harden secret handling** | Remove hard-coded Supabase URL/anon key defaults from `env.dart` + README; fail-fast if `--dart-define` missing. |
| P1-5 | **Tighten RLS on `conversations` insert** | Enforce `with check (created_by = auth.uid())` (currently only checks `authenticated`). |
| P1-6 | **Empty/error/loading polish** | Shared `EmptyState`/`ErrorView`/`LoadingView` widgets exist — ensure every async screen uses them consistently. |

### Future Considerations (P2) — design for, don't build
| # | Consideration | Why it matters now |
|---|---|---|
| P2-1 | **Assign tickets to teammates** | Biggest functional limitation. Data model already separates `created_by`/`assigned_to`; only the create path + RLS hardcode self. Keep them distinct so assignment is a policy/UI change, not a migration. |
| P2-2 | **Manager/team dashboard** | Will need a role concept + RLS policies that allow a lead to read team rows. Avoid baking "self-only" assumptions into queries that would block this. |
| P2-3 | **Geofence validation** | `attendance` already stores lat/lng; add an `offices` table + radius check later. |
| P2-4 | **Push notifications** (new message, ticket assigned) | Requires FCM/APNs wiring; design message/ticket events to be notification-friendly. |
| P2-5 | **Rich chat** (attachments, reactions, edit/delete) | Keep `messages` schema extensible. |

---

## 7. Success Metrics 🔶

*All targets are hypotheses pending a baseline — instrument analytics before committing.*

**Leading (days–weeks):**
- **Daily check-in rate:** ≥80% of active employees check in via app / working day (within 30 days).
- **Timesheet fill rate:** ≥70% of working days have ≥1 entry per active user.
- **Chat activation:** ≥60% of users send ≥1 message in week 1.
- **Crash-free sessions:** ≥99.5%.
- **Check-in success rate:** ≥95% of check-in attempts complete without a location error.

**Lagging (weeks–months):**
- **Tool consolidation:** target team retires ≥1 prior tool (spreadsheet timesheet or separate attendance app).
- **W4 retention:** ≥50% of signups still active in week 4.
- **Manager satisfaction** 🔶 (once team views exist).

**Measurement:** define event instrumentation (currently none in the app) — at minimum `check_in`, `check_out`, `timesheet_added`, `message_sent`, `ticket_created`, `ticket_status_changed`, plus screen views. Evaluate at 1 week / 1 month / 1 quarter.

---

## 8. Open Questions

| Question | Owner | Blocking? |
|---|---|---|
| Is **self-only ticket assignment** intentional for MVP, or a known cut? Determines P2-1 priority. | Product | No |
| Do we need **geofence/anti-spoof** before trusting attendance for any HR/payroll purpose? | Product + Legal | No (blocks payroll later) |
| Is **email confirmation** acceptable to keep disabled (README instructs disabling it) for production, or is it MVP-only? | Eng + Security | Yes (before prod) |
| What is the **target deployment surface** — the repo builds Android/iOS/Web/Windows; which are officially supported? | Product + Eng | Yes (scopes QA) |
| Are **profile emails/names** OK to expose to all authenticated users (current `profiles read` policy)? Acceptable as an internal directory? | Security | No |
| Which **analytics/observability** stack? No instrumentation exists today. | Data + Eng | No (blocks metrics) |
| Is there a **CI pipeline** requirement? Repo has only a smoke test and no workflow. | Eng | No |

---

## 9. Timeline & Phasing

The MVP (Section 6 P0) is **already implemented**. Suggested next phases:

- **Phase 1 — Production-hardening (P1):** secret handling (P1-4), RLS insert fix (P1-5), message pagination (P1-1), N+1 fix (P1-3). *Pre-launch blockers for scale/security.*
- **Phase 2 — Engagement:** read receipts/unread badges (P1-2), analytics instrumentation (Section 7), push notifications (P2-4).
- **Phase 3 — Team features:** cross-user ticket assignment (P2-1), manager dashboard + role model (P2-2), geofence validation (P2-3).

**Dependencies:** Supabase project must be bootstrapped per README (run `0001_init.sql` + `0002_fix...sql`, disable email confirmation, set `vcloud://login-callback` redirect). Push/analytics phases add external service dependencies (FCM/APNs, analytics SDK).

---

## Appendix A — Data Model (as built)

- **profiles** `(id→auth.users, email, display_name, avatar_url)` — auto-created by trigger.
- **conversations** `(id, is_group, name, created_by)` + **conversation_members** `(conversation_id, user_id)` (composite PK).
- **messages** `(id, conversation_id, sender_id, content[1–4000], read_by jsonb, created_at)`.
- **attendance** `(id, user_id, checkin_time, checkout_time, checkin_lat/lng, latitude/longitude)`.
- **timesheets** `(id, user_id, task_name[1–120], category enum, duration enum, worked_date)`.
- **tickets** `(id, title[1–120], description, status enum Todo/Doing/Done, created_by, assigned_to, updated_at via trigger)`.
- **RPC** `create_direct_conversation(other_id)` — idempotent 1:1 creation, SECURITY DEFINER.
- **Realtime** publication includes messages, conversations, tickets, attendance, timesheets.
