begin;
-- Public visitors receive only administrators, counts and public project data.
create or replace function public.public_community_profile(p_community_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb;
begin
 if not exists(select 1 from public.communities c where c.id=p_community_id and lower(c.visibility)='public') then
  raise exception 'This community profile is unavailable' using errcode='42501';
 end if;
 with community as (select * from public.communities where id=p_community_id),
 admins as (
  select created_by id,'owner'::text role from community
  union select m.user_id,m.role::text from public.community_members m
  where m.community_id=p_community_id and m.status='accepted' and m.role in ('owner','admin')
  and m.user_id<>(select created_by from community)
 ), members as (
  select created_by id from community union select user_id from public.community_members where community_id=p_community_id and status='accepted'
 ), projects as (
  select p.* from public.projects p where lower(p.visibility)='public'
  and exists(select 1 from jsonb_array_elements(coalesce(p.community_links,'[]'::jsonb)) l where l->>'id'=p_community_id::text)
 ), entries as (
  select e.* from public.journal_entries e join projects p on p.id=e.project_id
  where e.feed_ready and e.feed_public and e.feed_published_at is not null
  and exists(select 1 from jsonb_array_elements(e.content) x where x->>'stage' in ('free_notes','nextAction','reflection') and x->>'submitted'='true')
 ), points as (
  select e.id,e.project_id,coalesce(sum(i.eco_points),0) total from entries e
  left join public.impact_entries i on i.linked_journal_entry_id=e.id and i.project_id=e.project_id
  group by e.id,e.project_id
 ), subjects as (
  select coalesce(p.subject_domain,p.tags[1],'Other') subject,count(*) entries,sum(s.total) eco_points
  from points s join projects p on p.id=s.project_id group by 1
 )
 select jsonb_build_object(
  'member_count',(select count(*) from members),
  'admins',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'role',a.role,
    'display_name',u.display_name,'username',u.username,'avatar_url',u.avatar_url) order by a.role,a.id)
    from admins a left join public.profiles u on u.id=a.id),'[]'::jsonb),
  'completed_entries',(select count(*) from entries),
  'eco_points',(select coalesce(sum(total),0) from points),
  'progress',coalesce((select jsonb_agg(to_jsonb(s)) from subjects s),'[]'::jsonb),
  'projects',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'project_name',p.project_name,
    'project_image_url',p.project_image_url,'tags',p.tags,'subject_domain',p.subject_domain,
    'visibility',p.visibility,'journal_entries',jsonb_build_array(jsonb_build_object('count',(select count(*) from entries e where e.project_id=p.id)))) order by p.created_at desc) from projects p),'[]'::jsonb)
 ) into result;
 return result;
end $$;
revoke all on function public.public_community_profile(uuid) from public;
grant execute on function public.public_community_profile(uuid) to anon,authenticated;
-- Block roster reads outside accepted membership (including signed-in visitors).
create policy "Community roster requires membership" on public.community_members as restrictive for select to anon,authenticated
using(auth.uid() is not null and (user_id=auth.uid() or public.user_in_project_community(auth.uid(),community_id)));
commit;
