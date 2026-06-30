-- Migration 0003: Add ticket_comments table for ticket discussions
-- Run after 0001_init.sql and 0002_fix_conversation_members_recursion.sql

-- 1. Create ticket_comments table
create table if not exists public.ticket_comments (
  id         uuid primary key default gen_random_uuid(),
  ticket_id  uuid not null references public.tickets(id) on delete cascade,
  author_id  uuid not null references public.profiles(id) on delete cascade,
  content    text not null check (char_length(content) between 1 and 2000),
  created_at timestamptz not null default now()
);

-- 2. Index for efficient queries
create index idx_ticket_comments_ticket on public.ticket_comments(ticket_id, created_at);

-- 3. Enable RLS
alter table public.ticket_comments enable row level security;

-- 4. Select policy: ticket creator or assignee can read comments
create policy "ticket_comments_select" on public.ticket_comments
  for select using (
    ticket_id in (
      select id from public.tickets
      where created_by = auth.uid() or assigned_to = auth.uid()
    )
  );

-- 5. Insert policy: only authenticated users who have access to the ticket
create policy "ticket_comments_insert" on public.ticket_comments
  for insert with check (
    author_id = auth.uid() and
    ticket_id in (
      select id from public.tickets
      where created_by = auth.uid() or assigned_to = auth.uid()
    )
  );

-- 6. Update policy: only author can update their own comment
create policy "ticket_comments_update" on public.ticket_comments
  for update using (
    author_id = auth.uid()
  );

-- 7. Delete policy: author or ticket creator can delete comments
create policy "ticket_comments_delete" on public.ticket_comments
  for delete using (
    author_id = auth.uid() or
    ticket_id in (
      select id from public.tickets
      where created_by = auth.uid()
    )
  );
