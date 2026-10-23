begin;
insert into storage.buckets(id,name,public) values('journal-attachments','journal-attachments',false) on conflict(id) do nothing;
create or replace function public.can_read_journal_attachment(p_path text) returns boolean language sql stable security definer set search_path=public as $$
 select case when split_part(p_path,'/',1) ~ '^[0-9a-fA-F-]{36}$' then
 public.is_project_participant(split_part(p_path,'/',1)::uuid) or exists(select 1 from journal_entries e where e.project_id=split_part(p_path,'/',1)::uuid and e.content::text like '%'||p_path||'%' and journal_feed_entry_allowed(e.id,array[(select user_id from projects where id=e.project_id)],null))
 else false end;
$$;
revoke all on function public.can_read_journal_attachment(text) from public;
grant execute on function public.can_read_journal_attachment(text) to authenticated;
create policy "Authorized viewers read journal attachments" on storage.objects for select to authenticated using(bucket_id='journal-attachments' and public.can_read_journal_attachment(name));
create policy "Project participants upload journal attachments" on storage.objects for insert to authenticated with check(bucket_id='journal-attachments' and split_part(name,'/',1) ~ '^[0-9a-fA-F-]{36}$' and public.is_project_participant(split_part(name,'/',1)::uuid));
commit;
