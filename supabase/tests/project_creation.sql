-- Run as postgres. Fixtures and identity changes are always rolled back.
begin;
select set_config('request.jwt.claim.sub',(select id::text from auth.users limit 1),true);
select set_config('juniper.test_other_owner',(select id::text from auth.users where id<>auth.uid() limit 1),true);
set local role authenticated;
do $$
declare kind text; audience text; saved uuid;
begin
  foreach kind in array array['solo','collaborative'] loop
    foreach audience in array array['private','shared','public'] loop
      insert into public.projects(user_id,project_name,problem_statement,tags,project_type,community_links,visibility)
        values(auth.uid(),'Rollback creation test','Temporary diagnostic',array['Engineering & Design'],kind,'[]'::jsonb,audience)
        returning id into saved;
      if saved is null then raise exception 'Creation did not return a project'; end if;
    end loop;
  end loop;
  if nullif(current_setting('juniper.test_other_owner'),'') is not null then
    begin
      insert into public.projects(user_id,project_name,problem_statement,tags,visibility)
        values(current_setting('juniper.test_other_owner')::uuid,'Forbidden creation','Temporary diagnostic',array['Engineering & Design'],'private');
      raise exception 'Creating a project for another owner was allowed';
    exception when insufficient_privilege then null;
    end;
  end if;
end $$;
select 'Authenticated creation returns rows for all six type/visibility combinations; owner spoofing denied' as result;
rollback;
