-- Transaction-only fixtures. No project, membership, friendship or notification is retained.
begin;
do $$
declare owner_id uuid; friend_id uuid; member_id uuid; community_id uuid; project_id uuid; entry_id uuid; before_users uuid[];
begin
  select user_id into owner_id from public.projects limit 1;
  select id into friend_id from public.profiles where id<>owner_id limit 1;
  select id into member_id from public.profiles where id not in (owner_id,friend_id) limit 1;
  select id into community_id from public.communities limit 1;
  if member_id is null or community_id is null then raise exception 'Test requires three profiles and a community'; end if;
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  if not public.are_project_friends(owner_id,friend_id) then
    if exists(select 1 from public.friend_requests where (requester_id=owner_id and addressee_id=friend_id) or (requester_id=friend_id and addressee_id=owner_id)) then
      update public.friend_requests set status='accepted' where (requester_id=owner_id and addressee_id=friend_id) or (requester_id=friend_id and addressee_id=owner_id);
    else
      insert into public.friend_requests(requester_id,addressee_id,status) values(owner_id,friend_id,'accepted');
    end if;
  end if;
  insert into public.projects(user_id,project_name,problem_statement,tags,project_type,visibility)
    values(owner_id,'Audience transaction test','Testing audience boundaries',array['Environment'],'collaborative','Private') returning id into project_id;
  insert into public.journal_entries(project_id,user_id,title,content,feed_ready)
    values(project_id,owner_id,'Before sharing','[]'::jsonb,true) returning id into entry_id;
  perform set_config('request.jwt.claim.sub',friend_id::text,true);
  if public.can_view_project_audience(project_id) then raise exception 'Private project leaked to friend'; end if;
  if exists(select 1 from public.project_feed_for_audience(array[owner_id],null) where id=project_id) then raise exception 'Private entry leaked to friend feed'; end if;

  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  update public.projects set visibility='Friends',share_friends=true,shared_community_ids=array[community_id] where id=project_id;
  perform set_config('request.jwt.claim.sub',friend_id::text,true);
  if not public.can_view_project_audience(project_id) then raise exception 'Selected friends lack project access'; end if;
  if exists(select 1 from public.project_feed_for_audience(array[owner_id],null) where id=project_id) then raise exception 'Sharing retro-published an old entry'; end if;
  if (select community_id=any(feed_community_ids) from public.journal_entries where id=entry_id) then raise exception 'Community retro-published an old entry'; end if;

  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  update public.journal_entries set title='After sharing' where id=entry_id;
  perform set_config('request.jwt.claim.sub',friend_id::text,true);
  if not exists(select 1 from public.project_feed_for_audience(array[owner_id],null) where id=project_id) then raise exception 'Future update missing from friend feed'; end if;
  if not (select community_id=any(feed_community_ids) from public.journal_entries where id=entry_id) then raise exception 'Future update missing community snapshot'; end if;

  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  update public.projects set visibility='Private',share_friends=false,shared_community_ids='{}' where id=project_id;
  update public.journal_entries set title='Private before member joined' where id=entry_id;
  perform public.add_project_member(project_id,member_id,'project_member');
  perform set_config('request.jwt.claim.sub',member_id::text,true);
  if not public.can_view_project_audience(project_id) then raise exception 'Member lacks automatic private-project access'; end if;
  if exists(select 1 from public.project_feed_for_audience(null,null) where id=project_id) then raise exception 'Membership retro-published an old entry'; end if;
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  update public.journal_entries set title='After member joined' where id=entry_id;
  perform set_config('request.jwt.claim.sub',member_id::text,true);
  if not exists(select 1 from public.project_feed_for_audience(null,null) where id=project_id) then raise exception 'Member missing automatic feed update'; end if;
  perform set_config('request.jwt.claim.sub',friend_id::text,true);
  if public.can_view_project_audience(project_id) then raise exception 'Revoked friend retains access'; end if;
  if exists(select 1 from public.project_feed_for_audience(array[owner_id],null) where id=project_id) then raise exception 'Revoked friend retains feed update'; end if;

  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  update public.projects set community_links=jsonb_build_array(jsonb_build_object('id',community_id,'role','home')) where id=project_id;
  update public.journal_entries set title='Linked community update' where id=entry_id;
  if not (select community_id=any(feed_community_ids) from public.journal_entries where id=entry_id) then raise exception 'Linked community missing automatic feed update'; end if;
  select feed_user_ids into before_users from public.journal_entries where id=entry_id;
  update public.projects set visibility='Friends',share_friends=true where id=project_id;
  update public.journal_entries set title=title,content=content where id=entry_id;
  if (select feed_user_ids from public.journal_entries where id=entry_id) is distinct from before_users then raise exception 'No-op save retro-published an entry'; end if;
  -- Re-enabling friends must not resurrect a formerly eligible journal.
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  update public.projects set share_friends=false,community_links='[]'::jsonb where id=project_id;
  update public.projects set share_friends=true where id=project_id;
  perform set_config('request.jwt.claim.sub',friend_id::text,true);
  if exists(select 1 from public.project_feed_for_audience(array[owner_id],null) where id=project_id) then
    raise exception 'Re-enabled sharing resurrected an old journal';
  end if;
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  update public.journal_entries set feed_ready=false where id=entry_id;
  perform set_config('request.jwt.claim.sub',member_id::text,true);
  if exists(select 1 from public.project_feed_for_audience(null,null) where id=project_id) then raise exception 'Draft entry appears in feed'; end if;
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  update public.projects set visibility='Private',share_friends=false,community_links='[]'::jsonb,shared_community_ids='{}' where id=project_id;
  perform set_config('request.jwt.claim.sub',friend_id::text,true);
  execute 'set local role authenticated';
  if exists(select 1 from public.projects where id=project_id) then raise exception 'RLS exposed a private project to an unselected friend'; end if;
  if exists(select 1 from public.journal_entries where id=entry_id) then raise exception 'RLS exposed private journals to an unselected friend'; end if;
  perform set_config('request.jwt.claim.sub',member_id::text,true);
  if not exists(select 1 from public.projects where id=project_id) then raise exception 'RLS blocked an automatic project member'; end if;
  if not exists(select 1 from public.journal_entries where id=entry_id) then raise exception 'RLS blocked member journal access'; end if;
  execute 'reset role';
end;
$$;
rollback;
select 'Shared visibility, automatic member feeds, community snapshots, revocation, no retro-publishing, no-op saves and draft checks passed' as result;
