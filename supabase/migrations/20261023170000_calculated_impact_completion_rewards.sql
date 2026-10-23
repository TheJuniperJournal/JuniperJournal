begin;
-- Calculate bounded server-side impact points using the assessment formula.
-- Preserve immutable awards and one award per journal/metric/user.
create or replace function public.verified_impact_reward() returns trigger language plpgsql security definer set search_path=public as $$
declare e journal_entries%rowtype; points integer:=0; source text; scale numeric; confidence numeric; multiplier numeric:=1;
begin
 new.eco_points:=0;
 if length(trim(coalesce(new.title,'')))=0 or new.metric not in ('Energy','Water','Waste','Biological Growth','Education') or new.pattern_type not in ('Reduction','Substitution','Behavior Change','Capacity Building','Regeneration') or new.evidence_type not in ('Photo','Measurement','Calculation Estimate') or new.confidence_score not in ('Low','Medium','High') or new.linked_journal_entry_id is null or new.measurement is null or new.measurement<=0 or new.measurement::text in ('NaN','Infinity','-Infinity') then return new;end if;
 if new.impact_scale not in ('Seed (Very Small)','Sapling (Small)','Grove (Moderate)','Forest (Large)','Watershed (Very Large)') then return new;end if;
 select * into e from journal_entries where id=new.linked_journal_entry_id and project_id=new.project_id and feed_ready for update;
 if e.id is null then return new;end if;
 source:=e.id::text||':'||lower(trim(new.metric));
 if exists(select 1 from eco_point_transactions where user_id=new.user_id and source_type='impact' and source_id=source) then
   select amount into new.eco_points from eco_point_transactions where user_id=new.user_id and source_type='impact' and source_id=source and details->>'impact_entry_id'=new.id::text;
   new.eco_points:=coalesce(new.eco_points,0);
   return new;
 end if;
 scale:=case new.impact_scale when 'Sapling (Small)' then 1.25 when 'Grove (Moderate)' then 1.5 when 'Forest (Large)' then 1.75 when 'Watershed (Very Large)' then 2.25 else 1 end;
 confidence:=case new.confidence_score when 'Low' then .70 when 'Medium' then .85 else 1 end;
 if new.measurement_unit in ('units','people') then
  multiplier:=least(1+.5*log(new.measurement+1),2);
 elsif new.measurement_unit is not null then
  if new.measurement_unit='kg' then
   multiplier:=case when new.measurement>=2500 then 2 when new.measurement>=1000 then 1.75 when new.measurement>=500 then 1.6 when new.measurement>=250 then 1.5 when new.measurement>=100 then 1.4 when new.measurement>=50 then 1.3 when new.measurement>=20 then 1.2 when new.measurement>=10 then 1.1 when new.measurement>=5 then 1.05 else 1 end;
  else
   multiplier:=case when new.measurement>=5000 then 2 when new.measurement>=2500 then 1.75 when new.measurement>=1000 then 1.6 when new.measurement>=500 then 1.5 when new.measurement>=250 then 1.4 when new.measurement>=100 then 1.3 when new.measurement>=50 then 1.2 when new.measurement>=25 then 1.1 when new.measurement>=10 then 1.05 else 1 end;
  end if;
 end if;
 points:=round(15*scale*confidence*multiplier);
 if points<=0 then return new;end if;
 insert into eco_point_transactions(user_id,project_id,source_type,source_id,amount,details)values(new.user_id,new.project_id,'impact',source,points,jsonb_build_object('journal',e.id,'metric',new.metric,'quantity_bonus',false,'impact_entry_id',new.id))on conflict do nothing;
 new.eco_points:=points;
 return new;
end $$;
-- Reconcile previously completed impacts that never received an award.
do $$ declare impact_id uuid; begin
 for impact_id in select i.id from impact_entries i join journal_entries e on e.id=i.linked_journal_entry_id and e.project_id=i.project_id where e.feed_ready and i.eco_points=0 order by i.created_at,i.id loop
  update impact_entries set eco_points=eco_points where id=impact_id;
 end loop;
end $$;
commit;
