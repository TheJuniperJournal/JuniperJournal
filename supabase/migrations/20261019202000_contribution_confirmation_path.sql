begin;
create or replace function public.confirm_journal_contribution(p_entry_id uuid)returns void language plpgsql security definer set search_path=public as $$
declare e journal_entries%rowtype;
begin
 select * into e from journal_entries where id=p_entry_id;
 if e.user_id=auth.uid() or not is_project_participant(e.project_id) then raise exception 'Accepted project membership required';end if;
 if not exists(select 1 from jsonb_path_query(e.content,'lax $.**.involved[*]') x where x->>'id'=auth.uid()::text) then raise exception 'You are not listed as a contributor';end if;
 insert into journal_contributions(journal_entry_id,user_id,status,confirmed_at)values(e.id,auth.uid(),'confirmed',now())on conflict(journal_entry_id,user_id) do update set status='confirmed',confirmed_at=now();
end $$;

commit;
