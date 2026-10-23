-- Transaction-only fixtures: no real activity or notifications survive.
begin;
do $$
declare base public.projects%rowtype; project uuid:=gen_random_uuid(); actor uuid; member uuid; outsider uuid;
  entry uuid; post uuid; n int; member_count int;
begin
  select * into base from public.projects limit 1;
  if base.id is null then raise exception 'Requires a project fixture'; end if;
  actor:=base.user_id;
  select id into member from public.profiles where id<>actor limit 1;
  select id into outsider from public.profiles where id not in (actor,member) limit 1;
  if member is null or outsider is null then raise exception 'Requires three profiles'; end if;
  perform set_config('request.jwt.claim.sub',actor::text,true);
  insert into public.projects select (jsonb_populate_record(null::public.projects,to_jsonb(base) ||
    jsonb_build_object('id',project,'project_name','Activity notification test','community_links','[]'::jsonb,
      'shared_community_ids','[]'::jsonb,'share_friends',false,'timeline','[]'::jsonb,'materials_cost','[]'::jsonb,
      'project_type','collaborative','visibility','private'))).*;
  perform public.add_project_member(project,member,'project_member');
  if (select count(*) from public.project_notifications where project_id=project and user_id=member and activity_type='member_added')<>1 then
    raise exception 'New member needs exactly one alert'; end if;
  update public.projects set timeline='[{"id":"event1","name":"Workshop","start":"2026-10-18T10:00:00"}]' where id=project;
  update public.projects set timeline='[{"id":"event1","name":"Workshop","start":"2026-10-19T10:00:00"}]' where id=project;
  update public.projects set timeline='[{"id":"event1","name":"Updated workshop","start":"2026-10-19T10:00:00"}]' where id=project;
  update public.projects set timeline='[]' where id=project;
  update public.projects set materials_cost='[{"name":"Jar","cost":1}]' where id=project;
  update public.projects set materials_cost='[{"name":"Jar","cost":2}]' where id=project;
  update public.projects set problem_statement='Updated project details' where id=project;
  select count(*) into n from public.project_notifications where project_id=project;
  update public.projects set materials_cost=materials_cost,timeline=timeline,problem_statement=problem_statement,likes=likes+1 where id=project;
  if (select count(*) from public.project_notifications where project_id=project)<>n then
    raise exception 'No-op saves or likes generated alerts'; end if;
  insert into public.journal_entries(project_id,user_id,title,content,feed_ready)
    values(project,actor,'Draft test','[]',false) returning id into entry;
  if exists(select 1 from public.project_notifications where project_id=project and activity_type like 'journal_%') then
    raise exception 'Draft triggered notification'; end if;
  update public.journal_entries set feed_ready=true where id=entry;
  update public.journal_entries set title='Published update 1' where id=entry;
  update public.journal_entries set title='Published update 2' where id=entry;
  select count(*) into n from public.project_notifications where project_id=project;
  update public.journal_entries set updated_at=now() where id=entry;
  if (select count(*) from public.project_notifications where project_id=project)<>n then raise exception 'Timestamp autosave notified'; end if;
  insert into public.project_bulletin_posts(project_id,user_id,title,body,category)
    values(project,actor,'Test forum','Test body','Project Update') returning id into post;
  insert into public.project_bulletin_comments(post_id,user_id,body) values(post,actor,'Test reply');
  perform public.add_project_member(project,outsider,'project_member');
  perform public.set_project_member_role(project,member,'project_admin');
  perform public.remove_project_member(project,outsider);
  if not exists(select 1 from public.project_notifications where project_id=project and user_id=outsider and activity_type='member_removed') then
    raise exception 'Removed member should receive removal notice'; end if;
  select count(distinct activity_type) into n from public.project_notifications where project_id=project and user_id=member;
  if n<>13 then raise exception 'Expected 13 activity kinds, got %',n; end if;
  if (select count(*) from public.project_notifications where project_id=project and user_id=member and activity_type='journal_updated')<>1 then
    raise exception 'Journal edit notices did not coalesce'; end if;
  if (select count(*) from public.project_notifications where project_id=project and user_id=member and activity_type='materials_updated')<>1 then
    raise exception 'Material edit notices did not coalesce'; end if;
  if exists(select 1 from public.project_notifications where project_id=project and user_id=actor) then raise exception 'Actor notified themselves'; end if;
  select count(*) into member_count from public.project_notifications where project_id=project and user_id=outsider;
  update public.projects set problem_statement='After member removal' where id=project;
  if (select count(*) from public.project_notifications where project_id=project and user_id=outsider)<>member_count then
    raise exception 'Former member received later activity'; end if;
  if has_function_privilege('authenticated','public.emit_project_activity(uuid,text,text,text,uuid)','execute') then
    raise exception 'Clients must not be able to emit arbitrary notifications'; end if;
  if exists(select 1 from public.project_notifications where project_id=project and (actor_id<>actor or message not like '%Activity notification test.%')) then
    raise exception 'Actor or project context missing'; end if;
end;
$$;
rollback;
select 'Activity alerts: timeline, journal, materials, forum, membership, settings, recipients and edit grouping passed' as result;
