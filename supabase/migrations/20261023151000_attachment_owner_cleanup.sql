begin;
-- Keep owners able to remove their own files, including an abandoned upload
-- whose project was removed. Public readers still receive no access.
create policy "Attachment owners read their metadata" on storage.objects for select to authenticated
  using (bucket_id = 'journal-attachments' and owner_id = auth.uid()::text);
create policy "Attachment owners delete their files" on storage.objects for delete to authenticated
  using (bucket_id = 'journal-attachments' and owner_id = auth.uid()::text);
commit;
