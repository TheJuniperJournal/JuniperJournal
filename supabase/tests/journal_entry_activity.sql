-- Run against an existing journal. All fixture writes are rolled back.
begin;
do $$
declare eid uuid; uid uuid; n int;
begin
 select id,user_id into eid,uid from public.journal_entries where user_id is not null limit 1;
 if eid is null then raise exception 'No journal fixture available'; end if;
 perform set_config('request.jwt.claim.sub',uid::text,true);
 set local role authenticated;
 insert into public.journal_entry_likes(journal_entry_id,user_id) values(eid,uid) on conflict do nothing;
 select count(*) into n from public.journal_entry_likes where journal_entry_id=eid and user_id=uid;
 if n<>1 then raise exception 'Like read failed'; end if;
 insert into public.journal_entry_comments(journal_entry_id,user_id,content) values(eid,uid,'Transaction-only interaction check');
 select count(*) into n from public.journal_entry_comments where journal_entry_id=eid and content='Transaction-only interaction check';
 if n<1 then raise exception 'Comment read failed'; end if;
end $$;
rollback;
