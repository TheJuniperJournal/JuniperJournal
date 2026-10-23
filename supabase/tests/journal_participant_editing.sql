begin;
do $$
declare project uuid; owner_id uuid; participant uuid; entry uuid:=gen_random_uuid();
begin
 assert public.journal_participant_ids('[{"stage":"overview","involved":[{"id":"b"},{"id":"a"}]}]'::jsonb)=array['a','b'], 'Participant extraction must be stable';
 select id,user_id into project,owner_id from public.projects where user_id is not null limit 1;
 select id into participant from auth.users where id<>owner_id limit 1;
 if project is null or participant is null then raise exception 'Test requires a project and two users'; end if;
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 insert into public.project_collaborators(project_id,user_id,status,invited_by) values(project,participant,'accepted',owner_id)
 on conflict(project_id,user_id) do update set status='accepted';
 insert into public.journal_entries(id,project_id,user_id,title,content,progress,feed_ready)
 values(entry,project,owner_id,'Shared entry',jsonb_build_array(jsonb_build_object('stage','overview','involved',jsonb_build_array(jsonb_build_object('id',participant)))),'implementation',false);
 perform set_config('request.jwt.claim.sub',participant::text,true);
 assert public.can_edit_journal_entry(entry), 'Selected accepted participant can edit';
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 update public.journal_entries set content='[{"stage":"overview","involved":[]}]'::jsonb where id=entry;
 perform set_config('request.jwt.claim.sub',participant::text,true);
 assert not public.can_edit_journal_entry(entry), 'Removing involvement revokes edit access';
end;
$$;
rollback;
