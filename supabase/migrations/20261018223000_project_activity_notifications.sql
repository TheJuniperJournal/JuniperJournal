begin;
alter table public.project_notifications
  add column if not exists activity_type text,
  add column if not exists actor_id uuid references auth.users(id) on delete set null,
  add column if not exists source_id text;
create index if not exists project_notifications_recipient_unread
  on public.project_notifications(user_id,created_at desc) where read_at is null;

-- Only triggers may emit activity notices; callers cannot notify arbitrary users.
create or replace function public.emit_project_activity(
  p_project uuid, p_kind text, p_source text, p_description text,
  p_extra_recipient uuid default null
) returns void language plpgsql security definer set search_path=public as $$
declare actor uuid := auth.uid(); actor_name text; project_name text; recipient uuid;
begin
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

create or replace function public.notify_project_activity()
returns trigger language plpgsql security definer set search_path=public as $$
declare before_row jsonb := to_jsonb(old); after_row jsonb := to_jsonb(new);
  event jsonb; previous_event jsonb; event_id text; event_name text; time_keys text[] :=
  array['date','startDate','endDate','start','end','time','startTime','endTime','allDay'];
begin
  if new.timeline is distinct from old.timeline then
    for event in select value from jsonb_array_elements(coalesce(nullif(after_row->'timeline','null'::jsonb),'[]'::jsonb)) loop
      event_id:=coalesce(event->>'id',event->>'name',event->>'event');
      select value into previous_event from jsonb_array_elements(coalesce(nullif(before_row->'timeline','null'::jsonb),'[]'::jsonb))
        where coalesce(value->>'id',value->>'name',value->>'event')=event_id limit 1;
      event_name:=coalesce(nullif(event->>'name',''),nullif(event->>'event',''),'Timeline event');
      if previous_event is null then
        perform public.emit_project_activity(new.id,'timeline_added',event_id,'added timeline event “' || event_name || '”');
      elsif previous_event is distinct from event then
        if (select jsonb_object_agg(key,value) from jsonb_each(event) where key=any(time_keys)) is distinct from
           (select jsonb_object_agg(key,value) from jsonb_each(previous_event) where key=any(time_keys)) then
          perform public.emit_project_activity(new.id,'timeline_rescheduled',event_id,'rescheduled timeline event “' || event_name || '”');
        else
          perform public.emit_project_activity(new.id,'timeline_updated',event_id,'updated timeline event “' || event_name || '”');
        end if;
      end if;
    end loop;
    for event in select value from jsonb_array_elements(coalesce(nullif(before_row->'timeline','null'::jsonb),'[]'::jsonb)) loop
      event_id:=coalesce(event->>'id',event->>'name',event->>'event');
      if not exists(select 1 from jsonb_array_elements(coalesce(nullif(after_row->'timeline','null'::jsonb),'[]'::jsonb))
        where coalesce(value->>'id',value->>'name',value->>'event')=event_id) then
        perform public.emit_project_activity(new.id,'timeline_removed',event_id,
          'removed timeline event “' || coalesce(event->>'name',event->>'event','Timeline event') || '”');
      end if;
    end loop;
  end if;
  if after_row->'materials_cost' is distinct from before_row->'materials_cost' then
    perform public.emit_project_activity(new.id,'materials_updated',new.id::text,'updated materials and costs');
  end if;
  if after_row->'budget' is distinct from before_row->'budget' then
    perform public.emit_project_activity(new.id,'budget_updated',new.id::text,'updated the budget');
  end if;
  -- Ignore counters, timestamps, and activity handled above. Includes new settings fields.
  if (after_row-array['timeline','materials_cost','budget','updated_at','likes','journal_entry_count']) is distinct from
     (before_row-array['timeline','materials_cost','budget','updated_at','likes','journal_entry_count']) then
    perform public.emit_project_activity(new.id,'project_updated',new.id::text,'updated project details or settings');
  end if;
  return new;
end;
$$;
create trigger notify_project_activity after update on public.projects
for each row execute function public.notify_project_activity();

create or replace function public.notify_journal_activity()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if not new.feed_ready or new.feed_published_at is null then return new; end if;
  if TG_OP='UPDATE' then
    if old.feed_ready then
      if new.title is not distinct from old.title and new.content is not distinct from old.content
        and new.progress is not distinct from old.progress then return new; end if;
      perform public.emit_project_activity(new.project_id,'journal_updated',new.id::text,
        'updated journal entry “' || new.title || '”');
      return new;
    end if;
  end if;
  perform public.emit_project_activity(new.project_id,'journal_published',new.id::text,
    'published journal entry “' || new.title || '”');
  return new;
end;
$$;
create trigger notify_journal_activity after insert or update on public.journal_entries
for each row execute function public.notify_journal_activity();

-- Replace the original addition trigger so the new member receives one notice,
-- and existing members also hear about membership and role changes.
create or replace function public.notify_project_member_activity()
returns trigger language plpgsql security definer set search_path=public as $$
declare row_data jsonb; previous_data jsonb; target uuid; project uuid; person text;
begin
  if TG_OP='DELETE' then row_data:=to_jsonb(old); else row_data:=to_jsonb(new); end if;
  if TG_OP='UPDATE' then previous_data:=to_jsonb(old); end if;
  target:=(row_data->>'user_id')::uuid; project:=(row_data->>'project_id')::uuid;
  select coalesce(nullif(trim(display_name),''),nullif(trim(username),''),'a member') into person
    from public.profiles where id=target;
  person:=coalesce(person,'a member');
  if TG_OP='DELETE' or (previous_data->>'status'='accepted' and row_data->>'status'<>'accepted') then
    if row_data->>'status'='accepted' or previous_data->>'status'='accepted' then
      perform public.emit_project_activity(project,'member_removed',target::text,'removed ' || person || ' from the project',target);
    end if;
  elsif row_data->>'status'='accepted' then
    if TG_OP='INSERT' or previous_data->>'status' is distinct from 'accepted' then
      perform public.emit_project_activity(project,'member_added',target::text,'added ' || person || ' to the project');
    elsif previous_data->>'role' is distinct from row_data->>'role' then
      perform public.emit_project_activity(project,'member_role_updated',target::text,'changed the project role for ' || person);
    end if;
  end if;
  return coalesce(new,old);
end;
$$;
drop trigger notify_project_member_added on public.project_collaborators;
create trigger notify_project_member_activity after insert or update or delete on public.project_collaborators
for each row execute function public.notify_project_member_activity();

create or replace function public.notify_project_forum_activity()
returns trigger language plpgsql security definer set search_path=public as $$
declare project uuid; post_title text;
begin
  if TG_TABLE_NAME='project_bulletin_posts' then
    perform public.emit_project_activity(new.project_id,'forum_post',new.id::text,'posted “' || new.title || '” in the forum');
  else
    select project_id,title into project,post_title from public.project_bulletin_posts where id=new.post_id;
    perform public.emit_project_activity(project,'forum_reply',new.id::text,'replied to “' || post_title || '” in the forum');
  end if;
  return new;
end;
$$;
create trigger notify_project_forum_post after insert on public.project_bulletin_posts
for each row execute function public.notify_project_forum_activity();
create trigger notify_project_forum_reply after insert on public.project_bulletin_comments
for each row execute function public.notify_project_forum_activity();
revoke all on function public.notify_project_activity(), public.notify_journal_activity(),
  public.notify_project_member_activity(), public.notify_project_forum_activity() from public,authenticated;
commit;
