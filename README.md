# Census economic time series → Supabase → n8n AI chatbot

Your Kaggle file has 3 columns (`time_series_code`, `date`, `value`), 10,952 series, 1956–2017.
It is not user/bet data, so the schema is two tables: `time_series` (catalogue) and `observations` (values).

## 1. Clean the CSV
```bash
pip install pandas
python scripts/clean_data.py data.csv      # writes data/time_series.csv + data/observations.csv
```
What it fixes: 39,682 duplicate (code, date) rows removed; 5,435 non-numeric values
(S, D, X, Z, "Less than .05 percent"...) kept in `value_flag` with `value` = NULL.

## 2. Supabase
1. Create a project, open **SQL Editor**, run `sql/01_schema.sql` then `sql/03_analytics.sql`.
2. Load the data with psql (the dashboard CSV importer is too limited for 1.3M rows):
   `psql "<direct connection string>" -f sql/02_load.sql` (run from the repo root).
3. Fill `time_series.description` from the Census code dictionary on the Kaggle page,
   otherwise the chatbot only sees codes like `44000_E_MPCSM_US`.
   Geography/adjusted/prefix are derived from the code and are a best guess.

## 3. n8n AI agent
- Add a **Postgres** credential (Supabase direct/pooler connection string) or use the Supabase node with the service_role key. Keep keys in n8n credentials, never in GitHub.
- Workflow: **Chat Trigger → AI Agent (+ chat model, + memory) → tools**.
- Give the agent Postgres tool nodes that call the helpers in `03_analytics.sql`:
  - `select * from search_series($1)` to find the right code
  - `select * from get_series($1, $2, $3)` for values over time
  - `select * from yoy_change($1)` for growth
  - `select * from compare_geographies($1, $2)` for state comparisons
  - `select * from series_latest where series_code = $1`
- System prompt idea: "Always call search_series first to find the code, never guess values, say when a value is suppressed (value_flag)."

## 4. GitHub
```bash
git init && git add . && git commit -m "Census time series to Supabase"
git branch -M main
git remote add origin https://github.com/<you>/<repo>.git
git push -u origin main
```
`data/` is in `.gitignore` (regenerate it with the script). Never commit `.env` or database passwords.
