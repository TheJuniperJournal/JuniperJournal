-- All fixtures and notifications are rolled back; no user is notified by this test.
begin;
do $$
declare p public.projects%rowtype; person uuid; community uuid; before_count int; after_count int;
begin
  if public.valid_project_community_links('[{"id":"a","role":"home"},{"id":"b","role":"home"}]'::jsonb) then
    raise exception 'Multiple home communities must be rejected';
  end if;
  if not public.valid_project_community_links('[{"id":"a","role":"home"},{"id":"b","role":"collaborator"}]'::jsonb) then
    raise exception 'One home with collaborators must be allowed';
  end if;
  select * into p from public.projects where project_type='collaborative' limit 1;
  if p.id is null then raise exception 'A collaborative project is needed for this test'; end if;
  perform set_config('request.jwt.claim.sub',p.user_id::text,true);
  select id into person from public.profiles where id<>p.user_id
    and not exists(select 1 from public.project_collaborators pc where pc.project_id=p.id and pc.user_id=profiles.id) limit 1;
  if person is null then raise exception 'An unassigned profile is needed for this test'; end if;
  select count(*) into before_count from public.project_notifications where project_id=p.id and user_id=person;
  perform public.add_project_member(p.id,person,'project_member');
  if not exists(select 1 from public.project_collaborators where project_id=p.id and user_id=person and status='accepted') then
    raise exception 'Added member is not accepted';
  end if;
  select count(*) into after_count from public.project_notifications where project_id=p.id and user_id=person;
  if after_count<>before_count+1 then raise exception 'Missing member notification'; end if;
  perform public.add_project_member(p.id,person,'project_member');
  if (select count(*) from public.project_notifications where project_id=p.id and user_id=person)<>after_count then
    raise exception 'Duplicate member notification';
  end if;
  perform set_config('request.jwt.claim.sub',person::text,true);
  begin
    perform public.set_project_member_role(p.id,person,'project_admin');
    raise exception 'Member may not promote themselves';
  exception when raise_exception then
    if SQLERRM='Member may not promote themselves' then raise; end if;
  end;
  perform set_config('request.jwt.claim.sub',p.user_id::text,true);
  select id into community from public.communities c where not exists(
    select 1 from jsonb_array_elements(p.community_links) link where link->>'id'=c.id::text) limit 1;
  if community is not null then
    select count(*) into before_count from public.project_notifications where project_id=p.id and community_id=community;
    update public.projects set community_links=community_links || jsonb_build_array(jsonb_build_object('id',community,'role','collaborator')) where id=p.id;
    select count(*) into after_count from public.project_notifications where project_id=p.id and community_id=community;
    if after_count<=before_count then raise exception 'Missing community notifications'; end if;
    update public.projects set community_links=community_links where id=p.id;
    if (select count(*) from public.project_notifications where project_id=p.id and community_id=community)<>after_count then
      raise exception 'Duplicate community notification';
    end if;
  end if;
end;
$$;
rollback;
select 'Project addition, notification, deduplication, role and home restriction checks passed' as result;
