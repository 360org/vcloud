# AGENTS.md — orientation for AI agents & developers

Onboarding for anyone (human or agent) working on VCloud. Read this first.

## What this is
VCloud — employee productivity app (Flutter + Supabase): chat · attendance ·
timesheet · tickets · dashboard. See [docs/PRD.md](docs/PRD.md),
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/PLAN.md](docs/PLAN.md).

## Golden rules
1. **Presentation never touches Supabase.** Go through `features/<f>/data/*_repository.dart`.
2. **Keep `flutter analyze` at 0 errors / 0 warnings** before committing.
3. **Secrets via `--dart-define`**, never hard-code in committed files (the existing
   default in `env.dart` is a known M2 cleanup item — don't add more).
4. **DB changes = a new `supabase/migrations/NNNN_*.sql`**, never ad-hoc SQL.
5. Match the surrounding code's style, comment density, and naming.

## Layout
```
lib/core/        env · supabase client · theme (design tokens) · router · utils
lib/shared/      models · widgets (app_scaffold, ui_kit, empty/error/loading)
lib/features/<f>/{data, application, presentation}
supabase/migrations/   schema + RLS (source of truth)
docs/            PRD · ARCHITECTURE · PLAN · MOBILE_UX_OPTIONS
```

## Commands

### Analyze / test (host, if Flutter installed)
```bash
flutter pub get
flutter analyze
flutter test
```

### No local Flutter? Use Docker (this repo's standard)
> Public Flutter images ship Dart 3.12.0 but the project targets ^3.12.2. Builds
> relax the SDK floor **inside the container only** — host pubspec stays intact.

**Run web (no toolchain needed):**
```bash
docker compose -f docker-compose.web.yml up --build   # → http://localhost:8080
```

**Analyze in Docker:**
```bash
docker run --rm -v "$PWD":/src:ro ghcr.io/cirruslabs/flutter:stable bash -c '
  cp -r /src /app && cd /app && rm -rf build .dart_tool pubspec.lock
  sed -i "s/\^3\.12\.2/'"'"'>=3.12.0 <4.0.0'"'"'/" pubspec.yaml
  flutter pub get >/dev/null && flutter analyze lib'
```

### Build Android APK
Release, debug-signed, arm64 → `dist/vcloud.apk`. The Docker VM must fit Gradle's
heap (the template sets `-Xmx8G`; lower it for an 8 GB VM or the daemon is OOM-killed):
```bash
docker run --rm -v "$PWD":/src:ro -v "$PWD/dist":/out ghcr.io/cirruslabs/flutter:stable bash -c '
  set -e; cp -r /src /app && cd /app && rm -rf build .dart_tool pubspec.lock
  sed -i "s/\^3\.12\.2/'"'"'>=3.12.0 <4.0.0'"'"'/" pubspec.yaml
  sed -i "s|^org.gradle.jvmargs=.*|org.gradle.jvmargs=-Xmx3G -XX:MaxMetaspaceSize=512m|" android/gradle.properties
  flutter pub get >/dev/null
  flutter build apk --release --target-platform android-arm64
  mkdir -p /out && cp build/app/outputs/flutter-apk/app-release.apk /out/vcloud.apk'
```

## Gotchas
- **`flutter build web` feels web-like** — that's the web target, not the framework.
  Real native feel = `flutter run` on a device / the APK above. See docs/MOBILE_UX_OPTIONS.md.
- **Service worker caches the web bundle** — after a rebuild, unregister SW + clear
  caches (or hard-reload) or you'll see the old bundle.
- **RLS recursion (42P17)** was fixed via a `SECURITY DEFINER` helper in migration 0002 —
  don't reintroduce self-referencing policies on `conversation_members`.
- **Tickets are self-assigned only** (code + RLS) — cross-user assignment is M4.

## Backend setup (Supabase)
1. Run `supabase/migrations/0001_init.sql` then `0002_fix_conversation_members_recursion.sql`.
2. Auth → Providers → Email: disable "Confirm email" (MVP only).
3. Auth → URL config: add `vcloud://login-callback`.
