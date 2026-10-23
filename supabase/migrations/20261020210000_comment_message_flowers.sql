-- One flower per person. Parent-table RLS controls visibility and permission to react.
begin;
create table public.project_comment_flowers (
  target_id uuid not null references public.project_comments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  created_at timestamptz not null default now(),
  primary key (target_id, user_id)
);
alter table public.project_comment_flowers enable row level security;
create policy "Read accessible flowers" on public.project_comment_flowers for select to authenticated
using (exists (select 1 from public.project_comments parent where parent.id = target_id));
create policy "Give own flower" on public.project_comment_flowers for insert to authenticated
with check (user_id = auth.uid() and exists (select 1 from public.project_comments parent where parent.id = target_id));
create policy "Remove own flower" on public.project_comment_flowers for delete to authenticated using (user_id = auth.uid());
grant select, insert, delete on public.project_comment_flowers to authenticated;
create table public.journal_comment_flowers (
  target_id uuid not null references public.journal_entry_comments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  created_at timestamptz not null default now(),
  primary key (target_id, user_id)
);
alter table public.journal_comment_flowers enable row level security;
create policy "Read accessible flowers" on public.journal_comment_flowers for select to authenticated
using (exists (select 1 from public.journal_entry_comments parent where parent.id = target_id));
create policy "Give own flower" on public.journal_comment_flowers for insert to authenticated
with check (user_id = auth.uid() and exists (select 1 from public.journal_entry_comments parent where parent.id = target_id));
create policy "Remove own flower" on public.journal_comment_flowers for delete to authenticated using (user_id = auth.uid());
grant select, insert, delete on public.journal_comment_flowers to authenticated;
create table public.community_comment_flowers (
  target_id uuid not null references public.bulletin_post_comments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  created_at timestamptz not null default now(),
  primary key (target_id, user_id)
);
alter table public.community_comment_flowers enable row level security;
create policy "Read accessible flowers" on public.community_comment_flowers for select to authenticated
using (exists (select 1 from public.bulletin_post_comments parent where parent.id = target_id));
create policy "Give own flower" on public.community_comment_flowers for insert to authenticated
with check (user_id = auth.uid() and exists (select 1 from public.bulletin_post_comments parent where parent.id = target_id));
create policy "Remove own flower" on public.community_comment_flowers for delete to authenticated using (user_id = auth.uid());
grant select, insert, delete on public.community_comment_flowers to authenticated;
create table public.collaboration_comment_flowers (
  target_id uuid not null references public.project_bulletin_comments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  created_at timestamptz not null default now(),
  primary key (target_id, user_id)
);
alter table public.collaboration_comment_flowers enable row level security;
create policy "Read accessible flowers" on public.collaboration_comment_flowers for select to authenticated
using (exists (select 1 from public.project_bulletin_comments parent where parent.id = target_id));
create policy "Give own flower" on public.collaboration_comment_flowers for insert to authenticated
with check (user_id = auth.uid() and exists (select 1 from public.project_bulletin_comments parent where parent.id = target_id));
create policy "Remove own flower" on public.collaboration_comment_flowers for delete to authenticated using (user_id = auth.uid());
grant select, insert, delete on public.collaboration_comment_flowers to authenticated;
create table public.message_flowers (
  target_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  created_at timestamptz not null default now(),
  primary key (target_id, user_id)
);
alter table public.message_flowers enable row level security;
create policy "Read accessible flowers" on public.message_flowers for select to authenticated
using (exists (select 1 from public.messages parent where parent.id = target_id));
create policy "Give own flower" on public.message_flowers for insert to authenticated
with check (user_id = auth.uid() and exists (select 1 from public.messages parent where parent.id = target_id));
create policy "Remove own flower" on public.message_flowers for delete to authenticated using (user_id = auth.uid());
grant select, insert, delete on public.message_flowers to authenticated;
commit;
