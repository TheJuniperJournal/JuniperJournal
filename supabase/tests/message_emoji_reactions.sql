begin;
do $$
declare message_id uuid; sender uuid; outsider uuid;
begin
 select id,sender_id into message_id,sender from public.messages limit 1;
 assert message_id is not null,'Requires a message fixture';
 perform set_config('request.jwt.claim.sub',sender::text,true);
 set local role authenticated;
 insert into public.message_emoji_reactions(target_id,user_id,emoji) values(message_id,sender,'🎉') on conflict do nothing;
 assert exists(select 1 from public.message_emoji_reactions where target_id=message_id and emoji='🎉'),'Reaction must persist';
 begin
  insert into public.message_emoji_reactions(target_id,user_id,emoji) values(message_id,gen_random_uuid(),'👍');
  raise exception 'Spoofed reaction accepted';
 exception when insufficient_privilege then null; end;
 delete from public.message_emoji_reactions where target_id=message_id and user_id=sender and emoji='🎉';
 assert not exists(select 1 from public.message_emoji_reactions where target_id=message_id and emoji='🎉' and user_id=sender),'Own reaction can be removed';
end $$;
rollback;
