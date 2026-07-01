# implementation_plan.md - Odoo API Migration

## /spec
- [x] Capture OpenAPI-driven scope in `SPEC.md`.
- [x] Capture architecture changes in `ARCH.md`.
- [x] Document current Discuss/mobile chat API gaps from the attached OpenAPI
      contract.

## /plan
- [x] Replace Odoo API initialization with Odoo environment/session bootstrap.
- [x] Add reusable Odoo HTTP client and session store.
- [x] Replace Odoo JWT auth repository/controller types with app-local auth session types.
- [x] Convert attendance, ticket, chat, timesheet, task, profile, comments, and activity repositories to Odoo/mobile HTTP endpoints or safe local fallbacks.
- [x] Remove direct Odoo API references from presentation/application layers.
- [x] Update agent onboarding workflow in `AGENTS.md`.

## /build
- [x] Implement Dart/Flutter client integration for Odoo API.
- [x] Preserve existing UI/provider contracts where possible.
- [x] Map Discuss `ChatChannel` and `MessageInfo` fields into app chat models.
- [x] Wire chat mark-read to `/mobile/chat/channels/{channel_id}/mark-read`.
- [x] Map chat read-state fields for conversation previews, unread badges, and
      per-message read metadata.
- [x] Wire new mobile endpoints for auth profile/refresh/logout, chat
      direct/group/archive actions, ticket activities, dashboard summary,
      mobile avatars, and project task completion.

## /test
- [x] Run `flutter pub get`.
- [x] Run `flutter analyze`.
- [x] Run `flutter test`.
- [x] Add mapping coverage for mobile dashboard summary counters.

## /review
- [x] Audit for remaining Odoo API imports/direct backend calls.
- [x] Review failure handling and token persistence.

## /ship
- [x] Update `CHANGELOG.md`.
- [x] Cleanup generated dependency files after replacing `odoo_api_client` with `http`.
- [ ] Push branches `19.0` and `19.0-dev` when credentials/remotes are available.
