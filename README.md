# VCloud - Employee Productivity App

Flutter + Odoo Mobile API app: **chat - attendance - timesheet - tickets - dashboard**.
Vietnamese UI, premium mobile design.

## Stack
- **Flutter** 3.44+ / Dart 3.12+ - Material 3
- **Odoo Mobile API Gateway** - JWT auth and REST endpoints
- **Riverpod** for state management
- **GoRouter** for navigation
- **flutter_animate** + **lucide_flutter** for motion and icons

## Documentation
| Doc | Purpose |
|---|---|
| [SPEC.md](SPEC.md) | Odoo API integration spec |
| [ARCH.md](ARCH.md) | Current Odoo API architecture |
| [implementation_plan.md](implementation_plan.md) | Delivery workflow checklist |
| [AGENTS.md](AGENTS.md) | Onboarding for agents and devs |
| [CHANGELOG.md](CHANGELOG.md) | Release history |

## Run

### Native
```bash
flutter pub get
flutter run \
  --dart-define=VCLOUD_ODOO_API_BASE_URL=https://odoo.example.com \
  --dart-define=VCLOUD_ODOO_DB=production_db
```

### Web In Docker
```bash
ODOO_API_BASE_URL=https://odoo.example.com \
ODOO_DB=production_db \
docker compose -f docker-compose.web.yml up --build
```

Open [http://localhost:8080](http://localhost:8080).

### Android APK
See [AGENTS.md](AGENTS.md) for the Docker Android APK build recipe.

## Odoo Backend
1. Deploy the Odoo Mobile API Gateway matching OpenAPI version `19.0.1.0.0`.
2. Configure the mobile client with `VCLOUD_ODOO_API_BASE_URL` and optional `VCLOUD_ODOO_DB`.
3. Authenticate through `POST /api/v1/auth/login`; the app stores the JWT in secure storage.

## Project Layout
```text
lib/
  core/      api - config - theme - router - utils - error
  shared/    models - widgets
  features/  auth - chat - attendance - timesheet - ticket - home - profile
             each as {data, application, presentation}
docker/      Flutter web image + nginx config
docs/        product, design, and planning notes
```

## Verify
```bash
flutter analyze
flutter test
```
