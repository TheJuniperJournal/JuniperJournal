-- Active foreground use is recorded per user/session. Absolute cumulative writes
-- make retries and out-of-order delivery idempotent.
create table public.project_activity_sessions (
  session_id uuid primary key,
  project_id uuid not null references public.projects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  active_seconds integer not null check (active_seconds between 0 and 31536000),
  updated_at timestamptz not null default now()
);
create index project_activity_time_project on public.project_activity_sessions(project_id, user_id);
alter table public.project_activity_sessions enable row level security;
revoke all on public.project_activity_sessions from anon, authenticated;

create or replace function public.get_project_activity_time(p_project_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare participant boolean; personal bigint; total bigint;
begin
  participant := public.is_project_participant(p_project_id);
  if not coalesce(public.can_view_project_audience(p_project_id),false) then
    raise exception 'Project is not accessible' using errcode='42501';
  end if;
  select coalesce(sum(active_seconds) filter (where user_id=auth.uid()),0),
         coalesce(sum(active_seconds),0) into personal,total
    from public.project_activity_sessions where project_id=p_project_id;
  return jsonb_build_object('participant',coalesce(participant,false),
    'personal_seconds',personal,'total_seconds',total);
end;
$$;
revoke all on function public.get_project_activity_time(uuid) from public;
grant execute on function public.get_project_activity_time(uuid) to authenticated, anon;

create or replace function public.record_project_activity_time(
 p_project_id uuid, p_session_id uuid, p_seconds integer)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null or not public.is_project_participant(p_project_id) then
    raise exception 'Only project participants can record time' using errcode='42501';
  end if;
  if p_seconds is null or p_seconds < 0 or p_seconds > 31536000 or p_session_id is null then
    raise exception 'Invalid activity time' using errcode='22023';
  end if;
  insert into public.project_activity_sessions(session_id,project_id,user_id,active_seconds)
    values(p_session_id,p_project_id,auth.uid(),p_seconds)
  on conflict(session_id) do update
    set active_seconds=greatest(project_activity_sessions.active_seconds,excluded.active_seconds), updated_at=now()
    where project_activity_sessions.project_id=excluded.project_id
      and project_activity_sessions.user_id=excluded.user_id;
  if not found then
    raise exception 'Session belongs to another participant or project' using errcode='42501';
  end if;
  return public.get_project_activity_time(p_project_id);
end;
$$;
revoke all on function public.record_project_activity_time(uuid,uuid,integer) from public;
grant execute on function public.record_project_activity_time(uuid,uuid,integer) to authenticated;
