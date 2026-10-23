begin;
-- Membership and project type change together, including additions outside setup.
create or replace function public.promote_project_for_member()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status in ('accepted','pending') and exists(
    select 1 from projects where id=new.project_id and user_id<>new.user_id
  ) then
    update projects set project_type='collaborative' where id=new.project_id and project_type='solo';
  end if;
  return new;
end;
$$;
create trigger promote_project_for_member before insert or update on public.project_collaborators
for each row execute function public.promote_project_for_member();
create or replace function public.prevent_solo_with_members()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.project_type='solo' and exists(select 1 from project_collaborators
    where project_id=new.id and user_id<>new.user_id and status in ('accepted','pending')) then
    raise exception 'Remove other project members before changing to Solo';
  end if;
  return new;
end;
$$;
create trigger prevent_solo_with_members before update of project_type on public.projects
for each row execute function public.prevent_solo_with_members();
create or replace function public.add_project_member(p_project_id uuid,p_user_id uuid,p_role text default 'project_member')
returns void language plpgsql security definer set search_path=public as $$
begin
  perform 1 from projects where id=p_project_id for update;
  if not public.can_manage_project(p_project_id) then raise exception 'Only project admins may add members'; end if;
  if p_role not in ('project_member','project_admin') then raise exception 'Invalid project role'; end if;
  if exists(select 1 from projects where id=p_project_id and user_id=p_user_id) then return; end if;
  if exists(select 1 from project_collaborators where project_id=p_project_id and user_id=p_user_id and status='accepted') then return; end if;
  if exists(select 1 from project_collaborators where project_id=p_project_id and user_id=p_user_id) then
    update project_collaborators set status='accepted',role=p_role,invited_by=auth.uid() where project_id=p_project_id and user_id=p_user_id;
  else
    insert into project_collaborators(project_id,user_id,invited_by,status,role) values(p_project_id,p_user_id,auth.uid(),'accepted',p_role);
  end if;
end;
$$;
create or replace function public.is_project_participant(p_project_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select auth.uid() is not null and (exists(select 1 from projects where id=p_project_id and user_id=auth.uid())
 or exists(select 1 from project_collaborators where project_id=p_project_id and user_id=auth.uid() and status='accepted'));
$$;
revoke all on function public.is_project_participant(uuid) from public;
grant execute on function public.is_project_participant(uuid) to authenticated;
create table public.project_bulletin_posts (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.projects(id) on delete cascade,
 user_id uuid not null references auth.users(id),
 title text not null check(length(trim(title)) between 1 and 160),
 body text not null check(length(trim(body)) between 1 and 10000),
 category text not null check(category in ('Idea / Brainstorm','Design Feedback','Question / Help','Calculations','Resources / Materials','Project Update')),
 image_urls text[] not null default '{}',
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index on public.project_bulletin_posts(project_id,created_at desc);
create table public.project_bulletin_comments (
 id uuid primary key default gen_random_uuid(), post_id uuid not null references public.project_bulletin_posts(id) on delete cascade,
 user_id uuid not null references auth.users(id), body text not null check(length(trim(body)) between 1 and 4000), created_at timestamptz not null default now()
);
create table public.project_bulletin_reactions (
 post_id uuid not null references public.project_bulletin_posts(id) on delete cascade,
 user_id uuid not null references auth.users(id), primary key(post_id,user_id)
);
alter table public.project_bulletin_posts enable row level security;
alter table public.project_bulletin_comments enable row level security;
alter table public.project_bulletin_reactions enable row level security;
create policy "Participants read bulletin" on public.project_bulletin_posts for select to authenticated using(is_project_participant(project_id));
create policy "Participants post" on public.project_bulletin_posts for insert to authenticated with check(user_id=auth.uid() and is_project_participant(project_id));
create policy "Authors edit posts" on public.project_bulletin_posts for update to authenticated using(user_id=auth.uid() and is_project_participant(project_id)) with check(user_id=auth.uid() and is_project_participant(project_id));
create policy "Authors or admins delete posts" on public.project_bulletin_posts for delete to authenticated using(is_project_participant(project_id) and (user_id=auth.uid() or can_manage_project(project_id)));
create policy "Participants read comments" on public.project_bulletin_comments for select to authenticated using(exists(select 1 from project_bulletin_posts p where p.id=post_id and is_project_participant(p.project_id)));
create policy "Participants comment" on public.project_bulletin_comments for insert to authenticated with check(user_id=auth.uid() and exists(select 1 from project_bulletin_posts p where p.id=post_id and is_project_participant(p.project_id)));
create policy "Authors delete comments" on public.project_bulletin_comments for delete to authenticated using(user_id=auth.uid());
create policy "Participants read reactions" on public.project_bulletin_reactions for select to authenticated using(exists(select 1 from project_bulletin_posts p where p.id=post_id and is_project_participant(p.project_id)));
create policy "Participants react" on public.project_bulletin_reactions for insert to authenticated with check(user_id=auth.uid() and exists(select 1 from project_bulletin_posts p where p.id=post_id and is_project_participant(p.project_id)));
create policy "Members remove own reaction" on public.project_bulletin_reactions for delete to authenticated using(user_id=auth.uid());
grant select,insert,update,delete on public.project_bulletin_posts,public.project_bulletin_comments,public.project_bulletin_reactions to authenticated;
commit;
