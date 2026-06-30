-- ===========================================================================
-- 0011_extend_duration_enum.sql
-- Add '45m' to the timesheet_duration enum so the new quick preset
-- (15 / 30 / 45 / 60) can be saved without a Round-Trip through minutes.
--
-- '2h' is intentionally kept: postgres has no DROP VALUE on enums, and any
-- existing rows still need to read. The Dart model stops emitting '2h' and
-- reads it back as '1h' (orElse).
-- ===========================================================================

alter type public.timesheet_duration add value if not exists '45m';
