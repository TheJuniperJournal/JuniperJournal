begin;

create table public.journal_edit_sessions (
 entry_id uuid not null references public.journal_entries(id) on delete cascade,
 session_id uuid not null,
 user_id uuid not null references auth.users(id) on delete cascade,
 section text not null check(length(section) between 1 and 80),
 editing boolean not null default false,
 seen_at timestamptz not null default now(),
 primary key(entry_id, session_id)
);
alter table public.journal_edit_sessions enable row level security;
-- Presence is available only through the authorized RPC, never a public table.
revoke all on public.journal_edit_sessions from anon, authenticated;
create index journal_edit_sessions_expiry on public.journal_edit_sessions(entry_id, seen_at);

create function public.assert_journal_editor(p_entry_id uuid)
returns void language plpgsql stable security definer set search_path=public as $$
begin
 if auth.uid() is null or not public.can_edit_journal_entry(p_entry_id) or
 not exists(select 1 from public.journal_entries e where e.id=p_entry_id and public.is_project_participant(e.project_id)) then
  raise exception 'Entry editing is not permitted' using errcode='42501';
 end if;
end $$;
revoke all on function public.assert_journal_editor(uuid) from public;

create function public.journal_collaboration_heartbeat(p_entry_id uuid,p_session_id uuid,p_section text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare own boolean; result jsonb;
begin
 perform public.assert_journal_editor(p_entry_id);
 if p_section is null or length(p_section) not between 1 and 80 then raise exception 'Invalid section'; end if;
 -- Every acquire/save/release serializes on the same journal row.
 perform 1 from public.journal_entries where id=p_entry_id for update;
 delete from public.journal_edit_sessions where entry_id=p_entry_id and seen_at<clock_timestamp()-interval '20 seconds';
 if exists(select 1 from public.journal_edit_sessions where entry_id=p_entry_id and session_id=p_session_id and user_id<>auth.uid()) then
  raise exception 'Invalid editor session' using errcode='42501';
 end if;
 own := p_section='free_notes' or not exists(
  select 1 from public.journal_edit_sessions where entry_id=p_entry_id and session_id<>p_session_id and section=p_section and editing
 );
 insert into public.journal_edit_sessions(entry_id,session_id,user_id,section,editing,seen_at)
 values(p_entry_id,p_session_id,auth.uid(),p_section,own,clock_timestamp())
 on conflict(entry_id,session_id) do update set section=excluded.section, editing=excluded.editing, seen_at=excluded.seen_at;
 select jsonb_build_object('owns_section',own,'entry',to_jsonb(e),'people',coalesce((
  select jsonb_agg(jsonb_build_object('session_id',s.session_id,'user_id',s.user_id,
    'name',coalesce(nullif(u.display_name,''),nullif(u.username,''),'Collaborator'),
    'avatar_url',u.avatar_url,'section',s.section,'editing',s.editing) order by s.seen_at)
  from public.journal_edit_sessions s left join public.profiles u on u.id=s.user_id
  where s.entry_id=p_entry_id and s.seen_at>clock_timestamp()-interval '20 seconds'
 ),'[]'::jsonb)) into result from public.journal_entries e where e.id=p_entry_id;
 return result;
end $$;

-- Three-way merge: untouched fields retain their latest value. Collections with
-- stable stage/id keys merge independently; unkeyed arrays conflict atomically.
-- No last-writer-wins fallback is allowed.
create function public.merge_journal_document(b jsonb,l jsonb,r jsonb)
returns jsonb language plpgsql immutable set search_path=public as $$
declare out_value jsonb; k text; bv jsonb; lv jsonb; rv jsonb; item jsonb;
 keys text[]; bp integer:=0; bs integer:=0; lp integer:=0; ls integer:=0;
 bt text; lt text; rt text; b_end integer; r_end integer; local_insert text;
begin
 if l is not distinct from b then return r; end if;
 if r is not distinct from b or l is not distinct from r then return l; end if;
 if jsonb_typeof(b)='object' and jsonb_typeof(l)='object' and jsonb_typeof(r)='object' then
  out_value:='{}';
  for k in select key from jsonb_object_keys(b||l||r) key loop
   -- Navigation belongs to a browser session, not a collaborator's cursor.
   if k='_navigation' then continue; end if;
   bv:=b->k; lv:=l->k; rv:=r->k;
   item:=public.merge_journal_document(bv,lv,rv);
   if item is not null then out_value:=out_value||jsonb_build_object(k,item); end if;
  end loop;
  return out_value;
 end if;
 if jsonb_typeof(b)='array' and jsonb_typeof(l)='array' and jsonb_typeof(r)='array'
 and not exists(select 1 from jsonb_array_elements(b||l||r) x where jsonb_typeof(x)<>'object' or coalesce(x->>'stage',x->>'id') is null)
 -- Duplicate identities cannot be merged safely.
 and not exists(select 1 from (select b a union all select l union all select r) a,
 lateral (select coalesce(x->>'stage',x->>'id') id from jsonb_array_elements(a.a) x group by 1 having count(*)>1) duplicate) then
  out_value:='[]'; keys:='{}';
  -- Remote order first, then local additions: both clients converge on server order.
  for item in select value from jsonb_array_elements(r||l||b) loop
   k:=coalesce(item->>'stage',item->>'id');
   if k=any(keys) then continue; end if;
   keys:=array_append(keys,k);
   select x into bv from jsonb_array_elements(b) x where coalesce(x->>'stage',x->>'id')=k;
   select x into lv from jsonb_array_elements(l) x where coalesce(x->>'stage',x->>'id')=k;
   select x into rv from jsonb_array_elements(r) x where coalesce(x->>'stage',x->>'id')=k;
   if k='_navigation' then item:=lv;
   else item:=public.merge_journal_document(bv,lv,rv); end if;
   if item is not null then out_value:=out_value||jsonb_build_array(item); end if;
  end loop;
  return out_value;
 end if;
 -- Plain text co-editing merges disjoint contiguous edits and concurrent inserts.
 -- An overlapping replacement reports a conflict instead of deleting either edit.
 if jsonb_typeof(b)='string' and jsonb_typeof(l)='string' and jsonb_typeof(r)='string' then
  bt:=b#>>'{}'; lt:=l#>>'{}'; rt:=r#>>'{}';
  while bp<least(length(bt),length(lt)) and substr(bt,bp+1,1)=substr(lt,bp+1,1) loop bp:=bp+1; end loop;
  while bs<least(length(bt)-bp,length(lt)-bp) and substr(bt,length(bt)-bs,1)=substr(lt,length(lt)-bs,1) loop bs:=bs+1; end loop;
  while lp<least(length(bt),length(rt)) and substr(bt,lp+1,1)=substr(rt,lp+1,1) loop lp:=lp+1; end loop;
  while ls<least(length(bt)-lp,length(rt)-lp) and substr(bt,length(bt)-ls,1)=substr(rt,length(rt)-ls,1) loop ls:=ls+1; end loop;
  b_end:=length(bt)-bs; r_end:=length(bt)-ls;
  local_insert:=substr(lt,bp+1,length(lt)-bp-bs);
  if bp>=r_end then
   bp:=bp+(length(rt)-length(bt)); b_end:=b_end+(length(rt)-length(bt));
  elsif b_end>lp then
   raise exception 'Overlapping text edits. Keep your local text and reload the latest entry.' using errcode='40001';
  end if;
  return to_jsonb(substr(rt,1,bp)||local_insert||substr(rt,b_end+1));
 end if;
 raise exception 'This section changed in another editor. Your local changes have been kept.' using errcode='40001';
end $$;
revoke all on function public.merge_journal_document(jsonb,jsonb,jsonb) from public;

create function public.save_collaborative_journal(p_entry_id uuid,p_session_id uuid,p_base jsonb,p_desired jsonb,p_complete boolean)
returns jsonb language plpgsql security definer set search_path=public as $$
declare e public.journal_entries; merged jsonb; stage text; row_data jsonb; old_row jsonb;
begin
 perform public.assert_journal_editor(p_entry_id);
 select * into e from public.journal_entries where id=p_entry_id for update;
 if not exists(select 1 from public.journal_edit_sessions where entry_id=p_entry_id and session_id=p_session_id and user_id=auth.uid() and editing and seen_at>clock_timestamp()-interval '20 seconds') then
  raise exception 'Your editing session expired. Reconnect before saving.' using errcode='42501';
 end if;
 for row_data in select value from jsonb_array_elements((p_desired->'content')||(p_base->'content')) loop
  stage:=row_data->>'stage';
  if stage is null or stage in ('_navigation','free_notes','participants') then continue; end if;
  select x into old_row from jsonb_array_elements(p_base->'content') x where x->>'stage'=stage;
  select x into row_data from jsonb_array_elements(p_desired->'content') x where x->>'stage'=stage;
  if row_data is distinct from old_row and exists(
    select 1 from public.journal_edit_sessions where entry_id=p_entry_id and session_id<>p_session_id and editing and section=stage and seen_at>clock_timestamp()-interval '20 seconds'
  ) then raise exception 'This section is being edited by someone else.' using errcode='40001'; end if;
 end loop;
 merged:=public.merge_journal_document(p_base,p_desired,jsonb_build_object('title',e.title,'content',e.content,'progress',e.progress));
 -- The publication flag may only be claimed by a save whose merged final stage
 -- remains submitted; existing reward/publication triggers retain authority.
 perform set_config('juniper.journal_editor_session',p_session_id::text,true);
 update public.journal_entries set title=merged->>'title',content=merged->'content',progress=merged->>'progress',
 feed_ready=p_complete and exists(select 1 from jsonb_array_elements(merged->'content') x where x->>'stage' in ('free_notes','nextAction','reflection') and x->>'submitted'='true'),
 updated_at=clock_timestamp() where id=p_entry_id returning * into e;
 return to_jsonb(e);
end $$;

create function public.release_journal_collaboration(p_entry_id uuid,p_session_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
 perform 1 from public.journal_entries where id=p_entry_id for update;
 delete from public.journal_edit_sessions where entry_id=p_entry_id and session_id=p_session_id and user_id=auth.uid();
end $$;

-- Older clients must not overwrite a document participating in a live session.
create function public.protect_active_journal_editors()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is not null and (new.content is distinct from old.content or new.title is distinct from old.title or new.progress is distinct from old.progress)
 and exists(select 1 from public.journal_edit_sessions where entry_id=old.id and seen_at>clock_timestamp()-interval '20 seconds')
 and not exists(select 1 from public.journal_edit_sessions where entry_id=old.id and user_id=auth.uid() and session_id::text=current_setting('juniper.journal_editor_session',true) and editing and seen_at>clock_timestamp()-interval '20 seconds') then
 raise exception 'Use the collaborative editor to update this entry.' using errcode='40001';
 end if;
 return new;
end $$;
create trigger protect_active_journal_editors before update on public.journal_entries for each row execute function public.protect_active_journal_editors();
revoke all on function public.journal_collaboration_heartbeat(uuid,uuid,text),public.save_collaborative_journal(uuid,uuid,jsonb,jsonb,boolean),public.release_journal_collaboration(uuid,uuid) from public;
grant execute on function public.journal_collaboration_heartbeat(uuid,uuid,text),public.save_collaborative_journal(uuid,uuid,jsonb,jsonb,boolean),public.release_journal_collaboration(uuid,uuid) to authenticated;
commit;
