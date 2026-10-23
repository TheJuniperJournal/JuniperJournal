begin;
do $$
declare p uuid; u uuid; n int; after_like int;
begin
  select id,user_id into p,u from public.projects where user_id is not null limit 1;
  if p is null then raise exception 'An owned project is required for this rollback test'; end if;
  perform set_config('request.jwt.claim.sub',u::text,true);
  perform public.unlike_project(p);
  select coalesce(likes,0) into n from public.projects where id=p;
  perform public.like_project(p);
  perform public.like_project(p);
  select likes into after_like from public.projects where id=p;
  if after_like <> n+1 then raise exception 'Repeated self-like changed count incorrectly'; end if;
  if (select count(*) from public.project_likes where project_id=p and user_id=u) <> 1 then
    raise exception 'Expected exactly one self-like';
  end if;
  perform public.unlike_project(p);
  perform public.unlike_project(p);
  if (select likes from public.projects where id=p) <> n then
    raise exception 'Repeated unlike changed count incorrectly';
  end if;
end $$;
select 'Self-like, duplicate prevention and unlike passed (rolled back)' as result;
rollback;
