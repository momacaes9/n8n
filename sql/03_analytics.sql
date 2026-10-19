-- Read-only helpers the n8n AI agent can call.

-- Latest value + change vs previous period and vs 12 months earlier
create or replace view public.series_latest as
with ranked as (
  select o.*, row_number() over (partition by series_code order by obs_date desc) rn
  from public.observations o where o.value is not null
)
select r.series_code,
       r.obs_date  as latest_date,
       r.value     as latest_value,
       p.value     as previous_value,
       y.value     as year_ago_value,
       round((r.value - y.value) / nullif(abs(y.value), 0) * 100, 2) as yoy_pct
from ranked r
left join public.observations p on p.series_code = r.series_code
     and p.obs_date = (select max(obs_date) from public.observations
                       where series_code = r.series_code and obs_date < r.obs_date)
left join public.observations y on y.series_code = r.series_code
     and y.obs_date = r.obs_date - interval '1 year'
where r.rn = 1;

-- Find series by code fragment or description
create or replace function public.search_series(term text, lim int default 20)
returns table (code text, description text, geography text, seasonally_adjusted boolean)
language sql stable as $$
  select code, description, geography, seasonally_adjusted
  from public.time_series
  where code ilike '%' || term || '%' or description ilike '%' || term || '%'
  order by code limit lim
$$;

-- Time series between two dates
create or replace function public.get_series(p_code text, p_from date default '1900-01-01', p_to date default current_date)
returns table (obs_date date, value numeric, value_flag text)
language sql stable as $$
  select obs_date, value, value_flag from public.observations
  where series_code = p_code and obs_date between p_from and p_to
  order by obs_date
$$;

-- Year-over-year % change for any series
create or replace function public.yoy_change(p_code text, p_from date default '2000-01-01')
returns table (obs_date date, value numeric, yoy_pct numeric)
language sql stable as $$
  select o.obs_date, o.value,
         round((o.value - l.value) / nullif(abs(l.value), 0) * 100, 2)
  from public.observations o
  left join public.observations l on l.series_code = o.series_code
       and l.obs_date = o.obs_date - interval '1 year'
  where o.series_code = p_code and o.obs_date >= p_from
  order by o.obs_date
$$;

-- Same measure across geographies (e.g. all states for one prefix on one date)
create or replace function public.compare_geographies(p_prefix text, p_date date)
returns table (series_code text, geography text, value numeric)
language sql stable as $$
  select o.series_code, t.geography, o.value
  from public.observations o join public.time_series t on t.code = o.series_code
  where t.prefix = p_prefix and o.obs_date = p_date and o.value is not null
  order by o.value desc
$$;
