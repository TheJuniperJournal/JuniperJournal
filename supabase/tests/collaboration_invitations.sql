-- Run as postgres; all fixtures and identity changes are rolled back.
begin;
do $$
declare owner_id uuid; guest_id uuid; pid uuid:=gen_random_uuid(); iid uuid; cid uuid; admin_id uuid; link jsonb; state text;
begin
 select id into owner_id from auth.users limit 1;
 select id into guest_id from auth.users where id<>owner_id limit 1;
 if guest_id is null then raise exception 'Two users required for invitation checks'; end if;
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 insert into projects(id,user_id,project_name,problem_statement,project_type,visibility) values(pid,owner_id,'Rollback invitation test','Test','collaborative','private');
 perform add_project_member(pid,guest_id,'project_member');
 perform add_project_member(pid,guest_id,'project_admin');
 if (select count(*) from project_collaborators where project_id=pid and user_id=guest_id)<>1 then raise exception 'Duplicate invitation'; end if;
 select id,status into iid,state from project_collaborators where project_id=pid and user_id=guest_id;
 if state<>'pending' then raise exception 'Member accepted prematurely'; end if;
 perform set_config('request.jwt.claim.sub',guest_id::text,true);
 if is_project_participant(pid) then raise exception 'Pending invite grants access'; end if;
 perform respond_project_invitation(iid,true);
 if not is_project_participant(pid) then raise exception 'Accepted member has no access'; end if;
 begin perform respond_project_invitation(iid,false); raise exception 'Duplicate decision allowed'; exception when raise_exception then if SQLERRM='Duplicate decision allowed' then raise;end if;end;
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 perform remove_project_member(pid,guest_id);
 if (select status from project_collaborators where id=iid)<>'cancelled' then raise exception 'Cancellation not recorded';end if;
 select id,created_by into cid,admin_id from communities where created_by is not null limit 1;
 if cid is not null then
   link:=jsonb_build_object('id',cid,'name','Community','role','home');
   update projects set community_links=jsonb_build_array(link) where id=pid;
   if (select jsonb_array_length(community_links) from projects where id=pid)<>0 then raise exception 'Community accepted prematurely';end if;
   select id into iid from project_community_invitations where project_id=pid and community_id=cid and status='pending';
   if iid is null then raise exception 'Community invitation missing';end if;
   perform set_config('request.jwt.claim.sub',guest_id::text,true);
   if not can_review_community_projects(cid) then
     begin perform review_community_project_invitation(iid,true);raise exception 'Unauthorized approval allowed'; exception when raise_exception then if SQLERRM='Unauthorized approval allowed' then raise;end if;end;
   end if;
   perform set_config('request.jwt.claim.sub',admin_id::text,true);
   perform review_community_project_invitation(iid,true);
   if (select jsonb_array_length(community_links) from projects where id=pid)<>1 then raise exception 'Accepted community link missing';end if;
   begin perform review_community_project_invitation(iid,false);raise exception 'Community double decision allowed';exception when raise_exception then if SQLERRM='Community double decision allowed' then raise;end if;end;
 end if;
end $$;
select 'Invitation lifecycle, duplicate prevention, pending access and community administrator decisions passed' as result;
rollback;
