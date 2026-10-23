begin;
create table public.journal_entry_likes (
 journal_entry_id uuid not null references public.journal_entries(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(journal_entry_id,user_id)
);
create table public.journal_entry_comments (
 id uuid primary key default gen_random_uuid(),
 journal_entry_id uuid not null references public.journal_entries(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 content text not null check(length(trim(content)) between 1 and 5000),
 created_at timestamptz not null default now()
);
create index journal_entry_comments_entry_idx on public.journal_entry_comments(journal_entry_id,created_at);
alter table public.journal_entry_likes enable row level security;
alter table public.journal_entry_comments enable row level security;
create policy "Entry viewers read likes" on public.journal_entry_likes for select to authenticated using(exists(select 1 from public.journal_entries e where e.id=journal_entry_id));
create policy "Entry viewers add own likes" on public.journal_entry_likes for insert to authenticated with check(user_id=auth.uid() and exists(select 1 from public.journal_entries e where e.id=journal_entry_id));
create policy "Users remove own likes" on public.journal_entry_likes for delete to authenticated using(user_id=auth.uid());
create policy "Entry viewers read comments" on public.journal_entry_comments for select to authenticated using(exists(select 1 from public.journal_entries e where e.id=journal_entry_id));
create policy "Entry viewers add own comments" on public.journal_entry_comments for insert to authenticated with check(user_id=auth.uid() and exists(select 1 from public.journal_entries e where e.id=journal_entry_id));
grant select,insert,delete on public.journal_entry_likes to authenticated;
grant select,insert on public.journal_entry_comments to authenticated;
commit;
