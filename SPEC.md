# SPEC.md - Odoo Mobile API Integration

## Objective
Use the Odoo Mobile API Gateway from the provided OpenAPI 3.0.3 contract (`Odoo Mobile API Gateway`, version `19.0.1.0.0`) as the only backend for the Flutter client.

## Workflow
All backend-facing feature work must follow:

```text
/spec -> /plan -> /build -> /test -> /review -> /ship
```

## Functional Scope
- Authentication uses `POST /api/v1/auth/login` and stores the JWT bearer token securely on device.
  Session enrichment and lifecycle use `GET /api/v1/auth/me`,
  `POST /api/v1/auth/refresh`, and `POST /api/v1/auth/logout`.
- Attendance uses mobile endpoints:
  - `GET /api/v1/mobile/attendance/today`
  - `POST /api/v1/mobile/attendance/check-in`
  - `POST /api/v1/mobile/attendance/check-out/{att_id}`
  - `GET /api/v1/mobile/attendance/history`
- Tickets use mobile endpoints:
  - `GET /api/v1/mobile/ticket/list`
  - `GET /api/v1/mobile/ticket/{ticket_id}`
  - `POST /api/v1/mobile/ticket/create`
  - `POST /api/v1/mobile/ticket/{ticket_id}/message`
  - `GET /api/v1/mobile/ticket/teams`
- Chat uses mobile endpoints:
  - `GET /api/v1/mobile/chat/channels`
  - `GET /api/v1/mobile/chat/channels/{channel_id}/messages`
  - `POST /api/v1/mobile/chat/messages`
  - `POST /api/v1/mobile/chat/channels/{channel_id}/mark-read`
  - `POST /api/v1/mobile/chat/direct`
  - `POST /api/v1/mobile/chat/groups`
  - `POST /api/v1/mobile/chat/channels/{channel_id}/archive`
  - `POST /api/v1/mobile/chat/channels/{channel_id}/unarchive`
  - `GET /api/v1/discuss.channel/{id}` for channel metadata details only.
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
- Avatar rendering uses `/api/v1/mobile/avatar/{users,partners,channels}/{id}`
  when list/detail payloads do not already include inline avatar data.

## Non-Goals
- No alternate backend client initialization or direct backend calls in presentation/application layers.
- No database migrations for Odoo-owned schema.
- No Odoo server module Python/XML/OWL work in this Flutter client repo.

## Configuration
Runtime configuration is passed via `--dart-define`:

```bash
--dart-define=VCLOUD_ODOO_API_BASE_URL=https://odoo.example.com
--dart-define=VCLOUD_ODOO_DB=production_db
```

## Acceptance Criteria
- `flutter analyze` has 0 errors and 0 warnings.
- Existing smoke/widget tests pass or skipped blockers are documented.
- `AGENTS.md`, `ARCH.md`, `implementation_plan.md`, and `CHANGELOG.md` reflect the migration.
