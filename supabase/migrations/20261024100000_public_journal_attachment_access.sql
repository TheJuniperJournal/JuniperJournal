begin;
-- Private storage also serves public journal evidence, but only after the
-- attachment is referenced by a published entry in a public project.
create or replace function public.public_journal_attachment_visible(p_path text)
returns boolean language sql stable security definer set search_path=public as $$
  select exists (
    select 1 from public.journal_entries e
    join public.projects p on p.id=e.project_id
    where p.id::text=split_part(p_path,'/',1)
      and lower(p.visibility)='public'
      and e.feed_ready and e.feed_published_at is not null
      and position(p_path in e.content::text)>0
  );
$$;
revoke all on function public.public_journal_attachment_visible(text) from public;
grant execute on function public.public_journal_attachment_visible(text) to anon,authenticated;
create policy "Published public journal evidence" on storage.objects
  for select to anon,authenticated
  using(bucket_id='journal-attachments' and public.public_journal_attachment_visible(name));
commit;
