begin;
-- Match canonical URLs as well as raw storage paths (spaces and UTF-8 names).
create or replace function public.journal_attachment_url_path(p_path text)
returns text language plpgsql immutable strict set search_path=public as $$
declare bytes bytea := convert_to(p_path,'UTF8'); result text := ''; n integer;
begin
  for i in 0..length(bytes)-1 loop
    n := get_byte(bytes,i);
    if n between 48 and 57 or n between 65 and 90 or n between 97 and 122 or n in (45,46,47,95,126) then
      result := result || chr(n);
    else
      result := result || '%' || upper(lpad(to_hex(n),2,'0'));
    end if;
  end loop;
  return result;
end;
$$;
create or replace function public.public_journal_attachment_visible(p_path text)
returns boolean language sql stable security definer set search_path=public as $$
  select exists (
    select 1 from public.journal_entries e
    join public.projects p on p.id=e.project_id
    where p.id::text=split_part(p_path,'/',1)
      and lower(p.visibility)='public'
      and e.feed_ready and e.feed_published_at is not null
      and (position(p_path in e.content::text)>0
        or position(public.journal_attachment_url_path(p_path) in e.content::text)>0)
  );
$$;
commit;
