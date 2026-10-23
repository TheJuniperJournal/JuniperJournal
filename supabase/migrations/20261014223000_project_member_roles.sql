alter table public.project_collaborators
  add column if not exists role text not null default 'project_member'
  check (role in ('project_member', 'project_admin'));

create or replace function public.can_manage_project(p_project_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select auth.uid() is not null and (
    exists(select 1 from public.projects p where p.id=p_project_id and p.user_id=auth.uid())
    or exists(select 1 from public.project_collaborators c
      where c.project_id=p_project_id and c.user_id=auth.uid()
      and c.status='accepted' and c.role='project_admin')
  );
$$;

create or replace function public.guard_project_member_role()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if TG_OP='INSERT' then
    if new.role <> 'project_member' and not public.can_manage_project(new.project_id) then
      raise exception 'Only project admins may assign member roles';
    end if;
  elsif new.role is distinct from old.role then
    if not public.can_manage_project(old.project_id) or new.project_id is distinct from old.project_id then
      raise exception 'Only project admins may assign member roles';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists project_member_role_guard on public.project_collaborators;
create trigger project_member_role_guard before insert or update on public.project_collaborators
for each row execute function public.guard_project_member_role();

create or replace function public.set_project_member_role(p_project_id uuid, p_user_id uuid, p_role text)
returns void language plpgsql security definer set search_path=public
as $$
begin
  if not public.can_manage_project(p_project_id) then
    raise exception 'Only project admins may assign member roles';
  end if;
  if p_role not in ('project_member','project_admin') then
    raise exception 'Invalid project role';
  end if;
  if exists(select 1 from public.projects where id=p_project_id and user_id=p_user_id) then
    raise exception 'The project owner remains a project admin';
  end if;
  update public.project_collaborators set role=p_role
    where project_id=p_project_id and user_id=p_user_id;
  if not found then raise exception 'Project member not found'; end if;
end;
$$;
revoke all on function public.can_manage_project(uuid) from public;
revoke all on function public.set_project_member_role(uuid,uuid,text) from public;
grant execute on function public.can_manage_project(uuid) to authenticated;
grant execute on function public.set_project_member_role(uuid,uuid,text) to authenticated;

create policy "Project admins read members" on public.project_collaborators
for select to authenticated using (public.can_manage_project(project_id));
create policy "Project admins update settings" on public.projects
for update to authenticated using (public.can_manage_project(id))
with check (public.can_manage_project(id));
