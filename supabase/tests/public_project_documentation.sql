begin;
do $$
declare p uuid; owner_id uuid; visitor uuid; published uuid:=gen_random_uuid(); draft uuid:=gen_random_uuid(); private_project uuid:=gen_random_uuid();
begin
 select id,user_id into p,owner_id from public.projects where user_id is not null limit 1;
 select id into visitor from auth.users where id<>owner_id limit 1;
 if p is null or visitor is null then raise exception 'Test requires a project and two users'; end if;
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 perform set_config('test.project',p::text,true);
 perform set_config('test.owner',owner_id::text,true);
 perform set_config('test.visitor',visitor::text,true);
 perform set_config('test.published',published::text,true);
 perform set_config('test.draft',draft::text,true);
 perform set_config('test.private',private_project::text,true);
 delete from public.project_collaborators where project_id=p and user_id=visitor;
 update public.projects set visibility='public',timeline='[{"id":"secret","name":"Internal planning secret"}]'::jsonb where id=p;
 insert into public.projects(id,user_id,project_name,problem_statement,tags,visibility)
 values(private_project,owner_id,'Private fixture','Internal project',array[]::text[],'private');
 insert into public.journal_entries(id,project_id,user_id,title,content,progress,feed_ready)
 values(published,p,owner_id,'Published notes','[{"stage":"free_notes","submitted":true,"linkedTimelineEvent":{"id":"secret","name":"Internal planning secret"}},{"type":"body","text":"Public observations"}]'::jsonb,'implementation',true),
 (draft,p,owner_id,'Private draft','[{"stage":"free_notes","submitted":false},{"type":"body","text":"Unfinished secret"}]'::jsonb,'implementation',false);
end; $$;
select set_config('request.jwt.claim.sub',current_setting('test.visitor'),true);
set local role authenticated;
do $$
begin
 assert not exists(select 1 from public.projects where id=current_setting('test.project')::uuid), 'Direct full project rows are protected';
 assert exists(select 1 from public.project_documentation where id=current_setting('test.project')::uuid and timeline is null), 'Nonmembers can see public docs without timeline';
 assert not exists(select 1 from public.project_documentation where id=current_setting('test.private')::uuid), 'Private projects remain private';
 assert not exists(select 1 from public.journal_entries where project_id=current_setting('test.project')::uuid), 'Raw journals cannot bypass redaction';
 assert exists(select 1 from public.journal_documentation where id=current_setting('test.published')::uuid and content::text not like '%Internal planning secret%'), 'Published content is visible without internal links';
 assert not exists(select 1 from public.journal_documentation where id=current_setting('test.draft')::uuid), 'Drafts remain internal';
 assert not exists(select 1 from public.project_activity_feed where project_id=current_setting('test.project')::uuid), 'Project history is internal';
 assert not exists(select 1 from public.project_bulletin_posts where project_id=current_setting('test.project')::uuid), 'Project forum is internal';
end; $$;
reset role;
select set_config('request.jwt.claim.sub','',true);
set local role anon;
do $$
begin
 assert exists(select 1 from public.project_documentation where id=current_setting('test.project')::uuid and timeline is null), 'Guests can browse public documentation';
 assert not exists(select 1 from public.project_documentation where id=current_setting('test.private')::uuid), 'Guests cannot see private projects';
 assert exists(select 1 from public.journal_documentation where id=current_setting('test.published')::uuid), 'Guests can read published entries';
 assert not exists(select 1 from public.journal_documentation where id=current_setting('test.draft')::uuid), 'Guests cannot read drafts';
 assert not exists(select 1 from public.communities where lower(visibility)<>'public'), 'Private communities remain private';
end; $$;
reset role;
select set_config('request.jwt.claim.sub',current_setting('test.owner'),true);
set local role authenticated;
do $$
begin
 assert exists(select 1 from public.projects where id=current_setting('test.project')::uuid and timeline::text like '%Internal planning secret%'), 'Owner retains full project data';
 assert exists(select 1 from public.journal_documentation where id=current_setting('test.draft')::uuid), 'Owner retains drafts';
end; $$;
reset role;
do $$
begin
 insert into public.project_collaborators(project_id,user_id,status,role)
 values(current_setting('test.project')::uuid,current_setting('test.visitor')::uuid,'accepted','project_member')
 on conflict(project_id,user_id) do update set status='accepted';
end; $$;
select set_config('request.jwt.claim.sub',current_setting('test.visitor'),true);
set local role authenticated;
do $$
begin
 assert exists(select 1 from public.projects where id=current_setting('test.project')::uuid and timeline::text like '%Internal planning secret%'), 'Accepted members retain timeline data';
 assert exists(select 1 from public.journal_documentation where id=current_setting('test.draft')::uuid), 'Accepted members retain draft access';
end; $$;
rollback;
