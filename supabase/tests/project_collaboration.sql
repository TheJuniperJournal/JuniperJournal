begin;
do $$
declare p projects%rowtype; person uuid; outsider uuid; post uuid; n int;
begin
 select * into p from projects where user_id is not null limit 1;
 if p.id is null then raise exception 'A project fixture is required'; end if;
 select id into person from profiles where id<>p.user_id limit 1;
 select id into outsider from profiles where id not in (p.user_id,person) limit 1;
 if person is null or outsider is null then raise exception 'Profile fixtures required'; end if;
 perform set_config('request.jwt.claim.sub',p.user_id::text,true);
 delete from project_collaborators where project_id=p.id;
 update projects set project_type='solo' where id=p.id;
 perform add_project_member(p.id,person,'project_member');
 if not exists(select 1 from projects where id=p.id and project_type='collaborative') then raise exception 'Member addition must promote Solo'; end if;
 begin
  update projects set project_type='solo' where id=p.id;
  raise exception 'Solo must reject existing members';
 exception when raise_exception then
  if SQLERRM='Solo must reject existing members' then raise; end if;
 end;
 perform set_config('request.jwt.claim.sub',person::text,true);
 if not is_project_participant(p.id) then raise exception 'Member should participate'; end if;
 begin
  perform remove_project_member(p.id,person);
  raise exception 'Nonadmin must not remove members';
 exception when raise_exception then
  if SQLERRM='Nonadmin must not remove members' then raise; end if;
 end;
 insert into project_bulletin_posts(project_id,user_id,title,body,category) values(p.id,person,'Test','Test body','Design Feedback') returning id into post;
 -- Execute through actual authenticated policies, rather than postgres bypass.
 perform set_config('request.jwt.claim.sub',outsider::text,true);
 execute 'set local role authenticated';
 select count(*) into n from project_bulletin_posts where id=post;
 if n<>0 then raise exception 'Outsider can read member bulletin'; end if;
 begin
  insert into project_bulletin_posts(project_id,user_id,title,body,category) values(p.id,outsider,'Forbidden','Forbidden','Project Update');
  raise exception 'Outsider must not post';
 exception when insufficient_privilege then null;
 end;
 execute 'reset role';
 perform set_config('request.jwt.claim.sub',person::text,true);
 execute 'set local role authenticated';
 update project_bulletin_posts set body='Edited' where id=post;
 insert into project_bulletin_comments(post_id,user_id,body) values(post,person,'Comment');
 insert into project_bulletin_reactions(post_id,user_id) values(post,person);
 select count(*) into n from project_bulletin_posts where id=post and body='Edited';
 if n<>1 then raise exception 'Member author cannot edit post'; end if;
 execute 'reset role';
 perform set_config('request.jwt.claim.sub',p.user_id::text,true);
 perform set_project_member_role(p.id,person,'project_admin');
 perform set_config('request.jwt.claim.sub',person::text,true);
 begin
  perform remove_project_member(p.id,p.user_id);
  raise exception 'Creator must not be removed';
 exception when raise_exception then
  if SQLERRM='Creator must not be removed' then raise; end if;
 end;
 perform set_config('request.jwt.claim.sub',p.user_id::text,true);
 perform remove_project_member(p.id,person);
 update projects set project_type='solo' where id=p.id;
end;
$$;
rollback;
select 'Collaboration membership, Solo restriction, bulletin RLS, comments and reactions passed' as result;
