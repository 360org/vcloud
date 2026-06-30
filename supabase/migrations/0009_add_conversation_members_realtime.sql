-- Unread badges depend on conversation_members.unread_count.
-- The app already subscribes to this table; it must also be in the realtime
-- publication so recipients see new-message badges without manual refresh.

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.conversation_members;
    exception when duplicate_object then null;
    end;
  end if;
end$$;
