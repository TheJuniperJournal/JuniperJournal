begin;
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
 if p_kind like 'journal_%' and p_kind not in ('journal_deleted','journal_draft_deleted') then
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


-- Deleted entries cannot be foreign-key targets. Keep an independent, participant-only
-- tombstone with the original title and the deleting actor's identity.
create or replace function public.notify_journal_deletion()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if coalesce(old.feed_ready,false) then
  perform public.emit_project_activity(old.project_id,'journal_deleted',old.id::text,
   'deleted journal entry “' || coalesce(nullif(old.title,''),'Untitled entry') || '”');
 else
  perform public.emit_project_activity(old.project_id,'journal_draft_deleted',old.id::text,
   'deleted a draft “' || coalesce(nullif(old.title,''),'Untitled entry') || '”');
 end if;
 return old;
end;
$$;
create trigger notify_journal_deletion after delete on public.journal_entries
for each row execute function public.notify_journal_deletion();

create or replace function public.record_impact_feed_activity()
returns trigger language plpgsql security definer set search_path=public as $$
declare row_data public.impact_entries%rowtype; action text;
begin
 if TG_OP='UPDATE' and (to_jsonb(new)-array['eco_points','updated_at']) is not distinct from
   (to_jsonb(old)-array['eco_points','updated_at']) then return new; end if;
 if TG_OP='DELETE' then row_data:=old; action:='deleted';
 elsif TG_OP='INSERT' then row_data:=new; action:='added';
 else row_data:=new; action:='updated'; end if;
 -- A cascading journal/project deletion already has its own event.
 if TG_OP='DELETE' and row_data.linked_journal_entry_id is not null and
   not exists(select 1 from public.journal_entries where id=row_data.linked_journal_entry_id) then return old; end if;
 perform public.emit_project_activity(row_data.project_id,'impact_' || action,row_data.id::text,
   action || ' an impact assessment “' || row_data.title || '”');
 return coalesce(new,old);
end;
$$;
drop trigger project_feed_impact on public.impact_entries;
create trigger project_feed_impact after insert or update or delete on public.impact_entries
for each row execute function public.record_impact_feed_activity();

create or replace function public.notify_forum_edit_activity()
returns trigger language plpgsql security definer set search_path=public as $$
declare project uuid; source text; title text; action text;
begin
 action:=case when TG_OP='DELETE' then 'deleted' else 'updated' end;
 if TG_OP='UPDATE' and (to_jsonb(new)-array['updated_at']) is not distinct from
   (to_jsonb(old)-array['updated_at']) then return new; end if;
 if TG_TABLE_NAME='project_bulletin_posts' then
  project:=old.project_id; source:=old.id::text; title:=old.title;
 else
  select p.project_id,p.title into project,title from public.project_bulletin_posts p where p.id=old.post_id;
  source:=old.post_id::text;
 end if;
 if project is not null then
  perform public.emit_project_activity(project,
    case when TG_TABLE_NAME='project_bulletin_posts' then 'forum_post_' else 'forum_reply_' end || action,
    source,action || case when TG_TABLE_NAME='project_bulletin_posts' then ' forum post “' else ' a reply to “' end || title || '”');
 end if;
 return coalesce(new,old);
end;
$$;
create trigger notify_forum_post_edit after update or delete on public.project_bulletin_posts
for each row execute function public.notify_forum_edit_activity();
create trigger notify_forum_reply_edit after update or delete on public.project_bulletin_comments
for each row execute function public.notify_forum_edit_activity();
revoke all on function public.notify_journal_deletion(),public.notify_forum_edit_activity() from public,authenticated,anon;
commit;
