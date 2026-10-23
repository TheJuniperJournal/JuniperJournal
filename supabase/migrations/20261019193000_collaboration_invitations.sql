begin;
alter table public.project_collaborators drop constraint project_collaborators_status_check;
alter table public.project_collaborators add constraint project_collaborators_status_check check(status in ('pending','accepted','declined','cancelled'));

create or replace function public.add_project_member(p_project_id uuid,p_user_id uuid,p_role text default 'project_member')
returns void language plpgsql security definer set search_path=public as $$
declare previous text;
begin
  if not can_manage_project(p_project_id) then raise exception 'Only project admins may invite members'; end if;
  if p_role not in ('project_member','project_admin') then raise exception 'Invalid project role'; end if;
  perform 1 from projects where id=p_project_id for update;
  if exists(select 1 from projects where id=p_project_id and user_id=p_user_id) then return; end if;
  select status into previous from project_collaborators where project_id=p_project_id and user_id=p_user_id;
  if previous in ('accepted','pending') then return; end if;
  insert into project_collaborators(project_id,user_id,invited_by,status,role)
    values(p_project_id,p_user_id,auth.uid(),'pending',p_role)
    on conflict(project_id,user_id) do update set status='pending',role=excluded.role,invited_by=auth.uid(),created_at=now();
  insert into project_notifications(user_id,project_id,message)
    select p_user_id,id,'You are invited to collaborate on '||project_name||'. Accept or decline in Notifications.' from projects where id=p_project_id;
end $$;

create or replace function public.respond_project_invitation(p_id uuid,p_accept boolean)
returns void language plpgsql security definer set search_path=public as $$
declare invitation project_collaborators%rowtype;
begin
  select * into invitation from project_collaborators where id=p_id for update;
  if invitation.user_id is distinct from auth.uid() or invitation.status<>'pending' then raise exception 'This invitation is unavailable'; end if;
  update project_collaborators set status=case when p_accept then 'accepted' else 'declined' end where id=p_id;
  insert into project_notifications(user_id,project_id,message)
    values(invitation.invited_by,invitation.project_id,case when p_accept then 'Your project invitation was accepted.' else 'Your project invitation was declined.' end);
end $$;

-- Direct updates cannot let invitees change their own role or bypass acceptance.
revoke insert,delete on public.project_collaborators from authenticated;
-- Older clients can still answer their own pending invitation, while role,
-- identity and administrator mutations must use the permission-checked RPCs.
create or replace function public.guard_direct_invitation_update()returns trigger language plpgsql set search_path=public as $$
begin
 if current_user='authenticated' and not(old.user_id=auth.uid() and old.status='pending' and new.status in ('accepted','declined') and (to_jsonb(new)-'status')=(to_jsonb(old)-'status')) then raise exception 'Use the invitation or role management actions';end if;
 return new;
end $$;
create trigger guard_direct_invitation_update before update on project_collaborators for each row execute function guard_direct_invitation_update();
create or replace function public.remove_project_member(p_project_id uuid,p_user_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not can_manage_project(p_project_id) then raise exception 'Only project admins may remove members'; end if;
  if exists(select 1 from projects where id=p_project_id and user_id=p_user_id) then raise exception 'The project owner cannot be removed'; end if;
  update project_collaborators set status='cancelled' where project_id=p_project_id and user_id=p_user_id and status in ('pending','accepted');
end $$;

create or replace function public.can_review_community_projects(p_community_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select auth.uid() is not null and (
    exists(select 1 from communities where id=p_community_id and created_by=auth.uid()) or
    exists(select 1 from community_members where community_id=p_community_id and user_id=auth.uid() and status='accepted' and role in ('owner','admin')));
$$;
create table public.project_community_invitations(
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade deferrable initially deferred,
  community_id uuid not null references public.communities(id) on delete cascade,
  requested_role text not null check(requested_role in ('home','collaborator')),
  invited_by uuid not null references auth.users(id),
  status text not null default 'pending' check(status in ('pending','accepted','declined','cancelled')),
  decided_by uuid references auth.users(id),
  created_at timestamptz not null default now(),decided_at timestamptz
);
create unique index one_active_community_project_invite on public.project_community_invitations(project_id,community_id) where status in ('pending','accepted');
alter table public.project_community_invitations enable row level security;
create policy "Project and community admins review invitations" on public.project_community_invitations for select to authenticated
  using(can_manage_project(project_id) or can_review_community_projects(community_id));
grant select on public.project_community_invitations to authenticated;

-- Legacy links remain accepted. New links are staged as a community-level
-- invitation and do not grant audience access until an administrator decides.
create or replace function public.stage_project_community_invites()
returns trigger language plpgsql security definer set search_path=public as $$
declare link jsonb; retained jsonb:='[]'; known boolean;
begin
  for link in select value from jsonb_array_elements(coalesce(new.community_links,'[]')) loop
    known:=false;
    if TG_OP='UPDATE' then known:=exists(select 1 from jsonb_array_elements(old.community_links) l where l->>'id'=link->>'id'); end if;
    if known or exists(select 1 from project_community_invitations where project_id=new.id and community_id=(link->>'id')::uuid and status='accepted') then
      retained:=retained||jsonb_build_array(link);
    else
      insert into project_community_invitations(project_id,community_id,requested_role,invited_by)
        values(new.id,(link->>'id')::uuid,coalesce(link->>'role','collaborator'),coalesce(auth.uid(),new.user_id))
        on conflict(project_id,community_id) where status in ('pending','accepted') do nothing;
    end if;
  end loop;
  if TG_OP='UPDATE' then
    update project_community_invitations i set status='cancelled' where i.project_id=new.id and i.status='accepted' and not exists(select 1 from jsonb_array_elements(retained) l where l->>'id'=i.community_id::text);
  end if;
  new.community_links:=retained;
  return new;
end $$;
create trigger stage_project_community_invites before insert or update of community_links on public.projects for each row execute function public.stage_project_community_invites();

create or replace function public.review_community_project_invitation(p_id uuid,p_accept boolean)
returns void language plpgsql security definer set search_path=public as $$
declare invitation project_community_invitations%rowtype; links jsonb; item jsonb;
begin
  select * into invitation from project_community_invitations where id=p_id for update;
  if invitation.id is null or not can_review_community_projects(invitation.community_id) then raise exception 'Only community administrators may review this invitation'; end if;
  if invitation.status<>'pending' then raise exception 'This invitation has already been reviewed'; end if;
  update project_community_invitations set status=case when p_accept then 'accepted' else 'declined' end,decided_by=auth.uid(),decided_at=now() where id=p_id;
  if p_accept then
    select community_links into links from projects where id=invitation.project_id for update;
    if invitation.requested_role='home' then
      select coalesce(jsonb_agg(l||jsonb_build_object('role','collaborator')),'[]') into links from jsonb_array_elements(links) l;
    end if;
    select jsonb_build_object('id',id,'name',name,'role',invitation.requested_role,'imageUrl',image_url,'description',subject_focus) into item from communities where id=invitation.community_id;
    update projects set community_links=links||jsonb_build_array(item) where id=invitation.project_id;
  end if;
  insert into project_notifications(user_id,project_id,community_id,message)
    select user_id,id,invitation.community_id,case when p_accept then 'Community collaboration accepted.' else 'Community collaboration declined.' end from projects where id=invitation.project_id;
end $$;

create or replace function public.community_project_invitations(p_community_id uuid default null,p_project_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public as $$
begin
  if (p_community_id is null or not can_review_community_projects(p_community_id)) and
     (p_project_id is null or not can_manage_project(p_project_id)) then raise exception 'Administrator access required'; end if;
  return coalesce((select jsonb_agg(to_jsonb(i)||jsonb_build_object('project_name',p.project_name,'problem_statement',p.problem_statement,'creator_id',p.user_id,'creator_name',u.display_name,'community_name',c.name,'decided_by_name',d.display_name) order by i.created_at desc)
    from project_community_invitations i join projects p on p.id=i.project_id join communities c on c.id=i.community_id left join profiles u on u.id=p.user_id left join profiles d on d.id=i.decided_by
    where (p_community_id is null or i.community_id=p_community_id) and (p_project_id is null or i.project_id=p_project_id)), '[]');
end $$;

create or replace function public.cancel_community_project_invitation(p_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare pid uuid;
begin
  select project_id into pid from project_community_invitations where id=p_id for update;
  if not can_manage_project(pid) then raise exception 'Project administrator access required'; end if;
  update project_community_invitations set status='cancelled',decided_at=now(),decided_by=auth.uid() where id=p_id and status='pending';
end $$;
revoke all on function public.respond_project_invitation(uuid,boolean),public.review_community_project_invitation(uuid,boolean),public.community_project_invitations(uuid,uuid),public.cancel_community_project_invitation(uuid),public.can_review_community_projects(uuid) from public;
grant execute on function public.respond_project_invitation(uuid,boolean),public.review_community_project_invitation(uuid,boolean),public.community_project_invitations(uuid,uuid),public.cancel_community_project_invitation(uuid),public.can_review_community_projects(uuid) to authenticated;
create or replace function public.pending_project_invitations()
returns jsonb language sql stable security definer set search_path=public as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'project_id',c.project_id,'project_name',p.project_name,'invited_by',c.invited_by,'created_at',c.created_at,'display_name',u.display_name,'username',u.username,'avatar_url',u.avatar_url) order by c.created_at desc),'[]')
 from project_collaborators c join projects p on p.id=c.project_id left join profiles u on u.id=c.invited_by where c.user_id=auth.uid() and c.status='pending';
$$;
revoke all on function public.guard_direct_invitation_update() from public;
revoke all on function public.pending_project_invitations() from public;
grant execute on function public.pending_project_invitations() to authenticated;
commit;
