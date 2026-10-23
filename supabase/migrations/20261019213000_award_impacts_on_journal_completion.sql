begin;
create or replace function public.award_completed_journal_impacts() returns trigger
language plpgsql security definer set search_path=public as $$
declare impact_id uuid;
begin
 if not new.feed_ready then return new; end if;
 if tg_op='UPDATE' and old.feed_ready then return new; end if;
 for impact_id in select id from public.impact_entries where linked_journal_entry_id=new.id and project_id=new.project_id order by created_at,id loop
  update public.impact_entries set eco_points=eco_points where id=impact_id;
 end loop;
 return new;
end $$;
revoke all on function public.award_completed_journal_impacts() from public;
create trigger award_completed_journal_impacts after insert or update of feed_ready on public.journal_entries for each row execute function public.award_completed_journal_impacts();
-- Reconcile eligible completed entries. Existing ledger uniqueness and caps apply.
do $$ declare impact_id uuid; begin
 for impact_id in select i.id from public.impact_entries i join public.journal_entries e on e.id=i.linked_journal_entry_id and e.project_id=i.project_id where e.feed_ready order by i.created_at,i.id loop
  update public.impact_entries set eco_points=eco_points where id=impact_id;
 end loop;
end $$;
commit;
