# CLAUDE.md — Project context for Claude Code

## What this is
VCloud — employee productivity app (Flutter + Supabase): chat · attendance ·
timesheet · tickets · dashboard. Vietnamese UI, premium "Refined Tech Luxury" design.

## Golden rules
1. **Presentation never touches Supabase.** Go through `features/<f>/data/*_repository.dart`.
2. **Keep `flutter analyze` at 0 errors / 0 warnings** before committing.
3. **Secrets via `--dart-define`**, never hard-code.
4. **DB changes = a new `supabase/migrations/NNNN_*.sql`**, never ad-hoc SQL.
5. Match the surrounding code's style, comment density, and naming.

## Layout
```
lib/core/        env · supabase client · theme (design tokens) · router · utils
lib/shared/      models · widgets (app_scaffold, ui_kit, empty/error/loading)
lib/features/<f>/{data, application, presentation}
supabase/migrations/   schema + RLS (source of truth)
docs/            PRD · ARCHITECTURE · PLAN · UI_FIX_PLAN
```

## Commands
```bash
flutter pub get
flutter analyze
flutter test
flutter build web --no-pub
```

## Flutter Skills (from ~/.agents/skills/)

The following skills are available at `~/.agents/skills/`. Read the SKILL.md
before using any skill:

| Skill | Use when |
|-------|----------|
| `flutter-add-widget-test` | Writing WidgetTester-based UI tests |
| `flutter-add-widget-preview` | Adding widget preview/support code |
| `flutter-add-integration-test` | Writing integration tests |
| `flutter-apply-architecture-best-practices` | Refactoring for clean architecture |
| `flutter-build-responsive-layout` | Making layouts responsive |
| `flutter-fix-layout-issues` | Debugging layout overflow/rendering bugs |
| `flutter-implement-json-serialization` | Adding JSON serialization (freezed/json_serializable) |
| `flutter-setup-declarative-routing` | Setting up go_router or auto_route |
| `flutter-setup-localization` | Adding i18n/l10n support |
| `flutter-use-http-package` | Using the http/dio package for API calls |

To use a skill, read its SKILL.md first:
```
Read ~/.agents/skills/flutter-<skill-name>/SKILL.md
```
