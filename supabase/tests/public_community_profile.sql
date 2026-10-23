-- Run after the public community profile migration. Read-only assertions.
begin;
do $$
declare c record; summary jsonb; admin jsonb; project jsonb;
begin
 assert has_function_privilege('anon','public.public_community_profile(uuid)','execute');
 assert exists(select 1 from pg_policies where schemaname='public' and tablename='community_members' and policyname='Community roster requires membership' and permissive='RESTRICTIVE');
 for c in select id from public.communities where lower(visibility)='public' loop
  summary:=public.public_community_profile(c.id);
  assert jsonb_typeof(summary->'member_count')='number';
  assert not summary ? 'members','Full roster must not be returned';
  for admin in select value from jsonb_array_elements(summary->'admins') loop
   assert admin->>'role' in ('owner','admin');
   assert not admin ? 'email','Email must not be returned';
  end loop;
  for project in select value from jsonb_array_elements(summary->'projects') loop
   assert lower(project->>'visibility')='public';
   assert not project ? 'timeline','Timeline must not be returned';
  end loop;
 end loop;
 for c in select id from public.communities where lower(visibility)<>'public' loop
  begin
   perform public.public_community_profile(c.id);
   raise exception 'Private profile exposed';
  exception when insufficient_privilege then null;
  end;
 end loop;
end $$;
rollback;
