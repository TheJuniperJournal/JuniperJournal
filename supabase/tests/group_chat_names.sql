-- Temporary, uncommitted fixtures: no existing conversation is renamed.
begin;
do $$
declare users uuid[]; chat uuid; direct_chat uuid; community_chat uuid; community uuid;
begin
  select array_agg(id) into users from (select id from auth.users order by created_at limit 3) u;
  if cardinality(users)<3 then raise exception 'Three test users are required'; end if;
  insert into public.conversations(is_group,group_name) values(true,'Temporary group-name test') returning id into chat;
  insert into public.conversation_participants(conversation_id,user_id) values(chat,users[1]),(chat,users[2]);
  perform set_config('request.jwt.claim.sub',users[1]::text,true);
  perform public.rename_group_dm(chat,'  Garden team  ');
  if (select group_name from public.conversations where id=chat)<>'Garden team' then raise exception 'Group name was not trimmed and saved'; end if;
  begin
    perform public.rename_group_dm(chat,' ');
    raise exception 'Blank name accepted';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.rename_group_dm(chat,repeat('x',81));
    raise exception 'Long name accepted';
  exception when invalid_parameter_value then null; end;
  perform set_config('request.jwt.claim.sub',users[3]::text,true);
  begin
    perform public.rename_group_dm(chat,'Not allowed');
    raise exception 'Nonparticipant renamed group';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub',users[1]::text,true);
  insert into public.conversations(is_group) values(false) returning id into direct_chat;
  insert into public.conversation_participants(conversation_id,user_id) values(direct_chat,users[1]);
  begin
    perform public.rename_group_dm(direct_chat,'Not allowed');
    raise exception 'Direct chat renamed';
  exception when insufficient_privilege then null; end;
  select id into community from public.communities limit 1;
  if community is not null then
    insert into public.conversations(is_group,community_id) values(true,community) returning id into community_chat;
    insert into public.conversation_participants(conversation_id,user_id) values(community_chat,users[1]);
    begin
      perform public.rename_group_dm(community_chat,'Not allowed');
      raise exception 'Community chat renamed through DM endpoint';
    exception when insufficient_privilege then null; end;
  end if;
end;
$$;
rollback;
select 'Group names: save, trim, validation, membership and conversation-type checks passed' as result;
