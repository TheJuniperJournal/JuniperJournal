begin;
alter table public.projects
  add column if not exists share_friends boolean not null default false,
  add column if not exists shared_community_ids uuid[] not null default '{}';
alter table public.journal_entries
  add column if not exists feed_ready boolean not null default false,
  add column if not exists feed_user_ids uuid[] not null default '{}',
  add column if not exists feed_community_ids uuid[] not null default '{}',
  add column if not exists feed_public boolean not null default false,
  add column if not exists feed_published_at timestamptz;

create or replace function public.user_in_project_community(p_user uuid,p_community uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.communities c where c.id=p_community and c.created_by=p_user)
    or exists(select 1 from public.community_members cm where cm.community_id=p_community and cm.user_id=p_user and cm.status='accepted');
$$;
create or replace function public.are_project_friends(a uuid,b uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.friend_requests f where f.status='accepted'
    and ((f.requester_id=a and f.addressee_id=b) or (f.requester_id=b and f.addressee_id=a)));
$$;
create or replace function public.can_view_project_audience(p_project_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.projects p where p.id=p_project_id and (
    p.user_id=auth.uid()
    or public.is_project_member(p.id)
    or lower(coalesce(p.visibility,''))='public'
    or exists(select 1 from jsonb_array_elements(p.community_links) l
      where public.user_in_project_community(auth.uid(),(l->>'id')::uuid))
    or (lower(coalesce(p.visibility,'')) in ('friends','shared') and (
      (p.share_friends and public.are_project_friends(auth.uid(),p.user_id))
      or exists(select 1 from unnest(p.shared_community_ids) c where public.user_in_project_community(auth.uid(),c))
    ))
  ));
$$;
create or replace function public.snapshot_journal_feed_audience()
returns trigger language plpgsql security definer set search_path=public as $$
declare p public.projects%rowtype; communities uuid[];
begin
  if TG_OP='UPDATE' then
    -- Autosaves that have no content change must not republish old entries.
    if new.content is not distinct from old.content and new.title is not distinct from old.title
      and new.progress is not distinct from old.progress and new.feed_ready is not distinct from old.feed_ready then
      new.feed_user_ids:=old.feed_user_ids; new.feed_community_ids:=old.feed_community_ids;
      new.feed_public:=old.feed_public; new.feed_published_at:=old.feed_published_at;
      return new;
    end if;
  end if;
  select * into p from public.projects where id=new.project_id;
  select coalesce(array_agg(distinct id),'{}'::uuid[]) into communities from (
    select (l->>'id')::uuid id from jsonb_array_elements(p.community_links) l
    union select unnest(p.shared_community_ids) where lower(coalesce(p.visibility,'')) in ('friends','shared')
    union select cm.community_id from public.community_members cm
      where cm.user_id=p.user_id and cm.status='accepted' and lower(coalesce(p.visibility,''))='public'
    union select c.id from public.communities c where c.created_by=p.user_id and lower(coalesce(p.visibility,''))='public'
  ) c;
  new.feed_community_ids:=communities;
  new.feed_public:=lower(coalesce(p.visibility,''))='public';
  select coalesce(array_agg(distinct id),'{}'::uuid[]) into new.feed_user_ids from (
    select p.user_id id
    union select pc.user_id from public.project_collaborators pc
      where pc.project_id=p.id and pc.status='accepted'
    union select case when f.requester_id=p.user_id then f.addressee_id else f.requester_id end
      from public.friend_requests f where f.status='accepted'
      and (f.requester_id=p.user_id or f.addressee_id=p.user_id)
      and p.share_friends and lower(coalesce(p.visibility,'')) in ('friends','shared')
    union select cm.user_id from public.community_members cm where cm.community_id=any(communities) and cm.status='accepted'
    union select c.created_by from public.communities c where c.id=any(communities)
  ) u where id is not null;
  new.feed_published_at:=case when new.feed_ready then clock_timestamp() else null end;
  return new;
end;
$$;
create trigger snapshot_journal_feed_audience before insert or update on public.journal_entries
for each row execute function public.snapshot_journal_feed_audience();

-- Restrictive policies prevent legacy broad read policies from bypassing visibility.
create policy "Project audience access" on public.projects for select to authenticated
using(public.can_view_project_audience(id));
create policy "Enforce project audience" on public.projects as restrictive for select to authenticated
using(public.can_view_project_audience(id));
create policy "Journal audience access" on public.journal_entries for select to authenticated
using(public.can_view_project_audience(project_id));
create policy "Enforce journal audience" on public.journal_entries as restrictive for select to authenticated
using(public.can_view_project_audience(project_id) and (
  public.can_manage_project(project_id) or public.is_project_member(project_id) or feed_ready
));

create or replace function public.journal_feed_entry_allowed(p_entry_id uuid,p_owner_ids uuid[],p_community_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.journal_entries e join public.projects p on p.id=e.project_id
    where e.id=p_entry_id and e.feed_ready and e.feed_published_at is not null
      and public.can_view_project_audience(p.id)
      and case when p_community_id is null then (
        auth.uid()=any(e.feed_user_ids)
        or (e.feed_public and lower(coalesce(p.visibility,''))='public' and p.user_id=any(coalesce(p_owner_ids,'{}'::uuid[])))
      ) else (
        p_community_id=any(e.feed_community_ids) and (
          exists(select 1 from jsonb_array_elements(p.community_links) l where l->>'id'=p_community_id::text)
          or (lower(coalesce(p.visibility,'')) in ('friends','shared') and p_community_id=any(p.shared_community_ids))
          or (lower(coalesce(p.visibility,''))='public' and e.feed_public)
        )
      ) end);
$$;
revoke all on function public.journal_feed_entry_allowed(uuid,uuid[],uuid) from public;
create or replace function public.project_feed_for_audience(p_owner_ids uuid[] default null,p_community_id uuid default null)
returns setof public.projects language sql stable security definer set search_path=public as $$
  select p.* from public.projects p
  join lateral (select max(e.feed_published_at) latest from public.journal_entries e
    where e.project_id=p.id and public.journal_feed_entry_allowed(e.id,p_owner_ids,p_community_id)) f on f.latest is not null
  where auth.uid() is not null
    and (p_community_id is null or public.user_in_project_community(auth.uid(),p_community_id)
      or exists(select 1 from public.communities c where c.id=p_community_id and lower(c.visibility)='public'))
  order by f.latest desc;
$$;
revoke all on function public.project_feed_for_audience(uuid[],uuid) from public;
revoke all on function public.can_view_project_audience(uuid) from public;
revoke all on function public.user_in_project_community(uuid,uuid) from public;
revoke all on function public.are_project_friends(uuid,uuid) from public;
grant execute on function public.project_feed_for_audience(uuid[],uuid) to authenticated;
grant execute on function public.can_view_project_audience(uuid) to authenticated;
-- Called only inside security-definer functions.
commit;
