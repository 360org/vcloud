# Changelog - vclients Frontend

## [2.4.0+28] - 2026-08-03
### Added
- Success SnackBar notifications and automatic `context.pop()` navigation after ticket status updates.

### Fixed
- Fixed RenderFlex 3.9px overflow in `_TicketActionBar` by adding `maxLines: 1` and `TextOverflow.ellipsis`.
- Safe parsing for system messages and `author_id == false` in `TicketComment.fromMap`.
- Fixed `isDone` status mapping in `_ticketFromOdoo` using `close_date` and `stage_id`.
