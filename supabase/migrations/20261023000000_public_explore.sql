begin;
-- Anonymous browsing is read-only and limited to explicitly public content.
grant select on public.projects, public.journal_entries, public.communities to anon;
create policy "Visitors browse public projects" on public.projects for select to anon
using (lower(coalesce(visibility,''))='public');
create policy "Visitors browse public communities" on public.communities for select to anon
using (lower(coalesce(visibility,''))='public');
create policy "Visitors read completed public journals" on public.journal_entries for select to anon
using (
  feed_ready and feed_public
  and exists(select 1 from public.projects p where p.id=project_id and lower(coalesce(p.visibility,''))='public')
  and exists(select 1 from jsonb_array_elements(content) item
    where item->>'stage' in ('nextAction','reflection','free_notes') and item->>'submitted'='true')
);
-- Restrictive policies prevent broader legacy policies from exposing private rows.
create policy "Visitors enforce public projects" on public.projects as restrictive for select to anon
using (lower(coalesce(visibility,''))='public');
create policy "Visitors enforce public communities" on public.communities as restrictive for select to anon
using (lower(coalesce(visibility,''))='public');
create policy "Visitors enforce completed journals" on public.journal_entries as restrictive for select to anon
using (feed_ready and feed_public
  and exists(select 1 from public.projects p where p.id=project_id and lower(coalesce(p.visibility,''))='public')
  and exists(select 1 from jsonb_array_elements(content) item
    where item->>'stage' in ('nextAction','reflection','free_notes') and item->>'submitted'='true'));
grant select on public.impact_entries to anon;
create policy "Visitors read public journal impacts" on public.impact_entries for select to anon
using (exists(select 1 from public.journal_entries e where e.id=linked_journal_entry_id and e.project_id=impact_entries.project_id));
create policy "Visitors enforce public journal impacts" on public.impact_entries as restrictive for select to anon
using (exists(select 1 from public.journal_entries e where e.id=linked_journal_entry_id and e.project_id=impact_entries.project_id));
commit;
