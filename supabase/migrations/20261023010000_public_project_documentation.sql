begin;
grant execute on function public.is_project_participant(uuid) to anon;
-- Read projections keep internal columns out of nonmember responses. RLS alone
-- cannot hide a timeline column while exposing the same project row.
create or replace function public.project_documentation_json(p public.projects)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb;
begin
 if public.is_project_participant(p.id) then return to_jsonb(p); end if;
 select coalesce(jsonb_object_agg(key,value),'{}'::jsonb) into result
 from jsonb_each(to_jsonb(p)) where key=any(array[
 'id','project_name','user_id','created_at','updated_at','problem_statement','tags',
 'project_image_url','difficulty','subject_domain','progress','project_scale',
 'visibility','project_type','learning_objectives','likes','materials_cost','solution']);
 result:=result||jsonb_build_object('community_links',coalesce((
 select jsonb_agg(l) from jsonb_array_elements(coalesce(p.community_links,'[]'::jsonb)) l
 where exists(select 1 from communities c where c.id::text=l->>'id' and (lower(c.visibility)='public' or public.user_in_project_community(auth.uid(),c.id)))
 ),'[]'::jsonb));
 return result;
end; $$;
revoke all on function public.project_documentation_json(public.projects) from public;

create or replace function public.viewable_projects()
returns setof public.projects language sql stable security definer set search_path=public as $$
 select jsonb_populate_record(null::public.projects,public.project_documentation_json(p))
 from public.projects p where public.can_view_project_audience(p.id);
$$;
revoke all on function public.viewable_projects() from public;
grant execute on function public.viewable_projects() to anon,authenticated;

create or replace function public.strip_internal_journal_links(value jsonb)
returns jsonb language plpgsql immutable set search_path=public as $$
declare result jsonb;
begin
 if jsonb_typeof(value)='object' then
  select coalesce(jsonb_object_agg(key,public.strip_internal_journal_links(v)),'{}'::jsonb) into result
  from jsonb_each(value) e(key,v) where key not in ('linkedTimelineEvent','linkedTimelineEventId','linked_timeline_event','linked_timeline_event_id','timeline');
 elsif jsonb_typeof(value)='array' then
  select coalesce(jsonb_agg(public.strip_internal_journal_links(v) order by n),'[]'::jsonb) into result
  from jsonb_array_elements(value) with ordinality e(v,n);
 else return value;
 end if;
 return result;
end; $$;
revoke all on function public.strip_internal_journal_links(jsonb) from public;

create or replace function public.viewable_journal_entries()
returns setof public.journal_entries language sql stable security definer set search_path=public as $$
 select case when public.is_project_participant(e.project_id) then e else
 jsonb_populate_record(null::public.journal_entries,to_jsonb(e)||jsonb_build_object(
  'content',public.strip_internal_journal_links(e.content),
  'feed_user_ids','[]'::jsonb,'feed_community_ids','[]'::jsonb)) end
 from public.journal_entries e where public.can_view_project_audience(e.project_id)
 and (public.is_project_participant(e.project_id) or (
 e.feed_ready and e.feed_published_at is not null and exists(
 select 1 from jsonb_array_elements(e.content) s
 where s->>'stage' in ('nextAction','reflection','free_notes') and s->>'submitted'='true')
 and (auth.uid() is not null or (e.feed_public and exists(select 1 from projects p where p.id=e.project_id and lower(p.visibility)='public')))
 ));
$$;
revoke all on function public.viewable_journal_entries() from public;
grant execute on function public.viewable_journal_entries() to anon,authenticated;

-- Direct requests for the full stored rows are members-only, including requests
-- bypassing the app. Public clients use the redacted projections above.
create policy "Full project rows require membership" on public.projects as restrictive for select to anon,authenticated
 using(public.is_project_participant(id));
create policy "Full journal rows require membership" on public.journal_entries as restrictive for select to anon,authenticated
 using(public.is_project_participant(project_id));

create or replace function public.community_journal_entry_ids(p_project_id uuid,p_community_id uuid)
returns setof uuid language sql stable security definer set search_path=public as $$
 select e.id from public.journal_entries e join public.projects p on p.id=e.project_id
 where p.id=p_project_id and public.can_view_project_audience(p.id)
 and exists(select 1 from public.communities c where c.id=p_community_id
  and (lower(c.visibility)='public' or public.user_in_project_community(auth.uid(),c.id)))
 and e.feed_ready and e.feed_published_at is not null
 and exists(select 1 from jsonb_array_elements(e.content) s where s->>'stage' in ('nextAction','reflection','free_notes') and s->>'submitted'='true')
 and (
  (auth.uid() is not null and public.journal_feed_entry_allowed(e.id,null,p_community_id))
  or (lower(p.visibility)='public' and e.feed_public
   and exists(select 1 from jsonb_array_elements(coalesce(p.community_links,'[]'::jsonb)) l where l->>'id'=p_community_id::text))
 );
$$;
revoke all on function public.community_journal_entry_ids(uuid,uuid) from public;
grant execute on function public.community_journal_entry_ids(uuid,uuid) to anon,authenticated;

create or replace function public.public_project_directory(p_project_id uuid)
returns table(id uuid,display_name text,username text,avatar_url text)
language sql stable security definer set search_path=public as $$
 select u.id,u.display_name::text,u.username::text,u.avatar_url::text from public.profiles u
 where public.can_view_project_audience(p_project_id) and (
 exists(select 1 from public.projects p where p.id=p_project_id and p.user_id=u.id)
 or exists(select 1 from public.project_collaborators m where m.project_id=p_project_id and m.user_id=u.id and m.status='accepted')
 or exists(select 1 from public.viewable_journal_entries() e where e.project_id=p_project_id and e.user_id=u.id));
$$;
revoke all on function public.public_project_directory(uuid) from public;
grant execute on function public.public_project_directory(uuid) to anon,authenticated;

-- Preserve feed selection and sharing rules, but redact full project rows for
-- viewers who are not project participants.
create or replace function public.project_feed_for_audience(p_owner_ids uuid[] default null,p_community_id uuid default null)
returns setof public.projects language sql stable security definer set search_path=public as $$
 select jsonb_populate_record(null::public.projects,public.project_documentation_json(p)) from public.projects p
 join lateral(select max(e.feed_published_at) latest from public.journal_entries e
 where e.project_id=p.id and public.journal_feed_entry_allowed(e.id,p_owner_ids,p_community_id)) f on f.latest is not null
 where auth.uid() is not null and (p_community_id is null or public.user_in_project_community(auth.uid(),p_community_id)
 or exists(select 1 from public.communities c where c.id=p_community_id and lower(c.visibility)='public'))
 order by f.latest desc;
$$;
create policy "Project history requires membership" on public.project_activity_feed as restrictive for select to anon,authenticated
 using(public.is_project_participant(project_id));
create policy "Project forum requires membership" on public.project_bulletin_posts as restrictive for select to anon,authenticated
 using(public.is_project_participant(project_id));
create policy "Project discussion requires membership" on public.project_bulletin_comments as restrictive for select to anon,authenticated
 using(exists(select 1 from public.project_bulletin_posts p where p.id=post_id and public.is_project_participant(p.project_id)));
create policy "Project forum reactions require membership" on public.project_bulletin_reactions as restrictive for select to anon,authenticated
 using(exists(select 1 from public.project_bulletin_posts p where p.id=post_id and public.is_project_participant(p.project_id)));
-- Public impact documentation follows its completed journal projection.
drop policy if exists "Visitors read public journal impacts" on public.impact_entries;
drop policy if exists "Visitors enforce public journal impacts" on public.impact_entries;
create policy "Visitors read public impact documentation" on public.impact_entries for select to anon
 using(exists(select 1 from public.viewable_journal_entries() e where e.id=linked_journal_entry_id and e.project_id=impact_entries.project_id));
create policy "Impact documentation requires visible journal or membership" on public.impact_entries as restrictive for select to anon,authenticated
 using(public.is_project_participant(project_id) or exists(select 1 from public.viewable_journal_entries() e where e.id=linked_journal_entry_id and e.project_id=impact_entries.project_id));
create or replace view public.project_documentation as select * from public.viewable_projects();
create or replace view public.journal_documentation as select * from public.viewable_journal_entries();
revoke all on public.project_documentation,public.journal_documentation from public;
grant select on public.project_documentation,public.journal_documentation to anon,authenticated;
create policy "Journal writes require current membership" on public.journal_entries as restrictive for update to authenticated
 using(public.is_project_participant(project_id)) with check(public.is_project_participant(project_id));
create policy "Journal deletion requires current membership" on public.journal_entries as restrictive for delete to authenticated
 using(public.is_project_participant(project_id));
create or replace function public.community_documentation_projects(p_community_id uuid)
returns setof public.projects language sql stable security definer set search_path=public as $$
 select jsonb_populate_record(null::public.projects,public.project_documentation_json(p))
 from public.projects p where public.can_view_project_audience(p.id)
 and exists(select 1 from public.communities c where c.id=p_community_id and
 (lower(c.visibility)='public' or public.user_in_project_community(auth.uid(),c.id)))
 and (exists(select 1 from jsonb_array_elements(coalesce(p.community_links,'[]'::jsonb)) l where l->>'id'=p_community_id::text)
 or (lower(p.visibility) in ('friends','shared') and p_community_id=any(p.shared_community_ids)
 and public.user_in_project_community(auth.uid(),p_community_id)))
 order by p.created_at desc;
$$;
revoke all on function public.community_documentation_projects(uuid) from public;
grant execute on function public.community_documentation_projects(uuid) to anon,authenticated;
-- Public journal interactions remain available to signed-in viewers, without
-- granting them full raw journal rows or internal project discussion access.
create policy "Documentation viewers read journal likes" on public.journal_entry_likes for select to authenticated
 using(exists(select 1 from public.viewable_journal_entries() e where e.id=journal_entry_id));
create policy "Documentation viewers add journal likes" on public.journal_entry_likes for insert to authenticated
 with check(user_id=auth.uid() and exists(select 1 from public.viewable_journal_entries() e where e.id=journal_entry_id));
create policy "Documentation viewers read journal comments" on public.journal_entry_comments for select to authenticated
 using(exists(select 1 from public.viewable_journal_entries() e where e.id=journal_entry_id));
create policy "Documentation viewers add journal comments" on public.journal_entry_comments for insert to authenticated
 with check(user_id=auth.uid() and exists(select 1 from public.viewable_journal_entries() e where e.id=journal_entry_id));
create policy "Project forum changes require membership" on public.project_bulletin_posts as restrictive for all to authenticated
 using(public.is_project_participant(project_id)) with check(public.is_project_participant(project_id));
create policy "Project discussion changes require membership" on public.project_bulletin_comments as restrictive for all to authenticated
 using(exists(select 1 from public.project_bulletin_posts p where p.id=post_id and public.is_project_participant(p.project_id)))
 with check(exists(select 1 from public.project_bulletin_posts p where p.id=post_id and public.is_project_participant(p.project_id)));
create policy "Project forum reaction changes require membership" on public.project_bulletin_reactions as restrictive for all to authenticated
 using(exists(select 1 from public.project_bulletin_posts p where p.id=post_id and public.is_project_participant(p.project_id)))
 with check(exists(select 1 from public.project_bulletin_posts p where p.id=post_id and public.is_project_participant(p.project_id)));
commit;
