-- 1) Series catalogue (one row per time_series_code)
create table public.time_series (
  code                text primary key,
  prefix              text,          -- first token of the code (industry / category)
  geography           text,          -- last token: US, a state, a region...
  seasonally_adjusted boolean not null default false,
  description         text,          -- fill in from the Census code dictionary
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- 2) Observations (one row per series per month/quarter)
create table public.observations (
  series_code text not null references public.time_series (code) on delete cascade,
  obs_date    date not null,
  value       numeric,               -- null when the Census suppressed the value
  value_flag  text,                  -- original marker when not numeric: S, D, X, Z, ...
  primary key (series_code, obs_date)
);

create index observations_date_idx on public.observations (obs_date);
create index time_series_prefix_idx on public.time_series (prefix);
create index time_series_geo_idx on public.time_series (geography);

-- 3) Row level security: public dataset => read-only for everyone.
--    n8n using the service_role key or the direct Postgres connection bypasses RLS.
alter table public.time_series enable row level security;
alter table public.observations enable row level security;

create policy "read time_series" on public.time_series
  for select to anon, authenticated using (true);
create policy "read observations" on public.observations
  for select to anon, authenticated using (true);

-- 4) Keep updated_at fresh
create or replace function public.set_updated_at() returns trigger
language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

create trigger time_series_updated_at before update on public.time_series
  for each row execute function public.set_updated_at();
