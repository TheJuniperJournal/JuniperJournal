create or replace function public.remove_project_member(p_project_id uuid,p_user_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.can_manage_project(p_project_id) then raise exception 'Only project admins may remove members'; end if;
  if exists(select 1 from projects where id=p_project_id and user_id=p_user_id) then raise exception 'The project creator cannot be removed'; end if;
  delete from project_collaborators where project_id=p_project_id and user_id=p_user_id;
end;
$$;
revoke all on function public.remove_project_member(uuid,uuid) from public;
grant execute on function public.remove_project_member(uuid,uuid) to authenticated;
