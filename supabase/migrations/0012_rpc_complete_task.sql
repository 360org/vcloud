-- ===========================================================================
-- 0012_rpc_complete_task.sql
-- Atomically mark a task complete AND insert the linked timesheet row.
-- Returns the updated `tasks` row so the client can re-render immediately.
-- ===========================================================================

create or replace function public.complete_task(
  p_task     uuid,
  p_duration public.timesheet_duration,
  p_summary  text,
  p_user     uuid
) returns public.tasks
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ts_id     uuid;
  v_category  public.timesheet_category;
  v_result    public.tasks;
begin
  -- Lock the task row to avoid a double-completion race.
  select category into v_category
    from public.tasks
   where id = p_task and user_id = p_user
   for update;
  if not found then
    raise exception 'Task not found or not owned by user %', p_user
      using errcode = '42501';
  end if;

  insert into public.timesheets
        (user_id, task_name, category, duration, task_id)
  values (p_user, p_summary, v_category, p_duration, p_task)
  returning id into v_ts_id;

  update public.tasks
     set completed_at = now(),
         timesheet_id = v_ts_id,
         updated_at   = now()
   where id = p_task
  returning * into v_result;

  return v_result;
end;
$$;

-- Authorised callers (the owning user, authenticated). RLS on `tasks` and
-- `timesheets` still applies to direct SELECT/UPDATE — this RPC merely runs
-- as the function owner for the duration of the transaction.
revoke all on function public.complete_task(uuid, public.timesheet_duration, text, uuid) from public;
grant execute on function public.complete_task(uuid, public.timesheet_duration, text, uuid) to authenticated;
