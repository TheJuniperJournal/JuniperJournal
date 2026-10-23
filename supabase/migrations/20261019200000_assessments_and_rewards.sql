begin;
create table public.eco_reward_config(key text primary key,value numeric not null check(value>=0));
insert into eco_reward_config values('journal_base',20),('difficulty_medium',1.25),('difficulty_hard',1.5),('scale_medium',1.15),('scale_large',1.3),('contributor_step',.05),('contributor_cap',1.25),('evidence_each',5),('evidence_cap',10),('assessment_completion',5),('assessment_correct',5),('impact_cap',10),('impact_calculation',5),('impact_evidence',5);
alter table eco_reward_config enable row level security;
create policy "Reward configuration readable" on eco_reward_config for select using(true);
grant select on eco_reward_config to authenticated;
create table public.eco_point_transactions(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),project_id uuid references projects(id) on delete set null,
 source_type text not null,source_id text not null,amount integer not null,details jsonb not null default '{}',created_at timestamptz not null default now(),
 unique(user_id,source_type,source_id)
);
alter table eco_point_transactions enable row level security;
create policy "Users read their reward history" on eco_point_transactions for select to authenticated using(user_id=auth.uid());
grant select on eco_point_transactions to authenticated;
create or replace function public.reward_setting(p_key text,p_default numeric) returns numeric language sql stable security definer set search_path=public as $$select coalesce((select value from eco_reward_config where key=p_key),p_default)$$;
create or replace function public.eco_points_summary(p_user_id uuid default auth.uid()) returns jsonb language plpgsql stable security definer set search_path=public as $$
begin
 if p_user_id is distinct from auth.uid() and not exists(select 1 from profiles where id=p_user_id and is_public_profile) then return jsonb_build_object('total',0,'subjects','{}'::jsonb);end if;
 return jsonb_build_object('total',(select coalesce(sum(amount),0) from eco_point_transactions where user_id=p_user_id),'subjects',coalesce((select jsonb_object_agg(subject,total) from(select coalesce(split_part(p.tags[1],'|',1),'Other') subject,sum(t.amount) total from eco_point_transactions t left join projects p on p.id=t.project_id where t.user_id=p_user_id group by 1)x),'{}'));
end $$;

create or replace function public.qualifying_evidence(node jsonb,in_evidence boolean default false)returns setof text language plpgsql immutable set search_path=public as $$
declare k text;v jsonb;active boolean:=in_evidence;url text;hash text;
begin
 if jsonb_typeof(node)='object' then
   active:=active or lower(coalesce(node->>'type','')) in ('image','images','link','video','file','pdf','document');
   for k,v in select * from jsonb_each(node) loop
     return query select * from qualifying_evidence(v,active or k in ('evidence','supportingContext','supporting_context','attachments','images','files'));
   end loop;
 elsif jsonb_typeof(node)='array' then
   for v in select value from jsonb_array_elements(node) loop return query select * from qualifying_evidence(v,active);end loop;
 elsif active and jsonb_typeof(node)='string' then
   url:=trim(both '"' from node::text);
   if url ~ '^https?://' then
     hash:=substring(url from '_([a-f0-9]{64})_');
     return next coalesce('sha256:'||hash,regexp_replace(regexp_replace(url,'[?#].*$',''),'/object/(sign|public)/','/object/'));
   end if;
 end if;
end $$;

-- The ledger freezes the first qualifying completion; edits cannot re-award it.
create or replace function public.journal_reward_snapshot()
returns trigger language plpgsql security definer set search_path=public as $$
declare p projects%rowtype; diff numeric:=1; scale numeric:=1; collaboration numeric:=1; evidence integer:=0; points integer; ids uuid[]; contributor uuid;
begin
 if not new.feed_ready or new.feed_published_at is null then return new;end if;
 if exists(select 1 from eco_point_transactions where source_type='journal' and source_id=new.id::text) then return new;end if;
 select * into p from projects where id=new.project_id;
 diff:=case lower(coalesce(p.difficulty,'')) when 'hard' then reward_setting('difficulty_hard',1.5) when 'moderate' then reward_setting('difficulty_medium',1.25) when 'medium' then reward_setting('difficulty_medium',1.25) else 1 end;
 scale:=case lower(coalesce(p.project_scale,'')) when 'large' then reward_setting('scale_large',1.3) when 'medium' then reward_setting('scale_medium',1.15) else 1 end;
 -- Only explicitly confirmed participation can reward another member.
 select coalesce(array_agg(user_id),'{}') into ids from journal_contributions where journal_entry_id=new.id and status='confirmed' and user_id<>new.user_id and exists(select 1 from project_collaborators c where c.project_id=new.project_id and c.user_id=journal_contributions.user_id and c.status='accepted');
 collaboration:=least(reward_setting('contributor_cap',1.25),1+cardinality(ids)*reward_setting('contributor_step',.05));
 select least(reward_setting('evidence_cap',10),count(distinct value)*reward_setting('evidence_each',5))::integer into evidence from qualifying_evidence(new.content) value;

 points:=round(reward_setting('journal_base',20)*diff*scale*collaboration+evidence);
 insert into eco_point_transactions(user_id,project_id,source_type,source_id,amount,details) values(new.user_id,new.project_id,'journal',new.id::text,points,jsonb_build_object('base',20,'difficulty',diff,'scale',scale,'collaboration',collaboration,'evidence',evidence)) on conflict do nothing;
 foreach contributor in array ids loop
  insert into eco_point_transactions(user_id,project_id,source_type,source_id,amount,details)values(contributor,new.project_id,'journal',new.id::text,points,jsonb_build_object('confirmed_contribution',true))on conflict do nothing;
 end loop;
 return new;
end $$;
create table public.journal_contributions(
 journal_entry_id uuid not null references journal_entries(id) on delete cascade,user_id uuid not null references auth.users(id),status text not null default 'pending' check(status in ('pending','confirmed')),confirmed_at timestamptz,primary key(journal_entry_id,user_id)
);
alter table journal_contributions enable row level security;
create policy "Contributors see own participation" on journal_contributions for select to authenticated using(user_id=auth.uid());
grant select on journal_contributions to authenticated;

create table public.journal_assessments(
 id uuid primary key,journal_entry_id uuid not null references journal_entries(id) on delete cascade deferrable initially deferred,
 author_id uuid not null references auth.users(id),slot text not null,definition jsonb not null,public_definition jsonb not null,
 unique(journal_entry_id,slot)
);
alter table journal_assessments enable row level security;
create policy "Authors read assessment definitions" on journal_assessments for select to authenticated using(author_id=auth.uid() or exists(select 1 from journal_entries e where e.id=journal_entry_id and can_manage_project(e.project_id)));
grant select on journal_assessments to authenticated;
create table public.assessment_responses(
 assessment_id uuid not null references journal_assessments(id) on delete cascade,user_id uuid not null references auth.users(id),answer jsonb not null default '{}',
 status text not null check(status in ('in_progress','submitted','evaluated')),correct boolean,submitted_at timestamptz,updated_at timestamptz not null default now(),primary key(assessment_id,user_id)
);
alter table assessment_responses enable row level security;
create policy "Users read own responses" on assessment_responses for select to authenticated using(user_id=auth.uid());
grant select on assessment_responses to authenticated;

create or replace function public.redact_assessment_keys(node jsonb) returns jsonb language plpgsql immutable set search_path=public as $$
declare result jsonb; k text;v jsonb;
begin
 if jsonb_typeof(node)='array' then select coalesce(jsonb_agg(redact_assessment_keys(value)),'[]') into result from jsonb_array_elements(node);return result;
 elsif jsonb_typeof(node)='object' then result:='{}';for k,v in select * from jsonb_each(node) loop
 if k not in ('correct_answer','correct_index','correct_indices','correct_mapping','explanation','min_value','max_value') then result:=result||jsonb_build_object(k,redact_assessment_keys(v));end if;end loop;return result;
 end if;return node;
end $$;
create or replace function public.secure_journal_content(node jsonb,eid uuid,author uuid,slot text default '') returns jsonb language plpgsql security definer set search_path=public as $$
declare result jsonb; k text;v jsonb; i integer:=0; aid uuid; existing jsonb; definition jsonb;
begin
 if jsonb_typeof(node)='object' then
  if node->>'type' in ('numeric','matching','true_false','paragraph','short_answer','multiple_choice','multiple_selection') and jsonb_typeof(node->'data')='object' then
   aid:=md5(eid::text||':'||slot)::uuid;
   if coalesce(node->>'assessment_id','') ~ '^[0-9a-fA-F-]{36}$' and exists(select 1 from journal_assessments where id=(node->>'assessment_id')::uuid and journal_entry_id=eid) then aid:=(node->>'assessment_id')::uuid;end if;
   select a.definition into existing from journal_assessments a where a.id=aid;
   definition:=node-'assessment_id';
   if existing is not null and (auth.uid() is distinct from author and auth.uid() is not null) then
     definition:=existing;
   elsif existing is not null and not(node::text ~ 'correct_(answer|index|indices|mapping)') then
     definition:=existing||jsonb_build_object('data',(existing->'data')||(node->'data'));
   end if;
   result:=redact_assessment_keys(definition)||jsonb_build_object('assessment_id',aid,'data',redact_assessment_keys(definition->'data')||jsonb_build_object('answer_key_redacted',true));
   insert into journal_assessments(id,journal_entry_id,author_id,slot,definition,public_definition)values(aid,eid,author,slot,definition,result)
    on conflict(id) do update set definition=excluded.definition,public_definition=excluded.public_definition;
   return result;
  end if;
  result:='{}';for k,v in select * from jsonb_each(node) loop result:=result||jsonb_build_object(k,secure_journal_content(v,eid,author,slot||'.'||k));end loop;return result;
 elsif jsonb_typeof(node)='array' then result:='[]';for v in select value from jsonb_array_elements(node) loop result:=result||jsonb_build_array(secure_journal_content(v,eid,author,slot||'.'||i));i:=i+1;end loop;return result;
 end if;return node;
end $$;
create or replace function public.protect_journal_author_and_assessments() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if new.feed_ready and (length(trim(new.title))=0 or not exists(select 1 from jsonb_array_elements(new.content) x where x->>'stage' in ('nextAction','reflection','free_notes') and x->>'submitted'='true')) then new.feed_ready:=false;end if;
 if TG_OP='UPDATE' and new.user_id is distinct from old.user_id then raise exception 'The original journal author cannot be changed';end if;
 new.content:=secure_journal_content(new.content,new.id,new.user_id);
 return new;
end $$;
create trigger protect_journal_author_and_assessments before insert or update of content,user_id,feed_ready on journal_entries for each row execute function protect_journal_author_and_assessments();

create or replace function public.can_open_assessment(aid uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from journal_assessments a join journal_entries e on e.id=a.journal_entry_id where a.id=aid and e.content::text like '%'||a.id::text||'%' and (e.user_id=auth.uid() or is_project_participant(e.project_id) or journal_feed_entry_allowed(e.id,array[(select user_id from projects where id=e.project_id)],null)));
$$;
create or replace function public.assessment_session(p_id uuid) returns jsonb language plpgsql stable security definer set search_path=public as $$
declare a journal_assessments%rowtype; response jsonb;
begin
 if not can_open_assessment(p_id) then raise exception 'Assessment unavailable';end if;
 select * into a from journal_assessments where id=p_id;
 select to_jsonb(r) into response from assessment_responses r where assessment_id=p_id and user_id=auth.uid();
 return jsonb_build_object('assessment',a.public_definition,'author_preview',a.author_id=auth.uid(),'response',response);
end $$;
create or replace function public.assessment_author_definitions(p_entry_ids uuid[]) returns jsonb language sql stable security definer set search_path=public as $$
 select coalesce(jsonb_object_agg(a.id::text,a.definition||jsonb_build_object('assessment_id',a.id)),'{}') from journal_assessments a join journal_entries e on e.id=a.journal_entry_id where a.journal_entry_id=any(p_entry_ids) and (a.author_id=auth.uid() or can_manage_project(e.project_id));
$$;
create or replace function public.save_assessment_response(p_id uuid,p_answer jsonb,p_submit boolean default false) returns jsonb language plpgsql security definer set search_path=public as $$
declare a journal_assessments%rowtype;e journal_entries%rowtype; d jsonb;kind text;valid boolean:=false;correct boolean;points integer:=0;existing assessment_responses%rowtype; response assessment_responses%rowtype;
begin
 if auth.uid() is null or not can_open_assessment(p_id) then raise exception 'Sign in with access to this assessment';end if;
 select * into a from journal_assessments where id=p_id for update;select * into e from journal_entries where id=a.journal_entry_id;
 if a.author_id=auth.uid() then raise exception 'Author preview does not save real responses or rewards';end if;
 if not e.feed_ready then raise exception 'This assessment is not published yet';end if;
 select * into existing from assessment_responses where assessment_id=p_id and user_id=auth.uid();
 if existing.status in ('submitted','evaluated') then return jsonb_build_object('response',to_jsonb(existing),'points',0);end if;
 d:=a.definition->'data';kind:=a.definition->>'type';
 if kind='multiple_choice' and d->>'allow_multiple'='true' then kind:='multiple_selection';end if;
 if kind='numeric' then
  valid:=coalesce(p_answer->>'value','') ~ '^-?([0-9]+(\.[0-9]*)?|\.[0-9]+)$';
  if valid then correct:=(p_answer->>'value')::numeric between (d->>'min_value')::numeric and (d->>'max_value')::numeric;end if;
 elsif kind in ('paragraph','short_answer') then valid:=length(trim(coalesce(p_answer->>'value',''))) between 1 and coalesce((d->>'max_characters')::integer,10000);correct:=null;
 elsif kind='multiple_choice' then
  valid:=coalesce(p_answer->>'index','') ~ '^\d+$' and (p_answer->>'index')::int<jsonb_array_length(d->'options');
  if valid then correct:=(p_answer->>'index')::int=(d->>'correct_index')::int;end if;
 elsif kind='multiple_selection' then
  valid:=jsonb_typeof(p_answer->'indices')='array' and jsonb_array_length(p_answer->'indices')>0 and not exists(select 1 from jsonb_array_elements(p_answer->'indices') v where v::text !~ '^\d+$' or (v::text)::int>=jsonb_array_length(d->'options'));
  correct:=valid and (select array_agg(distinct v::text order by v::text) from jsonb_array_elements(p_answer->'indices') v)=(select array_agg(distinct v::text order by v::text)from jsonb_array_elements(d->'correct_indices')v);
 elsif kind='true_false' then
  valid:=jsonb_typeof(p_answer->'values')='array' and jsonb_array_length(p_answer->'values')=jsonb_array_length(d->'questions') and not exists(select 1 from jsonb_array_elements(p_answer->'values')v where jsonb_typeof(v)<>'boolean');
  correct:=valid and not exists(select 1 from jsonb_array_elements(d->'questions')with ordinality q(v,n) where (p_answer->'values')->(n::int-1) is distinct from v->'correct_answer');
 elsif kind='matching' then
  valid:=jsonb_typeof(p_answer->'mapping')='object' and (select count(*) from jsonb_object_keys(p_answer->'mapping'))=jsonb_array_length(d->'top_items');
  correct:=valid and p_answer->'mapping'=d->'correct_mapping';
 end if;
 if p_submit and not coalesce(valid,false) then raise exception 'Complete the required response with valid values';end if;
 insert into assessment_responses(assessment_id,user_id,answer,status,correct,submitted_at)values(p_id,auth.uid(),p_answer,case when not p_submit then 'in_progress' when correct is null then 'submitted' else 'evaluated' end,case when p_submit then correct end,case when p_submit then now() end)
 on conflict(assessment_id,user_id) do update set answer=excluded.answer,status=excluded.status,correct=excluded.correct,submitted_at=excluded.submitted_at,updated_at=now() returning * into response;
 if p_submit then
  points:=reward_setting('assessment_completion',5)+case when correct then reward_setting('assessment_correct',5) else 0 end;
  insert into eco_point_transactions(user_id,project_id,source_type,source_id,amount,details)values(auth.uid(),e.project_id,'assessment',p_id::text,points,jsonb_build_object('correct',correct))on conflict do nothing;
 end if;
 return jsonb_build_object('response',to_jsonb(response),'points',points);
end $$;
-- Existing entries retain their authored content, with answer keys moved behind
-- author-only policies. This does not create responses or historical rewards.
update journal_entries set content=content where content::text like '%"assessment"%';
create trigger journal_reward_snapshot after insert or update of content,feed_ready on journal_entries for each row execute function journal_reward_snapshot();

create or replace function public.confirm_journal_contribution(p_entry_id uuid)returns void language plpgsql security definer set search_path=public as $$
declare e journal_entries%rowtype;
begin
 select * into e from journal_entries where id=p_entry_id;
 if e.user_id=auth.uid() or not is_project_participant(e.project_id) then raise exception 'Accepted project membership required';end if;
 if not exists(select 1 from jsonb_path_query(e.content,'lax $.**.involved[*]') x where x->>'id'=auth.uid()::text) then raise exception 'You are not listed as a contributor';end if;
 insert into journal_contributions(journal_entry_id,user_id,status,confirmed_at)values(e.id,auth.uid(),'confirmed',now())on conflict(journal_entry_id,user_id) do update set status='confirmed',confirmed_at=now();
end $$;

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
create trigger verified_impact_reward before insert or update on impact_entries for each row execute function verified_impact_reward();

create or replace function public.adjust_eco_points(p_transaction_id uuid,p_amount integer,p_reason text) returns void language plpgsql security definer set search_path=public as $$
declare t eco_point_transactions%rowtype;
begin
 if coalesce(auth.role(),'')<>'service_role' then raise exception 'Service administration required';end if;
 if length(trim(p_reason))<5 then raise exception 'An adjustment reason is required';end if;
 select * into t from eco_point_transactions where id=p_transaction_id for update;
 if t.id is null then raise exception 'Transaction unavailable';end if;
 insert into eco_point_transactions(user_id,project_id,source_type,source_id,amount,details)values(t.user_id,t.project_id,'adjustment',p_transaction_id::text||':'||md5(p_reason),p_amount,jsonb_build_object('reason',p_reason,'original_transaction',t.id))on conflict do nothing;
end $$;
revoke all on function public.adjust_eco_points(uuid,integer,text),public.verified_impact_reward() from public;
grant execute on function public.adjust_eco_points(uuid,integer,text) to service_role;

alter table eco_point_transactions add column announced_at timestamptz;
create or replace function public.claim_eco_reward_notice(p_source text,p_id text)returns integer language plpgsql security definer set search_path=public as $$
declare points integer;
begin
 with claimed as(update eco_point_transactions set announced_at=now() where user_id=auth.uid() and source_type=p_source and source_id=p_id and announced_at is null returning amount)
 select coalesce(sum(amount),0)::integer into points from claimed;
 return points;
end $$;
revoke all on function claim_eco_reward_notice(text,text) from public;
grant execute on function claim_eco_reward_notice(text,text) to authenticated;

-- A member confirms their own selected contribution by saving that entry.
create or replace function public.sync_journal_contributions()returns trigger language plpgsql security definer set search_path=public as $$
begin
 if auth.uid()<>new.user_id and is_project_participant(new.project_id) and exists(select 1 from jsonb_path_query(new.content,'lax $.**.involved[*]') x where x->>'id'=auth.uid()::text) then
 insert into journal_contributions(journal_entry_id,user_id,status,confirmed_at)values(new.id,auth.uid(),'confirmed',now())on conflict(journal_entry_id,user_id)do update set status='confirmed',confirmed_at=now();end if;
 return new;
end $$;
create trigger a_sync_journal_contributions after insert or update of content on journal_entries for each row execute function sync_journal_contributions();
revoke all on function sync_journal_contributions() from public;
-- Preserve qualifying historical completion totals without crediting drafts or
-- retrospectively rewarding unconfirmed project members.
update journal_entries set content=content where feed_ready and feed_published_at is not null;

create or replace function public.journal_entry_rewards(p_project_id uuid)returns jsonb language plpgsql stable security definer set search_path=public as $$
begin
 if not(can_view_project_audience(p_project_id) or is_project_participant(p_project_id)) then raise exception 'Project access required';end if;
 return coalesce((select jsonb_object_agg(e.id::text,t.amount)from journal_entries e join eco_point_transactions t on t.source_type='journal' and t.source_id=e.id::text and t.user_id=e.user_id where e.project_id=p_project_id),'{}');
end $$;
revoke all on function journal_entry_rewards(uuid) from public;
grant execute on function journal_entry_rewards(uuid) to authenticated;

-- Internal recursion/key-writing/reward functions are never executable by clients.
revoke all on function qualifying_evidence(jsonb,boolean) from public;
revoke all on function secure_journal_content(jsonb,uuid,uuid,text),redact_assessment_keys(jsonb),reward_setting(text,numeric),journal_reward_snapshot(),protect_journal_author_and_assessments() from public;
revoke all on function eco_points_summary(uuid),assessment_session(uuid),assessment_author_definitions(uuid[]),save_assessment_response(uuid,jsonb,boolean),confirm_journal_contribution(uuid),can_open_assessment(uuid) from public;
grant execute on function eco_points_summary(uuid),assessment_session(uuid),assessment_author_definitions(uuid[]),save_assessment_response(uuid,jsonb,boolean),confirm_journal_contribution(uuid),can_open_assessment(uuid) to authenticated;
commit;
