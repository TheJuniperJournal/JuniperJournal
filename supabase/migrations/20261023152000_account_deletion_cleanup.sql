begin;
create or replace function public.delete_user() returns void
language plpgsql security definer set search_path=public as $$
declare account_id uuid := auth.uid();
begin
 if account_id is null then raise exception 'Authentication required' using errcode='42501'; end if;
 -- Metadata must never be deleted directly: the client first removes actual
 -- file bytes through the Storage API. Refuse to leave owned uploads behind.
 if exists(select 1 from storage.objects where owner_id=account_id::text) then
  raise exception 'Remove uploaded files before deleting this account';
 end if;
 -- These older foreign keys do not cascade from auth.users. Clean up only
 -- content owned/authored by this user, in the same database transaction.
 delete from public.project_community_invitations where invited_by=account_id or decided_by=account_id;
 delete from public.assessment_responses where user_id=account_id;
 delete from public.journal_assessments where author_id=account_id;
 delete from public.journal_contributions where user_id=account_id;
 delete from public.eco_point_transactions where user_id=account_id;
 delete from public.project_bulletin_reactions where user_id=account_id;
 delete from public.project_bulletin_comments where user_id=account_id;
 delete from public.project_bulletin_posts where user_id=account_id;
 delete from public.challenge_participants where user_id=account_id;
 delete from public.design_challenges where creator_id=account_id;
 delete from public.learning_module where author_id=account_id;
 delete from public.projects where user_id=account_id;
 delete from auth.users where id=account_id;
end;
$$;
revoke execute on function public.delete_user() from public, anon;
grant execute on function public.delete_user() to authenticated;
commit;
