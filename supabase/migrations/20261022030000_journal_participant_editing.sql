begin;
create or replace function public.journal_participant_ids(p_content jsonb)
returns text[] language sql immutable set search_path=public as $$
 select coalesce(array_agg(id order by id),'{}'::text[]) from (
 select distinct coalesce(x->>'id',x->>'user_id',case when jsonb_typeof(x)='string' then x#>>'{}' end) id
 from (
 select value x from jsonb_path_query(p_content,'lax $.**.involved[*]') as items(value)
 union all select value from jsonb_path_query(p_content,'lax $.**.involvedIds[*]') as items(value)
 union all select value from jsonb_path_query(p_content,'lax $.**.involved_ids[*]') as items(value)
 ) people
 ) ids where id is not null;
$$;
create or replace function public.can_edit_journal_entry(p_entry_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select auth.uid() is not null and exists(
 select 1 from public.journal_entries e join public.projects p on p.id=e.project_id where e.id=p_entry_id and (
   e.user_id=auth.uid() or p.user_id=auth.uid() or
   (public.is_project_participant(e.project_id) and auth.uid()::text=any(public.journal_participant_ids(e.content)))
 ));
$$;
revoke all on function public.can_edit_journal_entry(uuid) from public;
grant execute on function public.can_edit_journal_entry(uuid) to authenticated;
-- A restrictive policy prevents broader pre-existing member policies from granting
-- edit rights to members who are not participating in this entry.
create policy "Entry editors may update" on public.journal_entries for update to authenticated
 using(public.can_edit_journal_entry(id)) with check(public.can_edit_journal_entry(id));
create policy "Only entry editors update" on public.journal_entries as restrictive for update to authenticated
 using(public.can_edit_journal_entry(id)) with check(public.can_edit_journal_entry(id));
create or replace function public.protect_journal_identity()
returns trigger language plpgsql set search_path=public as $$
begin
 if new.id is distinct from old.id or new.project_id is distinct from old.project_id or new.user_id is distinct from old.user_id then
   raise exception 'An entry cannot change its author or project' using errcode='42501';
 end if;
 -- Editors may update entry content; only the author or project owner controls
 -- who else can edit. Removing one's own access cannot be used to bypass this.
 if public.journal_participant_ids(new.content) is distinct from public.journal_participant_ids(old.content)
    and auth.uid() is not null and old.user_id<>auth.uid()
    and not exists(select 1 from public.projects p where p.id=old.project_id and p.user_id=auth.uid()) then
   raise exception 'Only the entry author or project owner can change participants' using errcode='42501';
 end if;
 return new;
end;
$$;
create trigger protect_journal_identity before update on public.journal_entries for each row execute function public.protect_journal_identity();
create policy "Only authors or owners delete entries" on public.journal_entries as restrictive for delete to authenticated
using(user_id=auth.uid() or exists(select 1 from public.projects p where p.id=project_id and p.user_id=auth.uid()));
commit;
