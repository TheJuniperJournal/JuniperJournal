begin;
create table public.project_audience_grants(
  project_id uuid not null references public.projects(id) on delete cascade,
  audience_key text not null,
  granted_at timestamptz not null default clock_timestamp(),
  primary key(project_id,audience_key)
);
alter table public.project_audience_grants enable row level security;
create or replace function public.sync_project_audience_grants()
returns trigger language plpgsql security definer set search_path=public as $$
declare keys text[];
begin
  select coalesce(array_agg(distinct key),'{}'::text[]) into keys from (
    select 'friends' key where new.share_friends and lower(coalesce(new.visibility,'')) in ('friends','shared')
    union select 'public' where lower(coalesce(new.visibility,''))='public'
    union select 'community:'||(l->>'id') from jsonb_array_elements(new.community_links) l
    union select 'community:'||c::text from unnest(new.shared_community_ids) c where lower(coalesce(new.visibility,'')) in ('friends','shared')
  ) k;
  delete from public.project_audience_grants where project_id=new.id and audience_key not like 'member:%' and not(audience_key=any(keys));
  insert into public.project_audience_grants(project_id,audience_key)
    select new.id,unnest(keys) on conflict do nothing;
  return new;
end;
$$;
create trigger sync_project_audience_grants after insert or update of visibility,share_friends,shared_community_ids,community_links
on public.projects for each row execute function public.sync_project_audience_grants();
create or replace function public.sync_project_member_feed_grant()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if TG_OP='DELETE' then
    delete from public.project_audience_grants where project_id=old.project_id and audience_key='member:'||old.user_id::text;
    return old;
  end if;
  if new.status='accepted' then
    insert into public.project_audience_grants(project_id,audience_key)
      values(new.project_id,'member:'||new.user_id::text) on conflict do nothing;
  else
    delete from public.project_audience_grants where project_id=new.project_id and audience_key='member:'||new.user_id::text;
  end if;
  return new;
end;
$$;
create trigger sync_project_member_feed_grant after insert or update or delete on public.project_collaborators
for each row execute function public.sync_project_member_feed_grant();
-- Initialize current access windows without publishing any old journals.
insert into public.project_audience_grants(project_id,audience_key)
select p.id,keys.key from public.projects p cross join lateral (
  select 'friends' key where p.share_friends and lower(coalesce(p.visibility,'')) in ('friends','shared')
  union select 'public' where lower(coalesce(p.visibility,''))='public'
  union select 'community:'||(l->>'id') from jsonb_array_elements(p.community_links) l
  union select 'community:'||c::text from unnest(p.shared_community_ids) c where lower(coalesce(p.visibility,'')) in ('friends','shared')
) keys on conflict do nothing;
insert into public.project_audience_grants(project_id,audience_key)
select project_id,'member:'||user_id::text from public.project_collaborators where status='accepted' on conflict do nothing;

create or replace function public.feed_grant_covers(p_project uuid,p_key text,p_published timestamptz)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.project_audience_grants g
    where g.project_id=p_project and g.audience_key=p_key and p_published>=g.granted_at);
$$;
revoke all on function public.feed_grant_covers(uuid,text,timestamptz) from public;
create or replace function public.journal_feed_entry_allowed(p_entry_id uuid,p_owner_ids uuid[],p_community_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.journal_entries e join public.projects p on p.id=e.project_id
 where e.id=p_entry_id and e.feed_ready and e.feed_published_at is not null and public.can_view_project_audience(p.id)
 and case when p_community_id is null then (
   (auth.uid()=any(e.feed_user_ids) and (
     p.user_id=auth.uid()
     or (public.is_project_member(p.id) and public.feed_grant_covers(p.id,'member:'||auth.uid()::text,e.feed_published_at))
     or (p.share_friends and public.are_project_friends(auth.uid(),p.user_id)
       and public.feed_grant_covers(p.id,'friends',e.feed_published_at))
     or exists(select 1 from unnest(e.feed_community_ids) c
       where public.user_in_project_community(auth.uid(),c)
       and (public.feed_grant_covers(p.id,'community:'||c::text,e.feed_published_at)
         or (e.feed_public and public.feed_grant_covers(p.id,'public',e.feed_published_at))))
   ))
   or (e.feed_public and p.user_id=any(coalesce(p_owner_ids,'{}'::uuid[]))
      and public.feed_grant_covers(p.id,'public',e.feed_published_at))
 ) else (
   p_community_id=any(e.feed_community_ids) and (
     public.feed_grant_covers(p.id,'community:'||p_community_id::text,e.feed_published_at)
     or (e.feed_public and public.feed_grant_covers(p.id,'public',e.feed_published_at))
   )
 ) end);
$$;
commit;
