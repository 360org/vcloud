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
- `Env.odooApiBaseUrl` and `Env.odooDb` provide runtime configuration.
- `OdooSessionStore` persists `access_token`, `uid`, `db`, `login`, and expiry metadata using `flutter_secure_storage`.
- `OdooApiClient` attaches `Authorization: Bearer <token>` to authenticated requests and converts non-2xx responses into `Failure`.
- Odoo domain/list endpoints are accessed through typed repository methods, not from widgets.

## Auth Model
`AuthUser` is the app-local user/session identity. It intentionally exposes the small shape the UI needs:
- `id`
- `email`
- `userMetadata`

This keeps UI code stable without importing backend SDK types.

## Refresh Model
Repositories emit an initial HTTP snapshot and application actions invalidate providers after mutations. Polling or WebSocket support can be added later behind the same repository contracts.

## Data Mapping
Odoo uses integer IDs and snake_case fields. Existing Flutter models keep their public shape, while `fromMap` factories accept normalized maps from repositories:
- IDs are converted to strings.
- Odoo date fields map to app date fields.
- Stage/priority/status values are normalized for current UI enums.

## Security
Secrets and environment-specific hostnames stay out of committed code. JWTs are stored only in secure storage.
