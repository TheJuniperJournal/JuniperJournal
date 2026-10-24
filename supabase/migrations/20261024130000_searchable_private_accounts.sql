begin;
-- Discoverability exposes identity only; it does not widen profiles table RLS.
create or replace function public.search_user_directory(p_query text default '')
returns table(id uuid,display_name text,username text,avatar_url text,is_public_profile boolean)
language sql stable security definer set search_path=public as $$
 select p.id,p.display_name::text,p.username::text,p.avatar_url::text,p.is_public_profile
 from public.profiles p
 where auth.uid() is not null and p.id<>auth.uid()
 and (strpos(lower(coalesce(p.display_name,'')),lower(trim(coalesce(p_query,''))))>0
   or strpos(lower(coalesce(p.username,'')),lower(trim(coalesce(p_query,''))))>0)
 order by lower(coalesce(p.display_name,p.username,'')),p.id limit 30;
$$;
create or replace function public.user_profile_cards(p_ids uuid[])
returns table(id uuid,display_name text,username text,avatar_url text,is_public_profile boolean,bio text)
language sql stable security definer set search_path=public as $$
 select p.id,p.display_name::text,p.username::text,p.avatar_url::text,p.is_public_profile,
 case when p.id=auth.uid() or p.is_public_profile or exists (
   select 1 from public.friend_requests f where f.status='accepted' and
   ((f.requester_id=auth.uid() and f.addressee_id=p.id) or
    (f.addressee_id=auth.uid() and f.requester_id=p.id))
 ) then coalesce(p.bio,'') else '' end::text
 from public.profiles p where (auth.uid() is not null or p.is_public_profile) and p.id=any(p_ids) limit 100;
$$;
revoke all on function public.search_user_directory(text) from public,anon;
revoke all on function public.user_profile_cards(uuid[]) from public;
grant execute on function public.search_user_directory(text) to authenticated;
grant execute on function public.user_profile_cards(uuid[]) to anon,authenticated;
commit;
