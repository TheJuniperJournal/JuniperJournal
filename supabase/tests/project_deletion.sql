-- Creates disposable fixtures and rolls back every change.
begin;
do $$
declare base public.projects%rowtype; p uuid := gen_random_uuid(); removed uuid;
begin
  select * into base from public.projects where user_id is not null limit 1;
  if base.id is null then raise exception 'An owned project is required'; end if;
  perform set_config('request.jwt.claim.sub',base.user_id::text,true);
  insert into public.projects select (jsonb_populate_record(null::public.projects,
    to_jsonb(base)||jsonb_build_object('id',p,'project_name','Rollback deletion test'))).*;
  insert into public.journal_entries(project_id,user_id,title,content)
    values(p,base.user_id,'Rollback test','[]');
  execute 'set local role authenticated';
  delete from public.projects where id=p and user_id=base.user_id returning id into removed;
  if removed is distinct from p then raise exception 'Owner deletion did not remove project'; end if;
  if exists(select 1 from public.journal_entries where project_id=p) then
    raise exception 'Project journals were not cascaded';
  end if;
  execute 'reset role';
end $$;
select 'Atomic owner deletion and journal cleanup passed; all test changes rolled back' as result;
rollback;
