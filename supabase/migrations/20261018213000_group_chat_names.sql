begin;
create or replace function public.rename_group_dm(p_conversation_id uuid, p_name text)
returns void language plpgsql security definer set search_path=public as $$
declare cleaned text := btrim(p_name);
begin
  if auth.uid() is null then raise exception 'Sign in to rename a group chat' using errcode='42501'; end if;
  if cleaned is null or char_length(cleaned)=0 or char_length(cleaned)>80 then
    raise exception 'Group names must contain 1 to 80 characters' using errcode='22023';
  end if;
  if not exists (
    select 1 from public.conversations c
    join public.conversation_participants cp on cp.conversation_id=c.id
    where c.id=p_conversation_id and c.is_group and c.community_id is null and cp.user_id=auth.uid()
  ) then raise exception 'Only participants can rename this group chat' using errcode='42501'; end if;
  update public.conversations set group_name=cleaned where id=p_conversation_id;
end;
$$;
revoke all on function public.rename_group_dm(uuid,text) from public;
grant execute on function public.rename_group_dm(uuid,text) to authenticated;
commit;
