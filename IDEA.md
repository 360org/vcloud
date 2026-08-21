# Idea & Architecture Notes - vclients

## Ticket Module UX & State Management
- **Repository**: `TicketRepository` maps Odoo Helpdesk data to `Ticket` models using `close_date` and `stage_id`.
- **UI & UX**: Action bar auto-resizes buttons with `Expanded` and `TextOverflow.ellipsis`. Navigation pops back automatically with floating SnackBar feedback on status change.
