alter table public.projects
  add column if not exists project_type text not null default 'collaborative'
    check (project_type in ('solo', 'collaborative')),
  add column if not exists community_links jsonb not null default '[]'::jsonb;
