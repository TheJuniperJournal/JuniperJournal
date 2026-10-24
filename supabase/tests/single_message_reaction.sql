begin;
do $$
declare target uuid; actor uuid;
begin
 select id,sender_id into target,actor from public.messages limit 1;
 assert target is not null,'Requires message fixture';
 perform set_config('request.jwt.claim.sub',actor::text,true);
 set local role authenticated;
 delete from public.message_emoji_reactions where target_id=target and user_id=actor;
 perform public.toggle_message_reaction(target,'🎉');
 perform public.toggle_message_reaction(target,'🙏');
 assert (select count(*) from public.message_emoji_reactions where target_id=target and user_id=actor)=1,'Only one reaction allowed';
 assert exists(select 1 from public.message_emoji_reactions where target_id=target and user_id=actor and emoji='🙏'),'Selection replaces previous emoji';
 perform public.toggle_message_reaction(target,'🌼');
 assert exists(select 1 from public.message_emoji_reactions where target_id=target and user_id=actor and emoji='🌼'),'Like replaces another emoji';
 assert (select count(*) from public.message_emoji_reactions where target_id=target and user_id=actor)=1,'Like shares the same slot';
 perform public.toggle_message_reaction(target,'🌼');
 assert not exists(select 1 from public.message_emoji_reactions where target_id=target and user_id=actor),'Selecting same reaction removes it';
 begin
  perform public.toggle_message_reaction(target,'invalid');
  raise exception 'Invalid emoji accepted';
 exception when invalid_parameter_value then null; end;
end $$;
rollback;
