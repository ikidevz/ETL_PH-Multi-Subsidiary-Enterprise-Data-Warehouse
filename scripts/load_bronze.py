import os
from pathlib import Path

import snowflake.connector
from dotenv import load_dotenv

load_dotenv()

PROJECT_ROOT = Path("/opt/airflow")
DATA_DIR = PROJECT_ROOT / "data"

SNOWFLAKE_DATABASE = "enterprise_dw"

# ---------------------------------------------------------------------
# (csv_path, schema, stage, subsidiary, csv_column_count)
# csv_column_count = number of columns inside the CSV only
# ---------------------------------------------------------------------
FILES = {
    "raw_sub_a_sales": (
        "sub_a/sales_transactions.csv",
        "sub_a_pos",
        "stg_sub_a",
        "SUB_A",
        13,
    ),
    "raw_sub_a_customers": (
        "sub_a/customers.csv",
        "sub_a_pos",
        "stg_sub_a",
        "SUB_A",
        8,
    ),
    "raw_sub_b_shipments": (
        "sub_b/shipments.csv",
        "sub_b_tms",
        "stg_sub_b",
        "SUB_B",
        16,
    ),
    "raw_sub_c_loans": (
        "sub_c/loan_accounts.csv",
        "sub_c_core",
        "stg_sub_c",
        "SUB_C",
        15,
    ),
    "raw_sub_d_orders": (
        "sub_d/sales_orders.csv",
        "sub_d_sap",
        "stg_sub_d",
        "SUB_D",
        17,
    ),
    "raw_sub_e_leases": (
        "sub_e/lease_contracts.csv",
        "sub_e_pms",
        "stg_sub_e",
        "SUB_E",
        15,
    ),
}

conn = snowflake.connector.connect(
    account=os.getenv("SNOWFLAKE_ACCOUNT"),
    user=os.getenv("SNOWFLAKE_USER"),
    password=os.getenv("SNOWFLAKE_PASSWORD"),
    warehouse=os.getenv("SNOWFLAKE_WAREHOUSE"),
    role=os.getenv("SNOWFLAKE_ROLE"),
    database=SNOWFLAKE_DATABASE,
)

cur = conn.cursor()
cur.execute(f"USE DATABASE {SNOWFLAKE_DATABASE}")

stages_used = set()

for table, (
    rel_path,
    schema,
    stage_name,
    subsidiary_code,
    csv_cols,
) in FILES.items():

    csv_path = DATA_DIR / rel_path

    fq_table = f"{SNOWFLAKE_DATABASE}.bronze.{table}"
    fq_stage = f"@{SNOWFLAKE_DATABASE}.{schema}.{stage_name}"

    staged_filename = csv_path.name

    cur.execute(
        f"""
        PUT file://{csv_path.resolve()}
        {fq_stage}
        OVERWRITE=TRUE
        AUTO_COMPRESS=TRUE
        """
    )

    print(f"[PUT] {csv_path.name} -> {fq_stage}")
    cur.execute(f"TRUNCATE TABLE {fq_table}")

    select_columns = ",\n                ".join(
        f"${i}" for i in range(1, csv_cols + 1)
    )

    copy_sql = f"""
    COPY INTO {fq_table}
    FROM (
        SELECT
            {select_columns},
            '{subsidiary_code}' AS _subsidiary_code,
            CURRENT_TIMESTAMP() AS _loaded_at
        FROM {fq_stage}
    )
    FILE_FORMAT = (
        TYPE = CSV
        SKIP_HEADER = 1
        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
        EMPTY_FIELD_AS_NULL = TRUE
        NULL_IF = ('NULL','null','')
        DATE_FORMAT = 'YYYY-MM-DD'
        TIMESTAMP_FORMAT = 'YYYY-MM-DDTHH24:MI:SS'
    )
    PATTERN='.*{staged_filename}\\.gz'
    """

    cur.execute(copy_sql)

    result = cur.fetchone()

    if result:
        print(f"[OK] Loaded {result[0]} rows -> {fq_table}")
    else:
        print(f"[OK] Loaded -> {fq_table}")

    stages_used.add((schema, stage_name))


for schema, stage in stages_used:
    cur.execute(f"REMOVE @{SNOWFLAKE_DATABASE}.{schema}.{stage}")
    print(f"[REMOVE] @{SNOWFLAKE_DATABASE}.{schema}.{stage}")

conn.commit()

cur.close()
conn.close()

print("\n===================================")
print(" Bronze Load Completed Successfully")
print("===================================")
