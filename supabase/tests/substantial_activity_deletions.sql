-- Transaction-only regression checks: restore every fixture and its dependent rows.
begin;
do $$
declare entry public.journal_entries%rowtype; actor uuid; event_count bigint; deletion_kind text;
begin
 select * into entry from public.journal_entries limit 1;
 assert entry.id is not null,'Requires a journal fixture';
 select id into actor from auth.users where id<>entry.user_id limit 1;
 assert actor is not null,'Requires a second account';
 perform set_config('request.jwt.claim.sub',actor::text,true);
 deletion_kind:=case when entry.feed_ready then 'journal_deleted' else 'journal_draft_deleted' end;
 delete from public.journal_entries where id=entry.id;
 assert exists(select 1 from public.project_activity_feed where source_id=entry.id::text
   and kind=deletion_kind and journal_entry_id is null and actor_id=actor
   and description like 'deleted%'),'Deletion must survive without a deleted-entry FK';
 assert exists(select 1 from public.project_notifications where source_id=entry.id::text
   and activity_type=deletion_kind and actor_id=actor and user_id=entry.user_id),
   'Other project members must receive an explicit deletion notification';
 select count(*) into event_count from public.project_activity_feed where project_id=entry.project_id;
 update public.projects set project_name=project_name where id=entry.project_id;
 assert event_count=(select count(*) from public.project_activity_feed where project_id=entry.project_id),
   'No-op project updates must not generate activity';
end $$;
rollback;
