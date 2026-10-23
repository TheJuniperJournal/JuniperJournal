begin;
-- Authors follow the same one-like-per-user rule as other viewers.
drop trigger if exists prevent_own_project_like_trigger on public.project_likes;
create or replace function public.like_project(p_project_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare
  v_user_id uuid := auth.uid();
  v_inserted int;
begin
  if v_user_id is null then raise exception 'Not authenticated'; end if;
  if not public.can_view_project_audience(p_project_id) then
    raise exception 'Project unavailable';
  end if;
  insert into public.project_likes(project_id,user_id)
  values(p_project_id,v_user_id) on conflict do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted > 0 then
    update public.projects set likes=coalesce(likes,0)+1 where id=p_project_id;
  end if;
end;
$$;
commit;
