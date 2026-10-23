begin;
do $$
declare owner_id uuid;guest_id uuid;pid uuid:=gen_random_uuid();eid uuid:=gen_random_uuid();aid uuid;session jsonb;submitted jsonb;again jsonb;total integer;
begin
 select id into owner_id from auth.users limit 1;
 select id into guest_id from auth.users where id<>owner_id limit 1;
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 insert into projects(id,user_id,project_name,problem_statement,project_type,visibility,difficulty,project_scale)values(pid,owner_id,'Rollback assessment test','Test','collaborative','private','Hard','Medium');
 insert into project_collaborators(project_id,user_id,invited_by,status,role)values(pid,guest_id,owner_id,'accepted','project_member');
 insert into journal_entries(id,project_id,user_id,title,progress,content,feed_ready)values(eid,pid,owner_id,'Numeric learning','Discovery','[{"stage":"learning","assessment":{"type":"numeric","data":{"question":"How many?","correct_answer":"10","min_value":"9","max_value":"11"}}},{"stage":"nextAction","submitted":true,"learned":"Test","challenges":"Test","nextSteps":"Test"}]',true);
 select id into aid from journal_assessments where journal_entry_id=eid;
 if aid is null then raise exception 'Assessment definition not extracted';end if;
 if (select content::text from journal_entries where id=eid) like '%correct_answer%' then raise exception 'Answer key leaked in journal content';end if;
 begin perform save_assessment_response(aid,'{"value":"10"}',true);raise exception 'Author earned participation rewards';exception when raise_exception then if SQLERRM='Author earned participation rewards' then raise;end if;end;
 perform set_config('request.jwt.claim.sub',guest_id::text,true);
 session:=assessment_session(aid);
 if session::text like '%correct_answer%' or session::text like '%min_value%' then raise exception 'Answer key leaked in session';end if;
 perform save_assessment_response(aid,'{"value":"10"}',false);
 submitted:=save_assessment_response(aid,'{"value":"10"}',true);
 if submitted->'response'->>'status'<>'evaluated' or submitted->'response'->>'correct'<>'true' then raise exception 'Numeric response not graded';end if;
 if (submitted->>'points')::integer<>10 then raise exception 'Correct reward not awarded';end if;
 again:=save_assessment_response(aid,'{"value":"999"}',true);
 if (again->>'points')::integer<>0 then raise exception 'Duplicate reward';end if;
 if again->'response'->'answer'->>'value'<>'10' then raise exception 'Submitted response overwritten';end if;
 select sum(amount) into total from eco_point_transactions where user_id=guest_id and source_type='assessment' and source_id=aid::text;
 if total<>10 then raise exception 'Incorrect reward ledger';end if;
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 update journal_entries set title='Edited completion' where id=eid;
 if(select count(*) from eco_point_transactions where user_id=owner_id and source_type='journal' and source_id=eid::text)<>1 then raise exception 'Completion award duplicated or missing';end if;
 begin update journal_entries set user_id=guest_id where id=eid;raise exception 'Creator changed';exception when raise_exception then if SQLERRM='Creator changed' then raise;end if;end;
end $$;
select 'Assessment keys protected; response persisted and server graded; author and duplicate rewards blocked; creator immutable' as result;

do $$
declare owner_id uuid; guest_id uuid; pid uuid:=gen_random_uuid(); eid uuid:=gen_random_uuid(); aid uuid; n integer; result jsonb; definition jsonb; answer jsonb;
begin
 select id into owner_id from auth.users limit 1;
 select id into guest_id from auth.users where id<>owner_id limit 1;
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 insert into projects(id,user_id,project_name,problem_statement,project_type,visibility,difficulty,project_scale) values(pid,owner_id,'Rollback rewards test','Test','collaborative','private','Hard','Large');
 insert into project_collaborators(project_id,user_id,invited_by,status,role) values(pid,guest_id,owner_id,'pending','project_member');
 insert into journal_entries(id,project_id,user_id,title,progress,content,feed_ready)values(eid,pid,owner_id,'Evidence cap','Discovery','[{"stage":"observe","involved":[]},{"stage":"nextAction","submitted":true,"supportingContext":[{"publicUrl":"https://example.test/a?token=1"},{"publicUrl":"https://example.test/a?token=2"},{"publicUrl":"https://example.test/b"},{"publicUrl":"https://example.test/c"}]}]',true);
 select amount into n from eco_point_transactions where user_id=owner_id and source_type='journal' and source_id=eid::text;
 if n<>49 then raise exception 'Expected base*Hard*Large+10 evidence =49, got %',n;end if;
 if exists(select 1 from eco_point_transactions where user_id=guest_id and source_id=eid::text)then raise exception 'Pending contributor rewarded';end if;
 select count(distinct value) into n from qualifying_evidence('[{"evidence":["https://x/1_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa_a.pdf","https://x/2_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa_b.pdf"]}]') value;
 if n<>1 then raise exception 'Same uploaded bytes not deduplicated';end if;
 select count(*) into n from qualifying_evidence('{"members":[{"avatar":"https://example.test/photo"}]}');
 if n<>0 then raise exception 'Avatar counted as evidence';end if;
 update project_collaborators set status='accepted' where project_id=pid and user_id=guest_id;
 for definition,answer in select * from(values
 ('{"type":"multiple_choice","data":{"question":"Choose","options":["A","B"],"correct_index":1}}'::jsonb,'{"index":1}'::jsonb),
 ('{"type":"multiple_choice","data":{"question":"Choose several","options":["A","B","C"],"allow_multiple":true,"correct_indices":[0,2]}}','{"indices":[2,0]}'),
 ('{"type":"true_false","data":{"questions":[{"question":"True?","correct_answer":true}]}}','{"values":[true]}'),
 ('{"type":"matching","data":{"top_items":["A"],"bottom_items":["B"],"correct_mapping":{"0":0}}}','{"mapping":{"0":0}}'),
 ('{"type":"paragraph","data":{"question":"Explain","max_characters":100}}','{"value":"Written response"}')
 )x(d,a) loop
 aid:=gen_random_uuid();
 insert into journal_assessments(id,journal_entry_id,author_id,slot,definition,public_definition) values(aid,eid,owner_id,aid::text,definition,redact_assessment_keys(definition));
 -- Attach the protected assessment reference to the published entry.
 update journal_entries set content=content||jsonb_build_array(jsonb_build_object('assessment_id',aid)) where id=eid;
 perform set_config('request.jwt.claim.sub',guest_id::text,true);
 result:=save_assessment_response(aid,answer,true);
 if definition->>'type'='paragraph' then
   if result->'response'->>'status'<>'submitted' or result->'response'->>'correct' is not null or (result->>'points')::int<>5 then raise exception 'Written response wrongly evaluated';end if;
 elsif result->'response'->>'correct'<>'true' or (result->>'points')::int<>10 then raise exception 'Objective grading failed for %',definition->>'type';end if;
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 end loop;
 perform set_config('platform.test.assessment',aid::text,true);
 perform set_config('request.jwt.claim.sub',guest_id::text,true);
end $$;
set local role authenticated;
do $$
begin
 if exists(select 1 from journal_assessments where id=current_setting('platform.test.assessment')::uuid) then raise exception 'Viewer can read private answer definition';end if;
 begin
 insert into eco_point_transactions(user_id,source_type,source_id,amount)values(auth.uid(),'forged','test',999);
 raise exception 'Client forged reward ledger';
 exception when insufficient_privilege then null;end;
end $$;
reset role;

select 'Evidence caps, upload deduplication, all assessment grades and authenticated ledger/key protection passed' as result;

do $$
declare owner_id uuid; guest_id uuid; pid uuid:=gen_random_uuid();eid uuid:=gen_random_uuid(); n integer;
begin
 select id into owner_id from auth.users limit 1;
 select id into guest_id from auth.users where id<>owner_id limit 1;
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 insert into projects(id,user_id,project_name,problem_statement,project_type,visibility) values(pid,owner_id,'Rollback contribution','Test','collaborative','private');
 insert into project_collaborators(project_id,user_id,invited_by,status,role) values(pid,guest_id,owner_id,'accepted','project_member');
 insert into journal_entries(id,project_id,user_id,title,progress,content,feed_ready) values(eid,pid,owner_id,'Confirmed contribution','Discovery',jsonb_build_array(jsonb_build_object('stage','observe','involved',jsonb_build_array(jsonb_build_object('id',guest_id)))),false);
 perform set_config('request.jwt.claim.sub',guest_id::text,true);
 perform confirm_journal_contribution(eid);
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 update journal_entries set content=content||'[{"stage":"nextAction","submitted":true}]'::jsonb,feed_ready=true where id=eid;
 select amount into n from eco_point_transactions where user_id=guest_id and source_type='journal' and source_id=eid::text;
 if n<>21 then raise exception 'Confirmed contribution expected 21, got %',n;end if;
 update journal_entries set content=content where id=eid;
 if(select count(*) from eco_point_transactions where source_type='journal' and source_id=eid::text)<>2 then raise exception 'Contributor snapshot not frozen';end if;
end $$;

rollback;
