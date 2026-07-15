# implementation_plan.md - Odoo API Migration

## /spec
- [x] Capture OpenAPI-driven scope in `SPEC.md`.
- [x] Capture architecture changes in `ARCH.md`.
- [x] Document current Discuss/mobile chat API gaps from the attached OpenAPI
      contract.
- [x] Capture ticket create/get/list requirement to use 360 Support mobile
      ticket endpoints instead of direct `helpdesk.ticket` CRUD.
- [x] Capture create-ticket UI intake scope: title, issue description,
      star priority, tag, CC email, and handling team.
- [x] Capture mobile push notification API integration for FCM token
      register/unregister.
- [x] Capture Home bell notification-center behavior using unread chat and open
      ticket data until a notification-list API exists.
- [x] Capture chat pin-message and historical media/file browsing behavior.

## /plan
- [x] Replace Odoo API initialization with Odoo environment/session bootstrap.
- [x] Add reusable Odoo HTTP client and session store.
- [x] Replace Odoo JWT auth repository/controller types with app-local auth session types.
- [x] Convert attendance, ticket, chat, timesheet, task, profile, comments, and activity repositories to Odoo/mobile HTTP endpoints or safe local fallbacks.
- [x] Remove direct Odoo API references from presentation/application layers.
- [x] Update agent onboarding workflow in `AGENTS.md`.
- [x] Add a product-improvement log (`IDEA_IMPROVE.md`) for user-sourced ideas
      and implemented UI/API refinements.
- [x] Confirm the mobile chat group creation API is available and capture the
      UI integration requirement.
- [x] Plan push registration as auth-adjacent infrastructure with Firebase
      setup isolated from presentation.

## /build
- [x] Exclude the ticket-create description echoed by Odoo chatter from the
      user-comment stream while preserving actual replies.
- [x] Make attendance update immediately after a check-in/out, on foreground
      attendance notifications, and with a 15-second fallback refresh.
- [x] Implement Dart/Flutter client integration for Odoo API.
- [x] Preserve existing UI/provider contracts where possible.
- [x] Map Discuss `ChatChannel` and `MessageInfo` fields into app chat models.
- [x] Wire chat mark-read to `/mobile/chat/channels/{channel_id}/mark-read`.
- [x] Map chat read-state fields for conversation previews, unread badges, and
      per-message read metadata.
- [x] Wire new mobile endpoints for auth profile/refresh/logout, chat
      direct/group/archive actions, ticket activities, dashboard summary,
      mobile avatars, and project task completion.
- [x] Route ticket list/detail/create/team catalog through
      `/api/v1/mobile/ticket/*`.
- [x] Stop ticket create/get/list from calling direct `/api/v1/helpdesk.ticket`
      endpoints.
- [x] Add `ticketTeamsProvider` and `TicketTeamOption` for real team dropdown
      data.
- [x] Redesign create-ticket screen as a focused support intake form.
- [x] Add star priority selector, tag selection, CC email capture, team
      selection, and a composer-style issue description with inline
      "Thêm tài liệu" action.
- [x] Fix create-ticket header overlap/alignment and field spacing issues from
      visual review screenshots.
- [x] Make ticket detail comments auto-refresh while the screen is open and
      refresh immediately after sending a comment.
- [x] Add optimistic local rendering so a just-sent ticket comment appears
      immediately with a sending state before server confirmation.
- [x] Redesign ticket detail around support intake fields and map ticket tag
      labels from the mobile `tags` payload.
- [x] Sort ticket comments newest-first and render only a small newest window
      with local "Xem thêm bình luận cũ" expansion.
- [x] Integrate the main chat UI "Nhóm mới" action with the existing
      `/api/v1/mobile/chat/groups` repository action.
- [x] Add a product group composer with group name, member search, member
      selection, and create button.
- [x] Add Firebase Messaging configuration from `--dart-define` values.
- [x] Add `PushNotificationRepository` for
      `/api/v1/mobile/notifications/register` and
      `/api/v1/mobile/notifications/unregister`.
- [x] Register the current device after login/session restore and unregister
      the last known token before logout.
- [x] Load the Home bell with unread chat conversations and open tickets, with
      tap-through navigation to chat/ticket details.
- [x] Add chat pin/unpin repository actions and long-press message controls.
- [x] Rebuild chat info Media/File tabs from historical attachment metadata.

## /test
- [x] Add comment-stream coverage for a duplicate create-description message.
- [x] Add Odoo v17 `attendance_state` / `last_check_in` mapping coverage.
- [x] Run `flutter pub get`.
- [x] Run `flutter analyze`.
- [x] Run `flutter test`.
- [x] Add mapping coverage for mobile dashboard summary counters.
- [x] Add/refresh ticket repository tests to assert 360 Support create/get
      endpoint usage and prevent `helpdesk.ticket` regression.
- [x] Refresh create-ticket widget coverage for the simplified UI.
- [x] Re-run ticket/comment tests and `flutter analyze` after comment refresh
      changes.
- [x] Re-run ticket/comment tests and `flutter analyze` after ticket detail
      layout/comment window changes.
- [x] Add chat repository coverage for group creation endpoint and payload.
- [x] Add push notification repository coverage for register/unregister
      endpoint usage and payload mapping.
- [x] Add widget coverage for opening the Home notification sheet.
- [x] Add repository coverage for chat pin/unpin endpoint usage.

## /review
- [x] Verify Home prefers live attendance over a stale dashboard snapshot and
      refreshes that snapshot after a check-in/out action.
- [x] Audit for remaining Odoo API imports/direct backend calls.
- [x] Review failure handling and token persistence.
- [x] Review ticket repository for unsupported mobile mutations and explicit
      `Failure` messages.
- [x] Review create-ticket UI for product consistency, header spacing, input
      alignment, and composer affordance.
- [x] Review push integration for auth isolation, missing Firebase config, and
      presentation/backend boundary rules.
- [x] Review notification bell integration for provider-only data access and
      no direct backend calls from presentation.
- [x] Review chat pin/media actions for repository-only backend access.

## /ship
- [x] Update `CHANGELOG.md`.
- [x] Cleanup generated dependency files after replacing `odoo_api_client` with `http`.
- [x] Update `SPEC.md`, `ARCH.md`, `implementation_plan.md`, `AGENTS.md`, and
      `IDEA_IMPROVE.md` for ticket 360 Support/API/UI decisions.
- [x] Update workflow docs for chat group creation UI integration.
- [x] Add real mobile ticket attachment upload through
      `/api/v1/mobile/attachments/upload` after ticket creation.
- [x] Replace the placeholder "Thêm tài liệu" action with local file/photo/camera
      picking and upload selected files to `helpdesk.ticket`.
- [x] Add repository methods for chat/ticket contact card endpoints.
- [x] Integrate chat attachment UI icons with real gallery, camera, and document
      upload flows.
- [x] Declare Android/iOS camera and photo-library permissions for native
      camera/gallery pickers.
- [x] Update docs and changelog for mobile push notification integration.
- [x] Update docs and changelog for Home bell notification loading.
- [ ] Push branches `19.0` and `19.0-dev` when credentials/remotes are available.
