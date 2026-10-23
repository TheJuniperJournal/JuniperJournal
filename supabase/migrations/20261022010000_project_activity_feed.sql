begin;
create table public.project_activity_feed (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.projects(id) on delete cascade,
 actor_id uuid references auth.users(id) on delete set null,
 actor_name text not null,
 avatar_url text,
 kind text not null,
 source_id text,
 journal_entry_id uuid references public.journal_entries(id) on delete cascade,
 description text not null,
 created_at timestamptz not null default clock_timestamp()
);
create index project_activity_feed_recent on public.project_activity_feed(project_id,created_at desc,id desc);
alter table public.project_activity_feed enable row level security;
revoke all on public.project_activity_feed from anon,authenticated;
grant select on public.project_activity_feed to authenticated;
-- Internal activity stays internal. Journal visibility follows the current entry,
-- so changing an entry's audience also changes who can see its activity.
create policy "Project audience reads permitted activity" on public.project_activity_feed
 for select to authenticated using (
 public.can_view_project_audience(project_id) and (
  (journal_entry_id is not null and exists(
    select 1 from public.journal_entries e where e.id=journal_entry_id and
      (e.feed_ready or public.is_project_participant(e.project_id) or e.user_id=auth.uid())
  )) or (journal_entry_id is null and
    (public.is_project_participant(project_id) or kind='project_updated'))
 ));

create or replace function public.record_project_feed_event(
 p_project uuid,p_kind text,p_source text,p_description text)
returns void language plpgsql security definer set search_path=public as $$
declare actor uuid := auth.uid(); person text; avatar text; journal uuid; existing uuid; source text := p_source;
begin
 if not exists(select 1 from public.projects where id=p_project) then return; end if;
 if p_kind='forum_reply' then
   select post_id::text into source from public.project_bulletin_comments where id=p_source::uuid;
 end if;
 if p_kind like 'impact_%' then
   select linked_journal_entry_id into journal from public.impact_entries where id=p_source::uuid;
 end if;
 if p_kind like 'journal_%' then
   journal := p_source::uuid;
   if not exists(select 1 from public.journal_entries where id=journal) then return; end if;
 end if;
 select coalesce(nullif(trim(display_name),''),nullif(trim(username),''),'A project member'),avatar_url
 into person,avatar from public.profiles where id=actor;
 -- Serialize grouped edits, including simultaneous autosave requests.
 perform pg_advisory_xact_lock(hashtextextended(p_project::text||coalesce(actor::text,'')||p_kind||coalesce(p_source,''),0));
 if p_kind in ('journal_updated','journal_draft_updated','impact_updated','materials_updated','budget_updated','project_updated','timeline_updated','timeline_rescheduled') then
   select id into existing from public.project_activity_feed
    where project_id=p_project and actor_id is not distinct from actor and kind=p_kind
      and source_id is not distinct from p_source and created_at>clock_timestamp()-interval '5 minutes'
    order by created_at desc limit 1;
   if existing is not null then
     update public.project_activity_feed set description=p_description,created_at=clock_timestamp(),
       actor_name=coalesce(person,'A project member'),avatar_url=avatar where id=existing;
     return;
   end if;
 end if;
 insert into public.project_activity_feed(project_id,actor_id,actor_name,avatar_url,kind,source_id,journal_entry_id,description)
 values(p_project,actor,coalesce(person,'A project member'),avatar,p_kind,source,journal,p_description);
end;
$$;
revoke all on function public.record_project_feed_event(uuid,text,text,text) from public,authenticated,anon;

create or replace function public.emit_project_activity(
  p_project uuid, p_kind text, p_source text, p_description text,
  p_extra_recipient uuid default null
) returns void language plpgsql security definer set search_path=public as $$
declare actor uuid := auth.uid(); actor_name text; project_name text; recipient uuid;
begin
  perform public.record_project_feed_event(p_project,p_kind,p_source,p_description);
  select p.project_name into project_name from public.projects p where p.id=p_project;
  if project_name is null then return; end if;
  select coalesce(nullif(trim(display_name),''),nullif(trim(username),''))
    into actor_name from public.profiles where id=actor;
  actor_name := coalesce(actor_name,'A project member');
  for recipient in
    select user_id from public.projects where id=p_project
    union select user_id from public.project_collaborators where project_id=p_project and status='accepted'
    union select p_extra_recipient
  loop
    if recipient is null or recipient=actor then continue; end if;
    -- An unread notice represents the latest edit during a short editing session.
    if p_kind in ('journal_updated','materials_updated','budget_updated','project_updated','timeline_updated','timeline_rescheduled') then
      update public.project_notifications set
        message=actor_name || ' ' || p_description || ' in ' || project_name || '.', created_at=clock_timestamp()
      where user_id=recipient and project_id=p_project and activity_type=p_kind
        and source_id is not distinct from p_source and actor_id is not distinct from actor
        and read_at is null and created_at > clock_timestamp()-interval '5 minutes';
      if found then continue; end if;
    end if;
    insert into public.project_notifications(user_id,project_id,activity_type,actor_id,source_id,message)
    values(recipient,p_project,p_kind,actor,p_source,actor_name || ' ' || p_description || ' in ' || project_name || '.');
  end loop;
end;
$$;
revoke all on function public.emit_project_activity(uuid,text,text,text,uuid) from public,authenticated;

-- Draft saves are activity only, never recipient notifications.
create or replace function public.record_project_draft_activity()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if coalesce(new.feed_ready,false) then return new; end if;
 if TG_OP='UPDATE' and new.title is not distinct from old.title and new.content is not distinct from old.content
    and new.progress is not distinct from old.progress then return new; end if;
 perform public.record_project_feed_event(new.project_id,
   case when TG_OP='INSERT' then 'journal_draft_saved' else 'journal_draft_updated' end,
   new.id::text,case when TG_OP='INSERT' then 'saved a draft' else 'updated a draft' end || ' “' || new.title || '”');
 return new;
end;
$$;
create trigger project_feed_draft_activity after insert or update on public.journal_entries
 for each row execute function public.record_project_draft_activity();
create or replace function public.record_journal_comment_activity()
returns trigger language plpgsql security definer set search_path=public as $$
declare entry public.journal_entries%rowtype;
begin
 select * into entry from public.journal_entries where id=new.journal_entry_id;
 perform public.record_project_feed_event(entry.project_id,case when TG_TABLE_NAME='journal_entry_likes' then 'journal_flower' else 'journal_comment' end,entry.id::text,
   case when TG_TABLE_NAME='journal_entry_likes' then 'gave a flower to journal entry “' else 'commented on journal entry “' end || entry.title || '”');
 return new;
end;
$$;
create trigger project_feed_journal_comment after insert on public.journal_entry_comments
 for each row execute function public.record_journal_comment_activity();
create trigger project_feed_journal_flower after insert on public.journal_entry_likes
 for each row execute function public.record_journal_comment_activity();
revoke all on function public.record_project_draft_activity(),public.record_journal_comment_activity() from public,authenticated,anon;
create or replace function public.record_impact_feed_activity()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if TG_OP='UPDATE' and (to_jsonb(new)-array['eco_points','updated_at']) is not distinct from
   (to_jsonb(old)-array['eco_points','updated_at']) then return new; end if;
 perform public.record_project_feed_event(new.project_id,
   case when TG_OP='INSERT' then 'impact_added' else 'impact_updated' end,new.id::text,
   case when TG_OP='INSERT' then 'added an impact assessment' else 'updated an impact assessment' end || ' “' || new.title || '”');
 return new;
end;
$$;
create trigger project_feed_impact after insert or update on public.impact_entries
 for each row execute function public.record_impact_feed_activity();
revoke all on function public.record_impact_feed_activity() from public,authenticated,anon;
-- Seed existing entries once. Earlier edits and interactions cannot be reconstructed.
insert into public.project_activity_feed(project_id,actor_id,actor_name,avatar_url,kind,source_id,journal_entry_id,description,created_at)
 select e.project_id,e.user_id,coalesce(nullif(trim(p.display_name),''),nullif(trim(p.username),''),'A project member'),p.avatar_url,
   case when e.feed_ready then 'journal_published' else 'journal_draft_saved' end,e.id::text,e.id,
   case when e.feed_ready then 'published journal entry' else 'saved a draft' end || ' “' || e.title || '”',
   coalesce(e.created_at,now())
 from public.journal_entries e left join public.profiles p on p.id=e.user_id;
commit;
