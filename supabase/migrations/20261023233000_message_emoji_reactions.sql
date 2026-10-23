begin;
create table public.message_emoji_reactions (
 target_id uuid not null references public.messages(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
 emoji text not null check (emoji in ('❤️','👍','😂','🎉','😮','😢','🙏','🌱')),
 created_at timestamptz not null default now(),
 primary key(target_id,user_id,emoji)
);
alter table public.message_emoji_reactions enable row level security;
create policy "Read conversation emoji reactions" on public.message_emoji_reactions for select to authenticated
using (exists(select 1 from public.messages m where m.id=target_id));
create policy "Add own conversation emoji reaction" on public.message_emoji_reactions for insert to authenticated
with check(user_id=auth.uid() and exists(select 1 from public.messages m where m.id=target_id));
create policy "Remove own conversation emoji reaction" on public.message_emoji_reactions for delete to authenticated
using(user_id=auth.uid() and exists(select 1 from public.messages m where m.id=target_id));
grant select,insert,delete on public.message_emoji_reactions to authenticated;
-- Send only changes the subscriber can read through conversation RLS.
alter publication supabase_realtime add table public.message_emoji_reactions;
commit;
