-- Run after 20261023020000_journal_collaboration.sql. No production rows change.
begin;
do $$
declare value jsonb;
begin
 value:=public.merge_journal_document(
  '{"content":[{"stage":"overview","summary":"Old"},{"stage":"learning","notes":"Old"}]}',
  '{"content":[{"stage":"overview","summary":"Local"},{"stage":"learning","notes":"Old"}]}',
  '{"content":[{"stage":"overview","summary":"Old"},{"stage":"learning","notes":"Remote"}]}'
 );
 assert value#>>'{content,0,summary}'='Local','Lost local stage';
 assert value#>>'{content,1,notes}'='Remote','Lost remote stage';
 assert public.merge_journal_document('"Hello world"','"Hello world!"','"Hi Hello world"')='"Hi Hello world!"','Disjoint edits did not merge';
 assert public.merge_journal_document('"abc"','"aXbc"','"aYbc"')='"aYXbc"','Concurrent insert was lost';
 assert public.merge_journal_document('[{"id":"a","text":"Old"}]','[]','[{"id":"a","text":"Old"}]')='[]','Delete did not persist';
 begin
  perform public.merge_journal_document('"abc"','"axc"','"ayc"');
  raise exception 'Overlapping edits were accepted';
 exception when serialization_failure then null;
 end;
 begin
  perform public.merge_journal_document('[{"id":"a","text":"Old"}]','[]','[{"id":"a","text":"Remote"}]');
  raise exception 'Delete overwrote remote editing';
 exception when serialization_failure then null;
 end;
 assert not has_table_privilege('anon','public.journal_edit_sessions','select'),'Anonymous presence exposed';
 assert not has_table_privilege('authenticated','public.journal_edit_sessions','insert'),'Client can forge a lease';
 assert not has_function_privilege('anon','public.journal_collaboration_heartbeat(uuid,uuid,text)','execute'),'Anonymous heartbeat exposed';
 assert not has_function_privilege('anon','public.save_collaborative_journal(uuid,uuid,jsonb,jsonb,boolean)','execute'),'Anonymous save exposed';
end $$;
rollback;
