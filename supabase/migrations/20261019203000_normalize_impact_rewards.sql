begin;
insert into eco_reward_config(key,value)values('impact_cap',10)on conflict(key)do nothing;
create or replace function public.verified_impact_reward() returns trigger language plpgsql security definer set search_path=public as $$
declare e journal_entries%rowtype; points integer:=0; source text;
begin
 new.eco_points:=0;
 if length(trim(coalesce(new.title,'')))=0 or new.metric not in ('Energy','Water','Waste','Biological Growth','Education') or new.pattern_type not in ('Reduction','Substitution','Behavior Change','Capacity Building','Regeneration') or new.evidence_type not in ('Photo','Measurement','Calculation Estimate') or new.confidence_score not in ('Low','Medium','High') or new.linked_journal_entry_id is null or new.measurement is null or new.measurement<=0 or new.measurement::text in ('NaN','Infinity','-Infinity') or length(trim(coalesce(new.measurement_unit,'')))=0 then return new;end if;
 select * into e from journal_entries where id=new.linked_journal_entry_id and project_id=new.project_id and feed_ready for update;
 if e.id is null then return new;end if;
 source:=e.id::text||':'||lower(trim(new.metric));
 if exists(select 1 from eco_point_transactions where user_id=new.user_id and source_type='impact' and source_id=source) then
   select amount into new.eco_points from eco_point_transactions where user_id=new.user_id and source_type='impact' and source_id=source and details->>'impact_entry_id'=new.id::text;
   new.eco_points:=coalesce(new.eco_points,0);
   return new;
 end if;
 points:=reward_setting('impact_calculation',5);
 if exists(select 1 from qualifying_evidence(e.content)) then points:=points+reward_setting('impact_evidence',5);end if;
 points:=least(points,greatest(0,reward_setting('impact_cap',10)-(select coalesce(sum(amount),0) from eco_point_transactions where user_id=new.user_id and source_type='impact' and details->>'journal'=e.id::text)));
 if points<=0 then return new;end if;
 insert into eco_point_transactions(user_id,project_id,source_type,source_id,amount,details)values(new.user_id,new.project_id,'impact',source,points,jsonb_build_object('journal',e.id,'metric',new.metric,'quantity_bonus',false,'impact_entry_id',new.id))on conflict do nothing;
 new.eco_points:=points;
 return new;
end $$;
-- Bind any already awarded sources before normalizing older client estimates.
update eco_point_transactions t set details=t.details||jsonb_build_object('impact_entry_id',(select i.id from impact_entries i where i.user_id=t.user_id and i.linked_journal_entry_id::text||':'||lower(trim(i.metric))=t.source_id order by i.created_at,i.id limit 1)) where source_type='impact' and not(details ? 'impact_entry_id');
update impact_entries set eco_points=eco_points;
commit;
