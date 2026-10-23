alter table public.projects
  add column if not exists learning_objectives jsonb not null default '[]'::jsonb;
