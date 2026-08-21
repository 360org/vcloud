# CLAUDE.md - Project context for Claude Code

## What this is
VCloud - employee productivity app (Flutter + Odoo Mobile API): chat,
attendance, timesheet, tickets, dashboard. Vietnamese UI, premium
"Refined Tech Luxury" design.

## Golden rules
1. Presentation never touches backend APIs. Go through `features/<f>/data/*_repository.dart`.
2. Keep `flutter analyze` at 0 errors / 0 warnings before committing.
3. Secrets via `--dart-define`, never hard-code.
4. Odoo schema/server changes belong in the Odoo module repo, not this Flutter client.
5. Match the surrounding code's style, comment density, and naming.
6. New features follow `/spec -> /plan -> /build -> /test -> /review -> /ship`.

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
