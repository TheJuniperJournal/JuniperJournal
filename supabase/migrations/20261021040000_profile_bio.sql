-- Optional profile bio; existing profile visibility and owner-write policies apply.
alter table public.profiles add column if not exists bio text not null default '';
