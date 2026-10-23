-- Disposable auth user only, all rows and deletion rolled back.
begin;
select set_config('test.user',gen_random_uuid()::text,true);
insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
 values(current_setting('test.user')::uuid,'authenticated','authenticated',
 'launch-audit-'||current_setting('test.user')||'@example.invalid',
 '{"provider":"email","providers":["email"]}',
 jsonb_build_object('username','audit_'||replace(current_setting('test.user'),'-',''),'display_name','Disposable Launch Audit'),now(),now());
select set_config('request.jwt.claim.sub',current_setting('test.user'),true);
set local role authenticated;
insert into public.projects(user_id,project_name,problem_statement,tags,project_type,community_links,visibility)
 values(auth.uid(),'Disposable deletion audit','Rollback only',array['Engineering & Design'],'solo','[]'::jsonb,'private');
insert into public.journal_entries(project_id,user_id,title,content)
 select id,auth.uid(),'Disposable journal','[]'::jsonb from public.projects where user_id=auth.uid();
do $$ begin
 begin
  insert into storage.objects(bucket_id,name,owner_id)
   values('images','launch-audit/'||gen_random_uuid()::text,current_setting('test.user'));
  perform public.delete_user();
  raise exception 'Owned uploads were orphaned';
 exception when raise_exception then
  assert SQLERRM='Remove uploaded files before deleting this account','Account deletion must require file cleanup first';
 end;
end $$;
select public.delete_user();
reset role;
do $$ begin
 assert not exists(select 1 from auth.users where id=current_setting('test.user')::uuid),'Account remains after deletion';
 assert not exists(select 1 from public.profiles where id=current_setting('test.user')::uuid),'Profile remains after deletion';
 assert not exists(select 1 from public.projects where user_id=current_setting('test.user')::uuid),'Projects remain after deletion';
end $$;
select 'Disposable account, profile and project removal passed (rolled back)' as result;
rollback;
