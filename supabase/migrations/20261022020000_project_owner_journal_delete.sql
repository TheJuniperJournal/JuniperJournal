-- Entry authors retain deletion rights; project owners can manage project entries.
create policy "Authors or project owners delete journal entries"
on public.journal_entries for delete to authenticated
using (user_id=auth.uid() or exists(
 select 1 from public.projects p where p.id=project_id and p.user_id=auth.uid()
));
