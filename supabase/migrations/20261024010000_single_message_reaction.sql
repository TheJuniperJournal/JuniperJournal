begin;
-- Keep the latest emoji when a person previously chose several.
delete from public.message_emoji_reactions a using public.message_emoji_reactions b
 where a.target_id=b.target_id and a.user_id=b.user_id
 and (a.created_at,a.emoji)<(b.created_at,b.emoji);
alter table public.message_emoji_reactions drop constraint message_emoji_reactions_emoji_check;
alter table public.message_emoji_reactions add constraint message_emoji_reactions_emoji_check
 check(emoji in ('🌼','❤️','👍','😂','🎉','😮','😢','🙏','🌱'));
alter table public.message_emoji_reactions drop constraint message_emoji_reactions_pkey;
alter table public.message_emoji_reactions add primary key(target_id,user_id);
-- Preserve existing flower likes unless that person has chosen a newer emoji.
insert into public.message_emoji_reactions(target_id,user_id,emoji,created_at)
 select target_id,user_id,'🌼',created_at from public.message_flowers
 on conflict(target_id,user_id) do nothing;
create policy "Update own conversation emoji reaction" on public.message_emoji_reactions for update to authenticated
using(user_id=auth.uid() and exists(select 1 from public.messages m where m.id=target_id))
with check(user_id=auth.uid() and exists(select 1 from public.messages m where m.id=target_id));
grant update on public.message_emoji_reactions to authenticated;
create function public.toggle_message_reaction(p_target uuid,p_emoji text)
returns void language plpgsql security invoker set search_path=public as $$
declare actor uuid:=auth.uid(); previous text;
begin
 if actor is null or not exists(select 1 from public.messages where id=p_target) then
  raise exception 'Message unavailable' using errcode='42501';
 end if;
 if p_emoji not in ('🌼','❤️','👍','😂','🎉','😮','😢','🙏','🌱') or p_emoji is null then
  raise exception 'Unsupported reaction' using errcode='22023';
 end if;
 perform pg_advisory_xact_lock(hashtextextended(p_target::text||actor::text,0));
 select emoji into previous from public.message_emoji_reactions where target_id=p_target and user_id=actor;
 if previous=p_emoji then
  delete from public.message_emoji_reactions where target_id=p_target and user_id=actor;
 else
  insert into public.message_emoji_reactions(target_id,user_id,emoji) values(p_target,actor,p_emoji)
  on conflict(target_id,user_id) do update set emoji=excluded.emoji,created_at=clock_timestamp();
 end if;
end $$;
revoke all on function public.toggle_message_reaction(uuid,text) from public,anon;
grant execute on function public.toggle_message_reaction(uuid,text) to authenticated;
commit;
