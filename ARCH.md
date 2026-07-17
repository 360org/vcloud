# ARCH.md - Odoo API Architecture

## Backend Boundary
The app now talks to Odoo through a single HTTP boundary:

```text
presentation
  -> application providers/controllers
  -> feature repositories
  -> core/api/OdooApiClient
  -> Odoo Mobile API Gateway
```

Presentation must never call HTTP, Odoo, or storage directly.

## Core API Layer
- `Env.odooApiBaseUrl` points to the master mobile auth resolver.
  `Env.odooDb` remains optional for compatibility, but the default mobile login
  sends only `login` and `password`.
- Firebase push configuration is also read from `Env` via `--dart-define`
  values. Missing Firebase values disable client-side push registration without
  breaking local development.
- `OdooSessionStore` persists `access_token`, `uid`, `db`, `login`, expiry, and
  tenant routing metadata (`base_url`, `tenant_id`, `scope`) using
  `flutter_secure_storage`.
- `OdooApiClient` logs in through `/api/v1/mobile/auth/login` on the master
  resolver, then sends authenticated requests to the tenant `base_url` returned
  by the resolver. It attaches `Authorization: Bearer <token>` and converts
  non-2xx responses into `Failure`.
- The master resolver should use `mobile.api.tenant_user` as the primary tenant
  mapping table. The optional `databases.user` integration is only a fallback,
  so the mobile client must not depend on that module being installed.
- `404 tenant_not_found` means the Odoo master lacks a Tenant Users mapping for
  the login. The client reports it as a setup issue so admins can create the
  mapping before retrying.
- Master database admins are allowed to fall back to direct master
  `/api/v1/auth/login` when the mobile resolver returns `tenant_not_found`; the
  resulting session uses the master base URL and `scope=master_admin`.
- `409 multiple_tenants` means more than one tenant accepted the credentials. The
  client parses the `tenants[]` payload into a typed `MultipleTenantsFailure` and
  shows a bottom-sheet picker; picking a tenant re-calls `login()` with `tenant_id`
  to force that tenant (the picker can be re-opened if the forced retry 409s again).
- Odoo domain/list endpoints are accessed through typed repository methods, not from widgets.

## Push Notification Boundary
- `PushNotificationService` owns Firebase Messaging initialization, permission
  requests, installation id storage, token lookup, and last-token storage.
- `PushNotificationRepository` is the only layer that calls
  `/api/v1/mobile/notifications/register` and
  `/api/v1/mobile/notifications/unregister`.
- `AuthController` registers the device after login/session restore and
  unregisters before logout. Push errors are logged and skipped so notification
  setup cannot break auth or business flows.
- Presentation does not call Firebase Messaging or notification HTTP endpoints.
- The Home bell is a notification-center view over existing application
  providers. It reads unread chat conversations and open tickets, then routes
  taps to `/chat/:id` or `/tickets/:id`. This keeps the UI useful while the
  current mobile notification API only exposes device register/unregister.

## Auth Model
`AuthUser` is the app-local user/session identity. It intentionally exposes the small shape the UI needs:
- `id`
- `email`
- `userMetadata`

This keeps UI code stable without importing backend SDK types.

## Refresh Model
Repositories emit an initial HTTP snapshot and application actions invalidate providers after mutations. Polling or WebSocket support can be added later behind the same repository contracts.

Ticket comments are the first polling-backed stream: `TicketCommentRepository`
fetches the mobile ticket detail on listen and refreshes comments periodically
while the detail screen is mounted. `TicketCommentActions.add` invalidates the
comment provider immediately after posting so the author sees the new comment
without leaving and reopening the ticket. The detail screen also renders an
optimistic local comment immediately when the user sends, then replaces it with
the server comment once the mobile API returns.

Ticket detail renders comments newest-first and only shows the newest window
initially. Older comments are already available from the current detail payload
and are revealed locally with a "Xem thêm bình luận cũ" button, avoiding extra
fetches for simple expansion.

## Data Mapping
Odoo uses integer IDs and snake_case fields. Existing Flutter models keep their public shape, while `fromMap` factories accept normalized maps from repositories:
- IDs are converted to strings.
- Odoo date fields map to app date fields.
- Stage/priority/status values are normalized for current UI enums.

## Chat Boundary
- Chat list, detail, direct open, group creation, archive, and mark-read calls
  are exposed through `ChatRepository` and `conversationActionsProvider`.
- Message pin/unpin actions are exposed through `ChatRepository` and
  `pinMessageActionProvider`; presentation reads `Message.pinnedAt` and does not
  fake pinned state by prefixing message content.
- The main `/chat` route uses `TelegramConversationListScreen`; its "Nhóm mới"
  action opens a group composer sheet, selects users from the repository user
  catalog, then posts `name` and integer `member_ids` to
  `/api/v1/mobile/chat/groups`.
- Chat info Media/File views are derived from the currently loaded message
  history and use attachment metadata to reconstruct older sent images/files.
- Presentation never builds chat HTTP payloads directly; it passes display
  values and selected user IDs into the application action.

## Ticket / 360 Support Boundary
- Ticket screens use `features/ticket/application/ticket_controller.dart` and
  `features/ticket/data/ticket_repository.dart` as the only path to ticket API
  calls.
- Ticket create/get/list and team catalog calls are routed through the 360
  Support mobile endpoints under `/api/v1/mobile/ticket/*`.
- The Flutter client must not call direct `/api/v1/helpdesk.ticket` CRUD for
  ticket create/get/list behavior. Direct model CRUD is not a fallback for
  unsupported 360 Support actions.
- `ticketTeamsProvider` exposes `/api/v1/mobile/ticket/teams` to presentation so
  the create-ticket screen can render real handling teams without knowing JSON
  response details.
- The create-ticket UI keeps CC email as structured text in the ticket
  description until the backend exposes a dedicated CC field.
- Local attachment picking uses `image_picker` for gallery/camera and
  `file_picker` for documents. `TicketRepository.create` creates the ticket
  first, then uploads selected files through
  `/api/v1/mobile/attachments/upload` with `res_model=helpdesk.ticket` and the
  created ticket id.
- `MobileAttachmentRepository` centralizes upload and metadata reads for
  `/api/v1/mobile/attachments/*`.
- Chat and ticket contact cards are routed through repository methods for
  `/api/v1/mobile/chat/channels/{id}/contact` and
  `/api/v1/mobile/ticket/{id}/contact`.

## Ticket Create UI Pattern
- The create-ticket screen is a single product form with a centered header,
  feature gradient summary, one white form panel, and compact field rhythm.
- The issue description uses a composer-style input with an inline
  "Thêm tài liệu" action and local document chips. This is UI-level document
  capture backed by `MobileAttachmentRepository`; selected files are uploaded
  after the ticket is created.
- Priority is selected with 1-4 stars and mapped to existing
  `TicketPriority`/Odoo priority values in the repository.

## Ticket Detail UI Pattern
- Ticket detail mirrors the support intake shape instead of showing operational
  timeline blocks first: title, issue description, star priority, tags, CC
  email, and handling team.
- `Ticket.tagLabels` is populated from the mobile `tags` payload so detail can
  show tag names without parsing backend JSON in presentation.
- CC email and document labels are parsed from structured description lines
  until the backend exposes dedicated fields.

## Security
Secrets and environment-specific hostnames stay out of committed code. JWTs are stored only in secure storage.
