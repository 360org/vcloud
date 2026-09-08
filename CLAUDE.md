# CLAUDE.md - Project context for Claude Code

## What this is
VCloud - employee productivity app (Flutter + Odoo Mobile API): chat,
attendance, timesheet, tickets, dashboard. Vietnamese UI, premium
"Refined Tech Luxury" design.

## Golden rules
1. Keep the newest `main`; do not merge old backup/patches if they roll back working code.
2. Presentation never touches backend APIs. Go through `features/<f>/data/*_repository.dart` or application actions.
3. Keep `flutter analyze` at 0 errors / 0 warnings before committing.
4. Run targeted tests for small fixes; run `flutter test --exclude-tags=live-server` before release/large merges.
5. Secrets/tokens via CI secrets or `--dart-define`; never hard-code or log raw JWT/FCM/password values.
6. Odoo schema/server changes belong in the Odoo module repo, not this Flutter client.
7. Match the surrounding code's style, comment density, and naming; smallest safe diff wins.
8. New features follow `/spec -> /plan -> /build -> /test -> /review -> /ship`.
9. Full review checklist lives in `docs/AUDIT_ROADMAP.md`.

## Layout
```text
lib/core/        env - Odoo API client/session - theme - router - utils
lib/shared/      models - widgets (app_scaffold, ui_kit, empty/error/loading)
lib/features/<f>/{data, application, presentation}
docs/            PRD - ARCHITECTURE - PLAN - UI/design notes
```

## Commands
```bash
flutter pub get
flutter analyze
flutter test
flutter build web --no-pub
```
