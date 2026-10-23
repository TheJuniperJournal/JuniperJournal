begin;
-- INSERT ... RETURNING must recognize a new owner before the row is visible
-- to the stable participant lookup. Keep outsiders restricted to projections.
alter policy "Full project rows require membership" on public.projects
  using (user_id = auth.uid() or public.is_project_participant(id));

-- Browser roles must never write to the public image bucket anonymously or
-- overwrite somebody else's upload. Existing unowned files remain admin-only.
drop policy if exists "Allow all uploads to images bucket 1ffg0oo_0" on storage.objects;
drop policy if exists "Allow all uploads to images bucket 1ffg0oo_2" on storage.objects;
create policy "Image owners read metadata" on storage.objects for select to authenticated
  using (bucket_id = 'images' and owner_id = auth.uid()::text);
create policy "Image owners upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'images' and owner_id = auth.uid()::text);
create policy "Image owners update" on storage.objects for update to authenticated
  using (bucket_id = 'images' and owner_id = auth.uid()::text)
  with check (bucket_id = 'images' and owner_id = auth.uid()::text);
create policy "Image owners delete" on storage.objects for delete to authenticated
  using (bucket_id = 'images' and owner_id = auth.uid()::text);

-- These endpoints explicitly require a signed-in journal editor. Revoke the
-- explicit anonymous grant as well as PUBLIC (both can grant execution).
revoke execute on function public.journal_collaboration_heartbeat(uuid,uuid,text) from public, anon;
revoke execute on function public.save_collaborative_journal(uuid,uuid,jsonb,jsonb,boolean) from public, anon;
grant execute on function public.journal_collaboration_heartbeat(uuid,uuid,text) to authenticated;
grant execute on function public.save_collaborative_journal(uuid,uuid,jsonb,jsonb,boolean) to authenticated;
commit;
