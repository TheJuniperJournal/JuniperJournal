begin;
-- The existing timeline JSON stays members-only. Nonmembers receive only
-- explicitly public events for projects they are already allowed to view.
create or replace function public.public_project_timeline(p_project_id uuid)
returns jsonb language sql stable security definer set search_path=public as $$
 select coalesce(jsonb_agg(event - 'journalEntryId' - 'journalEntryTitle' order by n),'[]'::jsonb)
 from public.projects p
 cross join lateral jsonb_array_elements(coalesce(p.timeline,'[]'::jsonb)) with ordinality e(event,n)
 where p.id=p_project_id and public.can_view_project_audience(p.id)
 and event->>'visibility'='public';
$$;
revoke all on function public.public_project_timeline(uuid) from public;
grant execute on function public.public_project_timeline(uuid) to anon,authenticated;

-- Public journal previews must not expose a members-only event snapshot.
create or replace function public.strip_internal_journal_links(value jsonb)
returns jsonb language plpgsql immutable set search_path=public as $$
declare result jsonb;
begin
 if jsonb_typeof(value)='object' then
  select coalesce(jsonb_object_agg(key,public.strip_internal_journal_links(v)),'{}'::jsonb) into result
  from jsonb_each(value) e(key,v)
  where key not in ('linkedTimelineEvent','linkedTimelineEventId','linked_timeline_event','linked_timeline_event_id','timeline')
  and (key <> 'createdTimelineEvent' or v->>'visibility'='public');
 elsif jsonb_typeof(value)='array' then
  select coalesce(jsonb_agg(public.strip_internal_journal_links(v) order by n),'[]'::jsonb) into result
  from jsonb_array_elements(value) with ordinality e(v,n);
 else return value;
 end if;
 return result;
end; $$;
commit;
