# SPEC.md - VCloud Mobile API Integration

## Objective
Use the Odoo Mobile API Gateway from the provided OpenAPI 3.0.3 contract (`Odoo Mobile API Gateway`, version `19.0.2.7.0`) as the only backend for the Flutter client.

## Workflow
All backend-facing feature work must follow:

```text
/spec -> /plan -> /build -> /test -> /review -> /ship
```

## Functional Scope
- Authentication follows the Decoupled 2-Tier Architecture (Service Directory Lookup & Direct Client-to-Tenant Auth):
  - Step 1 (Zero-Knowledge Directory Lookup): The client calls `POST /api/v1/auth/lookup-db` (or `POST /api/v1/mobile/auth/lookup-db`) on Master Hub (`vuahethong.net`) with ONLY `login` (NO password sent to Master Hub).
  - Master Hub acts strictly as a Service Directory (DNS/Index querying `databases.user` / `mobile.api.tenant_user`), returning a list of tenant candidates: `[{"database_name": "...", "database_url": "...", "display_name": "..."}]` without performing proxy authentication or storing tenant passwords. Anti-hardcode policy: URL lấy từ cấu hình chuẩn của tenant hoặc fallback về base_url, tuyệt đối không gán cứng domain `.vuahethong.com` làm hỏng custom domain của khách hàng.
  - Step 2 (Direct Client-to-Tenant Authentication):
    - Trường hợp 1 Database duy nhất (90% người dùng thông thường): Sau khi nhận metadata từ Master, App TỰ ĐỘNG gửi request xác thực thẳng vào server của tenant đó (`POST /api/v1/mobile/auth/login` hoặc `/web/session/authenticate`) với username/password vừa nhập -> Người dùng vào thẳng ứng dụng (Đăng nhập 1 chạm), không bao giờ hiển thị popup làm phiền.
    - Trường hợp Trùng tài khoản ở nhiều Database/Tổ chức (kể cả khi mật khẩu giống nhau hoặc khác nhau): App tự động hiển thị Popup Clean & Flat ("Chọn tổ chức / cơ sở dữ liệu làm việc" kèm tên đơn vị thân thiện và URL). Người dùng chỉ cần chạm chọn tổ chức mong muốn -> App gửi ĐÚNG 1 REQUEST xác thực duy nhất tới server của đơn vị đã chọn.
    - Trường hợp 0 Database tìm thấy (Tài khoản không tồn tại trên hệ thống hoặc Portal chưa được cấp quyền): App thông báo lỗi rõ ràng: "Tài khoản không tồn tại trên hệ thống".
  - The client receives and securely stores the tenant JWT access token, `tenant_id`, `db`, `base_url`, and user `scope`.
  - Session enrichment and lifecycle use tenant endpoints: `GET /api/v1/auth/me`, `POST /api/v1/auth/refresh`, and `POST /api/v1/auth/logout`.
- Attendance uses mobile endpoints:
  - `GET /api/v1/mobile/attendance/today`
  - `POST /api/v1/mobile/attendance/check-in`
  - `POST /api/v1/mobile/attendance/check-out/{att_id}`
  - `GET /api/v1/mobile/attendance/history`
  - The open attendance state refreshes immediately after a check-in/out, on
    foreground attendance push events, and every 15 seconds while consumed.
    Polling is the fallback until the Odoo v17 mobile gateway exposes a
    documented WebSocket/bus contract to Flutter.
  - The `/today` mapper accepts `is_checked_in` / `current_attendance_id` and
    Odoo v17 aliases `attendance_state` / `last_check_in`. A checked-in response
    must still include an attendance record id for the check-out endpoint.
- Tickets use mobile endpoints:
  - `GET /api/v1/mobile/ticket/list`
  - `GET /api/v1/mobile/ticket/{ticket_id}`
  - `POST /api/v1/mobile/ticket/create`
  - `POST /api/v1/mobile/ticket/{ticket_id}/message`
  - `GET /api/v1/mobile/ticket/teams`
  - `POST /api/v1/mobile/ticket/{ticket_id}/contact`
  - Ticket comments should refresh automatically while the detail screen is
    open. Current implementation uses a lightweight HTTP polling stream plus
    immediate optimistic rendering and provider invalidation after sending a
    comment.
  - If ticket creation mirrors its description into Odoo chatter, the mobile
    comment stream excludes that duplicate initial message; the description is
    rendered in the ticket detail field instead.
  - Ticket detail comments are ordered newest-first. The detail screen only
    renders the newest window first and expands older comments locally via
    "Xem thêm bình luận cũ" to avoid unnecessary initial UI work.
  - Ticket list/detail/create must use the 360 Support mobile ticket contract,
    not direct `/api/v1/helpdesk.ticket` model CRUD from the Flutter client.
  - Unsupported mobile mutations (status, priority, team/category, delete) must
    fail explicitly in the repository until the 360 Support API exposes matching
    endpoints; do not silently fall back to `helpdesk.ticket`.
  - The create-ticket UI captures only the mobile support intake fields:
    title, issue description, star-based priority, tag, CC email, and handling
    team.
  - The ticket-detail UI mirrors the same support fields: title, issue
    description, star-based priority, tag, CC email, and handling team.
  - Create payload sends `team_id`, `name`, `description`, `priority`, and
    selected `tag_ids`. CC emails are appended to the description as structured
    text until the mobile API exposes a dedicated CC field.
  - The create-ticket UI lets users pick a gallery image, capture a camera
    image, or select a document locally. After the ticket is created, selected
    files are uploaded with `res_model=helpdesk.ticket` and the new ticket id.
  - Native mobile builds must declare camera/photo permissions for these local
    pickers; document selection uses the platform file picker.
- Attachments use mobile endpoints:
  - `POST /api/v1/mobile/attachments/upload`
  - `GET /api/v1/mobile/attachments/{id}`
  - Upload uses JSON base64 from Flutter and stores returned metadata including
    `id`, `attachment_id`, `mimetype`, `file_size`, `url`, `download_url`, and
    `access_token`.
- Chat uses mobile endpoints:
  - `GET /api/v1/mobile/chat/channels`
  - `GET /api/v1/mobile/chat/channels/{channel_id}/messages`
  - `POST /api/v1/mobile/chat/messages`
  - `POST /api/v1/mobile/chat/channels/{channel_id}/mark-read`
  - `POST /api/v1/mobile/chat/direct`
  - `GET /api/v1/mobile/users/search?q={keyword}` for internal-user lookup.
    Search responses preserve both the Odoo user ID and `partner_id`; direct
    creation sends only `partner_id`.
  - `POST /api/v1/mobile/chat/groups`
  - `POST /api/v1/mobile/chat/channels/{channel_id}/archive`
  - `POST /api/v1/mobile/chat/channels/{channel_id}/unarchive`
  - `POST /api/v1/mobile/chat/channels/{channel_id}/contact`
  - `POST /api/v1/mobile/chat/messages/{message_id}/pin`
  - `POST /api/v1/mobile/chat/messages/{message_id}/unpin`
  - Chat attachment UI uploads gallery images, camera captures, and documents to
    the current channel via `/api/v1/mobile/attachments/upload` with
    `res_model=discuss.channel`.
  - The chat composer must keep gallery, camera, and document actions wired to
    repository actions instead of building upload payloads directly in widgets.
  - Chat detail reads `pinned_at` from message payloads to show the newest pinned
    message banner. Long-press actions call the repository to pin/unpin instead
    of modifying message text locally.
  - Chat info Media/File tabs rebuild older sent images and files from message
    attachment metadata (`attachments`/`attachment_ids`) plus URL fallback.
  - `GET /api/v1/discuss.channel/{id}` for channel metadata details only.
  - Chat group creation accepts a group `name` and integer `member_ids`;
    the primary chat UI exposes this through the "Nhóm mới" action.
  - Chat channel payload exposes `last_message_id`, `last_message`,
    `last_message_date`, `unread_count`, `last_seen_message_id`, and
    `last_seen_dt` for conversation previews and badges.
  - Chat message payload exposes `is_read_by_me` and `read_by_count` for
    read-state UI.
- Timesheets/tasks use mobile endpoints:
  - `GET /api/v1/mobile/timesheet/list`
  - `POST /api/v1/mobile/timesheet/log`
  - `GET /api/v1/mobile/timesheet/projects`
  - `GET /api/v1/mobile/timesheet/projects/{project_id}/tasks`
  - `POST /api/v1/project.task/{task_id}/complete`
  - timer endpoints are reserved for future UI wiring.
- Ticket activity history uses `GET /api/v1/mobile/ticket/{ticket_id}/activities`.
- Home dashboard summary uses `GET /api/v1/mobile/dashboard/summary`.
- Mobile push notification uses FCM token registration endpoints:
  - `POST /api/v1/mobile/notifications/register`
  - `POST /api/v1/mobile/notifications/unregister`
  - The Flutter client registers the current device after login/session restore
    and unregisters the last known token before logout. Push setup must never
    block the main auth flow when Firebase is not configured locally or the user
    denies notification permission.
  - Until the backend exposes a notification-list endpoint, the Home bell loads
    actionable in-app notifications from existing mobile data: unread chat
    conversations and open tickets.
- Avatar rendering uses `/api/v1/mobile/avatar/{users,partners,channels}/{id}`
  when list/detail payloads do not already include inline avatar data.
- Portal Users Multi-Persona & Governance:
  - Supports dual user personas on mobile: `Internal Users` (staff/employees) and `Portal Users` (external customers/partners with `share=true`).
  - Auth contract returns `"is_portal": bool` and `"user_type": "portal" | "internal"`.
  - Portal Users receive a tailored lightweight 3-tab navigation: `Ticket` (support request lifecycle), `Chat` (direct conversation with technical team), and `Tôi` (account profile).
  - Internal features (`Attendance`, `Timesheet`, internal project tasks, and full company directory) are guarded both client-side (route redirects) and server-side (HTTP 403 Forbidden).
  - Ticket and Project API queries strictly enforce isolation domains: Portal Users can only read and comment on tickets/tasks where they are the owner/partner or a registered follower, preventing cross-tenant and company-internal data leakage.

## Non-Goals
- No alternate backend client initialization or direct backend calls in presentation/application layers.
- No database migrations for Odoo-owned schema.
- No Odoo server module Python/XML/OWL work in this Flutter client repo.

## Configuration
Runtime configuration is passed via `--dart-define`:

```bash
--dart-define=VCLOUD_ODOO_API_BASE_URL=https://odoo.example.com
--dart-define=VCLOUD_FIREBASE_API_KEY=...
--dart-define=VCLOUD_FIREBASE_APP_ID=...
--dart-define=VCLOUD_FIREBASE_MESSAGING_SENDER_ID=...
--dart-define=VCLOUD_FIREBASE_PROJECT_ID=...
--dart-define=VCLOUD_FIREBASE_IOS_BUNDLE_ID=com.w360s.wcloudapp
```

If the Firebase defines are omitted, push registration is skipped client-side
and the rest of the app continues to run.

## Mobile distribution

- Release artifacts are built by GitHub Actions on version tags matching `v*`.
  The iOS job runs on macOS, passes `flutter analyze` and `flutter test`, then
  executes Fastlane `ios beta` for TestFlight.
- The Android job runs Fastlane `android beta` and uploads APK/AAB artifacts.
- App Store, signing, Google Play, webhook, and Odoo production values are CI
  secrets. They must never be committed to this repository or written into docs.
- GitHub remains a clean build mirror. Do not push development branches or
  internal handoff/local-machine details there.

## Acceptance Criteria
- `flutter analyze` has 0 errors and 0 warnings.
- Existing smoke/widget tests pass or skipped blockers are documented.
- `AGENTS.md`, `docs/ARCH.md`, `docs/PLAN.md`, and `docs/CHANGELOGS.md` reflect the migration.
- Ticket create/get/list tests assert mobile ticket endpoint usage and guard
  against accidental `helpdesk.ticket` calls.
- Product UI changes should be reflected in `docs/IDEA_IMPROVE.md` so later agents
  understand which ideas came from user direction and which were implementation
  refinements.
