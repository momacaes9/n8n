-- Run with psql against your Supabase DIRECT connection string (Project Settings > Database):
--   psql "postgresql://postgres:[PASSWORD]@db.[REF].supabase.co:5432/postgres" -f sql/02_load.sql
-- The Supabase dashboard CSV importer is too slow/limited for ~1.3M rows, so use \copy.

\copy public.time_series (code, seasonally_adjusted, prefix, geography) from 'data/time_series.csv' with (format csv, header true)
\copy public.observations (series_code, obs_date, value, value_flag) from 'data/observations.csv' with (format csv, header true)

analyze public.time_series;
analyze public.observations;
