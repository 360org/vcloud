-- ===========================================================================
-- 0010_add_tasks.sql
-- Daily task list + linking timesheet entries to a task.
-- ===========================================================================

-- ---- tasks ----------------------------------------------------------------
create table if not exists public.tasks (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  title        text not null check (char_length(title) between 1 and 200),
  description  text,
  category     public.timesheet_category not null default 'Other',
  due_date     date not null default current_date,
  completed_at timestamptz,
  timesheet_id uuid,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists tasks_user_due_idx  on public.tasks(user_id, due_date);
create index if not exists tasks_user_done_idx on public.tasks(user_id, completed_at);

drop trigger if exists tasks_touch on public.tasks;
create trigger tasks_touch before update on public.tasks
  for each row execute function public.touch_updated_at();

-- ---- link timesheets.tasks -> tasks.id ------------------------------------
alter table public.timesheets
  add column if not exists task_id uuid references public.tasks(id) on delete set null;
create index if not exists timesheets_task_idx on public.timesheets(task_id);

-- ---- row-level security ---------------------------------------------------
alter table public.tasks enable row level security;

drop policy if exists "tasks self" on public.tasks;
create policy "tasks self"
  on public.tasks for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---- realtime publication -------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.tasks;
    exception when duplicate_object then null;
    end;
  end if;
end$$;
