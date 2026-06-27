import os
import snowflake.connector
from dotenv import load_dotenv

load_dotenv(".env")

SNOWFLAKE_DATABASE = "enterprise_dw"

conn = snowflake.connector.connect(
    account=os.getenv("SNOWFLAKE_ACCOUNT"),
    user=os.getenv("SNOWFLAKE_USER"),
    password=os.getenv("SNOWFLAKE_PASSWORD"),
    warehouse=os.getenv("SNOWFLAKE_WAREHOUSE"),
    role=os.getenv("SNOWFLAKE_ROLE"),
    database=SNOWFLAKE_DATABASE,
)
cur = conn.cursor()

# ── Fetch active configs ───────────────────────────────────────────────────
cur.execute(f"""
    SELECT config_id, subsidiary_code, target_table,
           load_strategy, incremental_column, last_loaded_at
    FROM   {SNOWFLAKE_DATABASE}.control.ingestion_config
    WHERE  active = TRUE
""")
cols = [c[0].lower() for c in cur.description]
configs = [dict(zip(cols, row)) for row in cur.fetchall()]

# ── Verify row counts and update watermark ─────────────────────────────────
for cfg in configs:
    sub = cfg["subsidiary_code"]
    tbl = f"{SNOWFLAKE_DATABASE}.bronze.{cfg['target_table']}"
    strategy = cfg["load_strategy"]
    inc_col = cfg["incremental_column"]   # None for FULL load tables
    last_ts = cfg["last_loaded_at"]       # None on first run

    if strategy == "INCREMENTAL" and inc_col and last_ts:
        cur.execute(
            f"SELECT COUNT(*) FROM {tbl} WHERE _subsidiary_code = '{sub}' AND {inc_col} > '{last_ts}'")
    else:
        cur.execute(
            f"SELECT COUNT(*) FROM {tbl} WHERE _subsidiary_code = '{sub}'")

    row_count = cur.fetchone()[0]

    cur.execute(f"""
        UPDATE {SNOWFLAKE_DATABASE}.control.ingestion_config
        SET    last_loaded_at = CURRENT_TIMESTAMP()
        WHERE  config_id = {cfg['config_id']}
    """)
    conn.commit()
    print(f"[{sub}] {cfg['target_table']} — {row_count} rows ({strategy})")

cur.close()
conn.close()
print("[OK] Metadata ingestion complete.")
