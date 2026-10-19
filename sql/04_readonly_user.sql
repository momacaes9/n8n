-- Troque REPLACE_ME pela senha real antes de rodar. Nunca commite a senha real.
create role n8n_reader login password 'REPLACE_ME';
grant usage on schema public to n8n_reader;
grant select on all tables in schema public to n8n_reader;
alter default privileges in schema public grant select on tables to n8n_reader;

do $$
declare t record;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format(
      'create policy %I on public.%I for select to n8n_reader using (true)',
      'n8n_reader_read_' || t.tablename, t.tablename
    );
  end loop;
end $$;
