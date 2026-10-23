begin;
do $$
declare project uuid; owner_id uuid; count_before bigint; count_after bigint;
begin
 select id,user_id into project,owner_id from public.projects where user_id is not null limit 1;
 if project is null then raise exception 'Test requires a project'; end if;
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 perform set_config('test.activity_project',project::text,true);
 update public.projects set visibility='public' where id=project;
 select count(*) into count_before from public.project_activity_feed where project_id=project and source_id='feed-test-source';
 perform public.record_project_feed_event(project,'materials_updated','feed-test-source','updated materials');
 perform public.record_project_feed_event(project,'materials_updated','feed-test-source','updated materials again');
 select count(*) into count_after from public.project_activity_feed where project_id=project and source_id='feed-test-source';
 perform public.record_project_feed_event(project,'project_updated','feed-test-public','updated project details');
 assert count_after=count_before+1,'Repeated edits must group into one event';
 assert exists(select 1 from public.project_activity_feed where project_id=project and source_id='feed-test-source' and description='updated materials again'), 'Latest edit must replace old description';
end;
$$;
-- The client has read-only access; only database triggers may write activity.
select set_config('request.jwt.claim.sub','',true);
set local role authenticated;
do $$
begin
 assert not exists(select 1 from public.project_activity_feed
   where project_id=current_setting('test.activity_project')::uuid and source_id='feed-test-source'),
   'Nonparticipants must not see internal materials activity';
 assert not exists(select 1 from public.project_activity_feed
   where project_id=current_setting('test.activity_project')::uuid and source_id='feed-test-public'),
   'Project activity must remain internal even for public projects';
 assert not exists(select 1 from public.project_activity_feed where kind like 'journal_draft_%'),
   'Nonparticipants must not see draft activity';
 begin
  insert into public.project_activity_feed(project_id,actor_name,kind,description)
   values(gen_random_uuid(),'Spoofed actor','project_updated','spoofed update');
  raise exception 'Client inserted spoofed activity';
 exception when insufficient_privilege then null;
 end;
end;
$$;
rollback;
