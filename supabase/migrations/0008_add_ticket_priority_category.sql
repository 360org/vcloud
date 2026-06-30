-- Add ticket priority/category columns expected by the Flutter ticket model.

alter table public.tickets
  add column if not exists priority text not null default 'P3';

alter table public.tickets
  add column if not exists category text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'tickets_priority_check'
      and conrelid = 'public.tickets'::regclass
  ) then
    alter table public.tickets
      add constraint tickets_priority_check
      check (priority in ('P1', 'P2', 'P3', 'P4'));
  end if;
end$$;
