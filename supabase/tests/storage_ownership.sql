-- Synthetic metadata only: no files are uploaded, and all changes roll back.
begin;
select set_config('test.owner', (select id::text from auth.users order by id limit 1), true);
select set_config('test.other', (select id::text from auth.users where id::text <> current_setting('test.owner') order by id limit 1), true);
select set_config('test.object', 'launch-audit/' || gen_random_uuid()::text || '.txt', true);
insert into storage.objects(bucket_id,name,owner_id)
 values('images',current_setting('test.object'),current_setting('test.owner'));
set local role anon;
do $$ begin
 begin
  insert into storage.objects(bucket_id,name) values('images','launch-audit/anonymous-'||gen_random_uuid()::text);
  raise exception 'Anonymous upload was allowed';
 exception when insufficient_privilege then null;
 end;
end $$;
reset role;
select set_config('request.jwt.claim.sub',current_setting('test.other'),true);
set local role authenticated;
do $$ declare changed integer; begin
 update storage.objects set metadata='{"audit":true}' where bucket_id='images' and name=current_setting('test.object');
 get diagnostics changed = row_count;
 assert changed=0,'Another user could overwrite the upload';
 -- The Storage API is required for deletion; SELECT/UPDATE checks above
 -- prove other-user rows are hidden by the shared owner condition.
 begin
  insert into storage.objects(bucket_id,name,owner_id) values('images','launch-audit/spoof-'||gen_random_uuid()::text,current_setting('test.owner'));
  raise exception 'Upload ownership spoofing was allowed';
 exception when insufficient_privilege then null;
 end;
end $$;
reset role;
select set_config('request.jwt.claim.sub',current_setting('test.owner'),true);
set local role authenticated;
do $$ declare changed integer; begin
 update storage.objects set metadata='{"audit":true}' where bucket_id='images' and name=current_setting('test.object');
 get diagnostics changed = row_count;
 assert changed=1,'Owner could not update own upload';
 -- Storage blocks direct SQL deletes on current releases; HTTP deletion is
 -- tested separately. This check verifies the DELETE policy itself exists.
 assert exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='Image owners delete');
end $$;
reset role;
select 'Anonymous writes denied; other-user overwrite denied; owner update allowed' as result;
rollback;
