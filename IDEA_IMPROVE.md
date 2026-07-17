# IDEA_IMPROVE.md - User Ideas and Product Improvements

Living log for user-sourced ideas, product direction, and implemented
improvements. Update this when a user asks for a UI/API behavior change so later
agents can understand the intent, not just the code diff.

## Direct Chat User Search

### User Idea
- Let employees find internal users from Chat and start a direct conversation.

### Implemented Improvement
- Direct Chat now searches `/api/v1/mobile/users/search?q={keyword}` instead of
  reading the generic `res.users` model endpoint.
- Search results retain both the internal user ID and Odoo `partner_id`.
  Creating a direct conversation sends the required `partner_id` to
  `/api/v1/mobile/chat/direct`; group creation continues to use user IDs.

### Follow-Up Ideas
- Add debounce and result pagination if the internal directory grows beyond the
  small current result set.

## Ticket 360 Support API

### User Idea
- Ticket screens must create and get tickets through the 360 Support mobile API,
  not direct Helpdesk model API calls.
- The app should stop treating `/api/v1/helpdesk.ticket` as the ticket create/get
  path for the mobile product.

### Implemented Improvement
- `TicketRepository` now centralizes mobile ticket paths under
  `/api/v1/mobile/ticket`.
- Ticket list, detail, create, comment, activity, and team catalog flows use
  mobile ticket endpoints.
- Direct `helpdesk.ticket` mutations that are not available in the mobile
  contract now throw explicit `Failure`s instead of silently falling back to
  model CRUD.
- Tests protect create/get from regressing back to `helpdesk.ticket`.

### Follow-Up Ideas
- Add real mobile endpoints for status update, priority update, team/category
  update, and delete if those actions remain part of the product.
- Add backend-supported attachment upload for ticket creation.

## Create Ticket Form Scope

### User Idea
- Simplify the create-ticket UI to only the fields needed for intake:
  - title
  - issue description
  - priority rating by stars
  - tag
  - CC email
  - handling team

### Implemented Improvement
- Removed extra intake fields such as request type, location, asset/service,
  contact person, due date, and attachment note from the main UI.
- Added star-based priority selection while preserving existing
  `TicketPriority` mapping.
- Added tag dropdown and sends selected tag through `tag_ids` when available.
- Added real team dropdown backed by `/api/v1/mobile/ticket/teams`.
- CC email is validated locally and appended into the description because the
  current create-ticket API has no dedicated CC field.

### Follow-Up Ideas
- Replace static local tags with a mobile tag catalog endpoint when available.
- Add a dedicated backend CC field if notification semantics are required.

## Create Ticket Product UI

### User Idea
- Redesign the create-ticket UI because the first version had many alignment
  issues and did not look like a polished product screen.
- Make the UI consistent with the rest of VCloud's premium mobile design.

### Implemented Improvement
- Rebuilt the create-ticket screen around:
  - centered header
  - ticket gradient summary block
  - single white form panel
  - consistent field height, radius, border, icon, and spacing
  - Vietnamese labels and product-oriented microcopy
- Fixed header overlap where the title pill could touch the back button on small
  widths.
- Normalized input and dropdown alignment so icons, text, and field baselines
  feel consistent.

### Follow-Up Ideas
- Add screenshot-based visual regression checks for primary mobile breakpoints.
- Extract repeated form-field styling into a shared ticket/support form widget if
  more support screens are added.

## Description Composer and Documents

### User Idea
- The issue-description box looked bad and should be redesigned.
- Add a "Thêm tài liệu" button inside that chat/description input area.

### Implemented Improvement
- Replaced the plain multi-line text field with a composer-style description
  area:
  - message-style icon and placeholder alignment
  - inner action bar
  - inline "Thêm tài liệu" button
  - document chips with remove action
- The attachment picker opens real local choices for photo, camera, and
  document.
- After the backend added `/api/v1/mobile/attachments/upload`, selected files
  are uploaded after ticket creation with `res_model=helpdesk.ticket` and the
  created ticket id. Attachment metadata can be read from
  `/api/v1/mobile/attachments/{id}`.
- Chat and ticket contact cards now have repository methods for
  `/api/v1/mobile/chat/channels/{id}/contact` and
  `/api/v1/mobile/ticket/{id}/contact`.

### Follow-Up Ideas
- Surface uploaded attachment URLs in ticket detail when the detail endpoint
  includes attachment metadata.

## Native Media and File Access

### User Idea
- Let the mobile app use the phone camera, load images, and upload files from
  the device.

### Implemented Improvement
- Camera capture, gallery image selection, and document selection are wired into
  chat and create-ticket flows through `image_picker` and `file_picker`.
- Uploads go through `MobileAttachmentRepository` and
  `/api/v1/mobile/attachments/upload`, then attach to `discuss.channel` or
  `helpdesk.ticket` from the repository layer.
- Android and iOS declare the camera/photo access descriptions needed for real
  device pickers.

### Follow-Up Ideas
- Show uploaded ticket attachments in ticket detail once the detail endpoint
  returns attachment metadata.

## Ticket Detail Comments

### User Idea
- Ticket detail comments should appear automatically after a user comments.
- Users should not have to leave/reload the ticket detail screen to see a newly
  added comment.
- Comments should display the newest messages first and older messages below.
- The screen should show only a few comments first, with a button to reveal
  older comments, so the initial detail UI stays light.

### Implemented Improvement
- `TicketCommentRepository.watchByTicket` now refreshes comments periodically
  while the detail screen is open.
- `TicketCommentActions.add` invalidates the comment provider immediately after
  posting a comment.
- Ticket detail adds an optimistic local comment as soon as the user sends, shows
  it as "Đang gửi...", and replaces/removes it after server confirmation.
- Ticket detail listens for comment-count increases and scrolls to the newest
  comment.
- Comments are sorted newest-first before rendering.
- The UI initially renders a small newest comment window and reveals older
  comments locally via "Xem thêm bình luận cũ" without another network request.

### Follow-Up Ideas
- Replace HTTP polling with WebSocket/server-sent events if the backend exposes
  a real realtime channel for ticket messages.
- Add retry affordance on failed optimistic comments instead of only restoring
  the draft text.

## Ticket Detail Product UI

### User Idea
- Redesign ticket detail to focus on the same support fields as ticket creation:
  title, issue description, star priority, tag, CC email, handling team, and
  comments.

### Implemented Improvement
- Ticket detail no longer prioritizes timeline/activity blocks above the main
  support data.
- Added detail sections for title, issue description, read-only priority stars,
  tags, CC email, and handling team.
- Mapped tag labels from the mobile ticket `tags` payload into `Ticket.tagLabels`.
- Parsed CC email from structured description text until the backend exposes a
  dedicated field.

### Follow-Up Ideas
- Add dedicated backend fields for CC email and attachments so detail does not
  need to parse structured description text.
- Add real paginated comments if the backend exposes comment pagination.

## Documentation Practice

### User Idea
- Keep `SPEC.md`, `ARCH.md`, `implementation_plan.md`, and `AGENTS.md` updated.
- Create a separate idea/improvement file that records what ideas were suggested
  and what improvements were generated from them.

### Implemented Improvement
- Added this `IDEA_IMPROVE.md` log.
- Updated workflow docs with the 360 Support ticket boundary, create-ticket UI
  scope, and known backend limitations.

### Follow-Up Ideas
- Add a short "Decision Log" section per milestone when larger UX/API choices
  are made.

## Mobile Push Notification

### User Idea
- Backend `mobile_api` v19.0.2.5.0 now exposes FCM push notification support.
- Integrate the Flutter mobile app so it registers the device token after login
  and unregisters it on logout.

### Implemented Improvement
- Added Firebase Messaging dependencies and runtime Firebase configuration via
  `--dart-define`, keeping project-specific Firebase values out of committed
  secrets.
- Added `PushNotificationRepository` for
  `/api/v1/mobile/notifications/register` and
  `/api/v1/mobile/notifications/unregister`.
- Added `PushNotificationService` to initialize Firebase Messaging, request
  notification permission, persist a stable installation id, store the last FCM
  token, and call the repository.
- Wired auth restore/login/logout to register/unregister push devices while
  swallowing push errors so notification setup does not break app access.
- Added Android `POST_NOTIFICATIONS` permission for Android 13+ and repository
  tests for endpoint payloads.
- Loaded the Home bell with actionable in-app notification data from existing
  providers: unread chat conversations and open tickets. The sheet shows a
  badge count, supports manual refresh, and routes users directly to the
  relevant chat or ticket.

### Follow-Up Ideas
- Add a dedicated mobile notification list/read endpoint so the bell can show
  persisted push logs instead of deriving items from chat/ticket state.
- Add foreground in-app notification UI when product design decides how chat and
  ticket alerts should appear while VCloud is open.
- Add token-refresh re-registration once backend/device testing confirms the
  exact Firebase rotation behavior needed in production.

## Ticket Description and Comments

### User Idea
- A ticket's issue description and CC email must not reappear as the first
  comment immediately after creation.

### Implemented Improvement
- The mobile ticket-comment repository normalizes HTML and whitespace, then
  omits an Odoo chatter message only when its content exactly matches the
  ticket description. Real replies remain in the comment stream.

### Follow-Up Ideas
- Have the mobile ticket API expose an explicit message kind for initial
  descriptions so clients do not need content-based compatibility filtering.

## Attendance Real-Time Status

### User Idea
- Check-in/check-out status must update in the mobile app without a manual
  reload after moving the backend to Odoo v17 notifications.

### Implemented Improvement
- Home now prioritizes live attendance over a stale dashboard snapshot and
  refreshes that snapshot after a check-in/out toggle.
- The client refreshes attendance for foreground push payloads that identify an
  attendance event, with a 15-second fallback refresh while the provider is used.
- Odoo v17 `attendance_state` and `last_check_in` aliases are supported beside
  the established mobile endpoint fields.

### Follow-Up Ideas
- Expose and document an authenticated Odoo bus/WebSocket channel for mobile
  clients, then replace the attendance polling fallback with that subscription.
- Ensure a checked-in `/attendance/today` response includes
  `current_attendance_id`; `attendance_state` alone cannot identify the record
  required by the check-out endpoint.

## Chat Group Creation

### User Idea
- Check whether the app already has a create-group API.
- If the API exists, integrate it into the UI so users can create chat groups
  from the product screen.

### Implemented Improvement
- Confirmed `ChatRepository.createGroup` already calls
  `/api/v1/mobile/chat/groups` with `name` and `member_ids`.
- Connected the active chat screen's "Nhóm mới" action to a real group creation
  flow instead of the previous "sắp có" placeholder.
- Added a group composer sheet with group name, member search, selected-member
  count, member toggles, and a submit button.
- After creation, the app invalidates the conversation list and opens the newly
  created channel.
- Added repository test coverage for the mobile group endpoint and payload.

### Follow-Up Ideas
- Add a dedicated mobile user-search endpoint if `/api/v1/res.users` becomes
  too broad for large databases.
- Add avatar/channel metadata editing after group creation if the backend
  exposes those fields.

## Chat Pin and History Attachments

### User Idea
- Add message pinning in chat.
- Let users reopen older images and files that were already sent in a
  conversation.

### Implemented Improvement
- Added repository/application actions for chat message pin and unpin endpoints.
- The chat long-press menu now exposes "Ghim tin nhắn" and "Bỏ ghim tin nhắn".
- The pinned-message banner reads real `pinned_at` data from messages instead
  of relying on text prefixes.
- The chat info Media/File tabs now rebuild older images and documents from
  message attachment metadata, with image viewer and file download actions.

### Follow-Up Ideas
- Add server-side pagination/search for media and files if long conversations
  should load more history than the current message payload returns.
