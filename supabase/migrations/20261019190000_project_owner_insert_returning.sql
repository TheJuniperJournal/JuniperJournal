begin;

-- INSERT ... RETURNING evaluates SELECT policies before a lookup function can
-- see the newly inserted project. Check ownership on the row itself first.
alter policy "Enforce project audience" on public.projects
  using (user_id = auth.uid() or public.can_view_project_audience(id));

commit;
