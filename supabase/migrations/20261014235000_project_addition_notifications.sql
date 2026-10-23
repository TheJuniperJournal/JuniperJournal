begin;
create table if not exists public.project_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  community_id uuid references public.communities(id) on delete cascade,
  message text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
alter table public.project_notifications enable row level security;
create policy "Recipients read project notifications" on public.project_notifications
for select to authenticated using (user_id=auth.uid());
create policy "Recipients mark project notifications read" on public.project_notifications
for update to authenticated using (user_id=auth.uid()) with check(user_id=auth.uid());

create or replace function public.add_project_member(p_project_id uuid,p_user_id uuid,p_role text default 'project_member')
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.can_manage_project(p_project_id) then raise exception 'Only project admins may add members'; end if;
  if p_role not in ('project_member','project_admin') then raise exception 'Invalid project role'; end if;
  if not exists(select 1 from public.projects where id=p_project_id and project_type='collaborative') then
    raise exception 'Only collaborative projects support members';
  end if;
  if exists(select 1 from public.projects where id=p_project_id and user_id=p_user_id) then return; end if;
  if exists(select 1 from public.project_collaborators where project_id=p_project_id and user_id=p_user_id and status='accepted') then return; end if;
  if exists(select 1 from public.project_collaborators where project_id=p_project_id and user_id=p_user_id) then
    update public.project_collaborators set status='accepted',role=p_role,invited_by=auth.uid()
    where project_id=p_project_id and user_id=p_user_id;
  else
    insert into public.project_collaborators(project_id,user_id,invited_by,status,role)
      values(p_project_id,p_user_id,auth.uid(),'accepted',p_role);
  end if;
end;
$$;
revoke all on function public.add_project_member(uuid,uuid,text) from public;
grant execute on function public.add_project_member(uuid,uuid,text) to authenticated;

create or replace function public.notify_project_member_added()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status='accepted' then
    if TG_OP='UPDATE' then
      if old.status='accepted' then return new; end if;
    end if;
    insert into public.project_notifications(user_id,project_id,message)
    select new.user_id,new.project_id,'You were added to ' || p.project_name || '. It is now in your library.'
    from public.projects p where p.id=new.project_id;
  end if;
  return new;
end;
$$;
create trigger notify_project_member_added after insert or update on public.project_collaborators
for each row execute function public.notify_project_member_added();

create or replace function public.notify_project_community_added()
returns trigger language plpgsql security definer set search_path=public as $$
declare link jsonb; previous jsonb := '[]'::jsonb; community uuid;
begin
  if TG_OP='UPDATE' then previous := coalesce(old.community_links,'[]'::jsonb); end if;
  for link in select value from jsonb_array_elements(coalesce(new.community_links,'[]'::jsonb)) loop
    if not exists(select 1 from jsonb_array_elements(previous) v where v->>'id'=link->>'id') then
      community := (link->>'id')::uuid;
      insert into public.project_notifications(user_id,project_id,community_id,message)
      select recipients.user_id,new.id,community,
        new.project_name || ' was added to ' || c.name || '. It is now in the community library.'
      from public.communities c
      cross join lateral (
        select cm.user_id from public.community_members cm where cm.community_id=c.id and cm.status='accepted'
        union select c.created_by
      ) recipients
      where c.id=community and recipients.user_id is not null;
    end if;
  end loop;
  return new;
end;
$$;
create trigger notify_project_community_added after insert or update of community_links on public.projects
for each row execute function public.notify_project_community_added();

create or replace function public.can_view_linked_community_project(p_project_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select auth.uid() is not null and exists(
    select 1 from public.projects p
    cross join lateral jsonb_array_elements(p.community_links) link
    join public.communities c on c.id::text=link->>'id'
    where p.id=p_project_id and (
      c.created_by=auth.uid() or exists(select 1 from public.community_members cm
        where cm.community_id=c.id and cm.user_id=auth.uid() and cm.status='accepted')
    )
  );
$$;
revoke all on function public.can_view_linked_community_project(uuid) from public;
grant execute on function public.can_view_linked_community_project(uuid) to authenticated;
create policy "Linked community members view projects" on public.projects for select to authenticated
using (public.can_view_linked_community_project(id));
create or replace function public.is_project_member(p_project_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select auth.uid() is not null and exists(select 1 from public.project_collaborators pc
    where pc.project_id=p_project_id and pc.user_id=auth.uid() and pc.status='accepted');
$$;
revoke all on function public.is_project_member(uuid) from public;
grant execute on function public.is_project_member(uuid) to authenticated;
create policy "Accepted collaborators view projects" on public.projects for select to authenticated
using (public.is_project_member(id));
grant select,update on public.project_notifications to authenticated;

create or replace function public.valid_project_community_links(links jsonb)
returns boolean language sql immutable set search_path=public as $$
  select jsonb_typeof(links)='array' and
    (select count(*) from jsonb_array_elements(links) link where link->>'role'='home') <= 1;
$$;
alter table public.projects add constraint projects_one_home_community
  check (public.valid_project_community_links(community_links));

commit;
