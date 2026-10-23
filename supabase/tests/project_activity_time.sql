begin;
do $$
declare p uuid; owner_id uuid; session_id uuid := gen_random_uuid(); value jsonb; baseline bigint;
begin
  select id,user_id into p,owner_id from public.projects where user_id is not null limit 1;
  if p is null then raise exception 'Test needs one project'; end if;
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  value := public.get_project_activity_time(p);
  baseline := (value->>'personal_seconds')::bigint;
  perform public.record_project_activity_time(p,session_id,30);
  perform public.record_project_activity_time(p,session_id,30);
  perform public.record_project_activity_time(p,session_id,10);
  value := public.record_project_activity_time(p,session_id,60);
  assert (value->>'personal_seconds')::bigint=baseline+60, 'Retries must not duplicate seconds';
  value := public.record_project_activity_time(p,gen_random_uuid(),20);
  assert (value->>'personal_seconds')::bigint=baseline+80, 'Sessions must accumulate';
  assert (value->>'participant')::boolean, 'Owner is participant';
  perform set_config('request.jwt.claim.sub','',true);
  begin
    perform public.record_project_activity_time(p,gen_random_uuid(),10);
    raise exception 'Anonymous write was accepted';
  exception when insufficient_privilege then null;
  end;
end;
$$;
rollback;
