
begin;
do $$
declare owner_id uuid;pid uuid:=gen_random_uuid();eid uuid:=gen_random_uuid();iid uuid;duplicate_id uuid;points numeric;
begin
 select id into owner_id from auth.users limit 1;
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 insert into projects(id,user_id,project_name,problem_statement,project_type,visibility)values(pid,owner_id,'Rollback impact','Test','solo','private');
 insert into journal_entries(id,project_id,user_id,title,progress,content,feed_ready)values(eid,pid,owner_id,'Impact evidence','Implementation','[{"stage":"nextAction","submitted":true,"evidence":["https://example.test/evidence.pdf"]}]',true);
 insert into impact_entries(project_id,user_id,title,metric,impact_scale,pattern_type,evidence_type,confidence_score,measurement,measurement_unit,eco_points,linked_journal_entry_id)values(pid,owner_id,'Validated impact','Energy','Seed (Very Small)','Reduction','Measurement','High',999999999,'kWh',999999,eid)returning id,eco_points into iid,points;
 if points<>10 then raise exception 'Impact should be capped at10, got %',points;end if;
 insert into impact_entries(project_id,user_id,title,metric,impact_scale,pattern_type,evidence_type,confidence_score,measurement,measurement_unit,eco_points,linked_journal_entry_id)values(pid,owner_id,'Duplicate','Energy','Seed (Very Small)','Reduction','Measurement','High',999999999,'kWh',999999,eid)returning id,eco_points into duplicate_id,points;
 if points<>0 then raise exception 'Duplicate impact rewarded';end if;
 update impact_entries set eco_points=999999 where id=duplicate_id returning eco_points into points;
 if points<>0 then raise exception 'Duplicate impact update inflated reward';end if;
 update impact_entries set measurement=2 where id=iid returning eco_points into points;
 if points<>10 then raise exception 'Original impact reward changed';end if;
 insert into impact_entries(project_id,user_id,title,metric,impact_scale,pattern_type,evidence_type,confidence_score,measurement,measurement_unit,eco_points,linked_journal_entry_id)values(pid,owner_id,'Second metric','Water','Seed (Very Small)','Reduction','Measurement','High',50,'kg',999999,eid)returning eco_points into points;
 if points<>0 then raise exception 'Entry impact cap exceeded';end if;
 if(select sum(amount) from eco_point_transactions where source_type='impact' and details->>'journal'=eid::text)<>10 then raise exception 'Impact ledger inconsistent';end if;
end $$;
do $$
declare owner_id uuid; pid uuid:=gen_random_uuid(); eid uuid:=gen_random_uuid(); iid uuid; points numeric;
begin
 select id into owner_id from auth.users limit 1;
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 insert into projects(id,user_id,project_name,problem_statement,project_type,visibility) values(pid,owner_id,'Rollback deferred impact','Test','solo','private');
 insert into journal_entries(id,project_id,user_id,title,progress,content,feed_ready) values(eid,pid,owner_id,'Deferred impact','Implementation','[{"stage":"reflection","submitted":false}]',false);
 insert into impact_entries(project_id,user_id,title,metric,impact_scale,pattern_type,evidence_type,confidence_score,measurement,measurement_unit,eco_points,linked_journal_entry_id) values(pid,owner_id,'Draft impact','Biological Growth','Sapling (Small)','Behavior Change','Photo','Medium',111111,'people',0,eid) returning id,eco_points into iid,points;
 if points<>0 then raise exception 'Draft awarded points'; end if;
 update journal_entries set content='[{"stage":"reflection","submitted":true,"evidence":["https://example.test/evidence.pdf"]}]',feed_ready=true where id=eid;
 select eco_points into points from impact_entries where id=iid;
 if points<>10 then raise exception 'Completion did not award deferred impact: %',points; end if;
 update journal_entries set feed_ready=true where id=eid;
 if(select sum(amount) from eco_point_transactions where source_type='impact' and details->>'journal'=eid::text)<>10 then raise exception 'Completion repeated reward'; end if;
end $$;
select 'Impact completion awards, quantity inflation, duplicates and per-entry cap verified' as result;
rollback;
