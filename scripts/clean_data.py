"""
Clean the Kaggle CSV (time_series_code, date, value) into two load-ready files:
  data/time_series.csv    one row per series (metadata derived from the code)
  data/observations.csv   one row per (series, date), de-duplicated, numeric value + flag

Usage:  python scripts/clean_data.py path/to/data.csv
"""
import sys
import pandas as pd

src = sys.argv[1] if len(sys.argv) > 1 else "data.csv"
df = pd.read_csv(src, dtype=str)
df.columns = [c.strip() for c in df.columns]
df["time_series_code"] = df["time_series_code"].str.strip()
df["value"] = df["value"].str.strip()

# Census suppression / footnote markers come through in the value column.
df["obs_date"] = pd.to_datetime(df["date"]).dt.date
num = pd.to_numeric(df["value"], errors="coerce")
df["value_flag"] = df["value"].where(num.isna())      # keep the original marker (S, D, X, Z...)
df["value"] = num

# 39k (code,date) pairs appear twice; keep the last occurrence.
before = len(df)
df = df.drop_duplicates(["time_series_code", "obs_date"], keep="last")
print(f"rows: {before:,} -> {len(df):,} after de-duplication")

obs = df.rename(columns={"time_series_code": "series_code"})[
    ["series_code", "obs_date", "value", "value_flag"]
]
obs.to_csv("data/observations.csv", index=False)

# Series metadata derived from the code, e.g. QTAXCAT3_T27_AK, 44000_E_MPCSM_US, 34H_UO_US_adj
codes = pd.Series(sorted(obs["series_code"].unique()), name="code").to_frame()
codes["seasonally_adjusted"] = codes["code"].str.endswith("_adj")
base = codes["code"].str.replace(r"_adj$", "", regex=True)
codes["prefix"] = base.str.split("_").str[0]
codes["geography"] = base.str.split("_").str[-1]
codes.to_csv("data/time_series.csv", index=False)
print(f"series: {len(codes):,}")
