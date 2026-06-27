import os
import snowflake.connector


SNOWFLAKE_WAREHOUSE = "portfolio_wh"
SNOWFLAKE_DATABASE = "enterprise_dw"
SNOWFLAKE_SCHEMAS = [
    "sub_a_pos", "sub_b_tms", "sub_c_core", "sub_d_sap", "sub_e_pms",
    "bronze", "integration", "marts", "control",
]

conn = snowflake.connector.connect(
    account=os.getenv("SNOWFLAKE_ACCOUNT"),
    user=os.getenv("SNOWFLAKE_USER"),
    password=os.getenv("SNOWFLAKE_PASSWORD"),
    warehouse=os.getenv("SNOWFLAKE_WAREHOUSE"),
    role=os.getenv("SNOWFLAKE_ROLE"),
)
cur = conn.cursor()

# ── Warehouse ──────────────────────────────────────────────────────────────
cur.execute(f"""
    CREATE WAREHOUSE IF NOT EXISTS {SNOWFLAKE_WAREHOUSE}
        WAREHOUSE_SIZE = 'X-SMALL'
        AUTO_SUSPEND   = 60
        AUTO_RESUME    = TRUE
        COMMENT        = 'Shared warehouse for all portfolio projects'
""")
print(f"[OK] Warehouse {SNOWFLAKE_WAREHOUSE} ensured.")

# ── Database ───────────────────────────────────────────────────────────────
cur.execute(f"CREATE DATABASE IF NOT EXISTS {SNOWFLAKE_DATABASE}")
cur.execute(f"USE DATABASE {SNOWFLAKE_DATABASE}")
print(f"[OK] Database {SNOWFLAKE_DATABASE} ensured.")

# ── Schemas ────────────────────────────────────────────────────────────────
for schema in SNOWFLAKE_SCHEMAS:
    cur.execute(f"CREATE SCHEMA IF NOT EXISTS {SNOWFLAKE_DATABASE}.{schema}")
    print(f"[OK] Schema {SNOWFLAKE_DATABASE}.{schema} ensured.")

# ── Ingestion stages (one named stage per subsidiary schema) ───────────────
# Named stages avoid the %table_stage pitfall — table stages only exist in
# the same schema as the table, but bronze tables live in bronze, not sub_*_*.
STAGES = [
    ("sub_a_pos",  "stg_sub_a"),
    ("sub_b_tms",  "stg_sub_b"),
    ("sub_c_core", "stg_sub_c"),
    ("sub_d_sap",  "stg_sub_d"),
    ("sub_e_pms",  "stg_sub_e"),
]

for schema, stage in STAGES:
    cur.execute(f"""
        CREATE STAGE IF NOT EXISTS {SNOWFLAKE_DATABASE}.{schema}.{stage}
            COMMENT = 'Landing stage for {schema} CSV ingestion'
    """)
    print(f"[OK] Stage {SNOWFLAKE_DATABASE}.{schema}.{stage} ensured.")

# ── Bronze tables ──────────────────────────────────────────────────────────
COLUMN_MAP = {
    "raw_sub_a_sales": """
        order_id VARCHAR, order_date TIMESTAMP_NTZ, customer_id VARCHAR, product_sku VARCHAR,
        channel VARCHAR, category VARCHAR, region VARCHAR, qty INTEGER,
        unit_price NUMBER(12,2), discount_pct NUMBER(5,2), net_sales NUMBER(15,2),
        currency VARCHAR, updated_at TIMESTAMP_NTZ,
        _subsidiary_code VARCHAR, _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()""",

    "raw_sub_a_customers": """
        customer_id VARCHAR, full_name VARCHAR, email VARCHAR, phone VARCHAR,
        region VARCHAR, segment VARCHAR, join_date TIMESTAMP_NTZ, is_active BOOLEAN,
        _subsidiary_code VARCHAR, _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()""",

    "raw_sub_b_shipments": """
        shipment_id VARCHAR, client_id VARCHAR, origin_city VARCHAR, dest_city VARCHAR,
        service_type VARCHAR, ship_date TIMESTAMP_NTZ, expected_del TIMESTAMP_NTZ,
        actual_del TIMESTAMP_NTZ, delay_days INTEGER, weight_kg NUMBER(10,2),
        volume_cbm NUMBER(10,2), freight_revenue NUMBER(15,2), fuel_surcharge NUMBER(15,2),
        total_revenue NUMBER(15,2), currency VARCHAR, modified_ts TIMESTAMP_NTZ,
        _subsidiary_code VARCHAR, _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()""",

    "raw_sub_c_loans": """
        loan_id VARCHAR, borrower_id VARCHAR, loan_type VARCHAR, origination_date TIMESTAMP_NTZ,
        maturity_date TIMESTAMP_NTZ, term_months INTEGER, principal_amount NUMBER(15,2),
        interest_rate NUMBER(5,2), outstanding_balance NUMBER(15,2),
        monthly_payment NUMBER(15,2), loan_status VARCHAR, days_past_due INTEGER,
        branch_id VARCHAR, currency VARCHAR, last_updated TIMESTAMP_NTZ,
        _subsidiary_code VARCHAR, _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()""",

    "raw_sub_d_orders": """
        order_num VARCHAR, order_item VARCHAR, doc_type VARCHAR, sales_org VARCHAR,
        customer_id VARCHAR, material_id VARCHAR, plant VARCHAR, order_date TIMESTAMP_NTZ,
        requested_del TIMESTAMP_NTZ, confirmed_del TIMESTAMP_NTZ, order_qty INTEGER,
        delivered_qty VARCHAR, net_price NUMBER(12,2), order_value_php NUMBER(15,2),
        currency VARCHAR, status VARCHAR, change_date TIMESTAMP_NTZ,
        _subsidiary_code VARCHAR, _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()""",

    "raw_sub_e_leases": """
        contract_id VARCHAR, property_id VARCHAR, tenant_id VARCHAR, unit_type VARCHAR,
        lease_type VARCHAR, area_sqm NUMBER(10,2), start_date TIMESTAMP_NTZ, end_date TIMESTAMP_NTZ,
        term_years INTEGER, monthly_rent_php NUMBER(15,2), annual_rent_php NUMBER(15,2),
        security_deposit NUMBER(15,2), rent_escalation_pct NUMBER(5,2),
        status VARCHAR, city VARCHAR,
        _subsidiary_code VARCHAR, _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()""",
}

for table, columns in COLUMN_MAP.items():
    cur.execute(f"""
        CREATE TABLE IF NOT EXISTS {SNOWFLAKE_DATABASE}.bronze.{table} ({columns})
    """)
    print(f"[OK] Table {SNOWFLAKE_DATABASE}.bronze.{table} ensured.")

# ── Control table ──────────────────────────────────────────────────────────
cur.execute(f"""
    CREATE TABLE IF NOT EXISTS {SNOWFLAKE_DATABASE}.control.ingestion_config (
        config_id         INTEGER AUTOINCREMENT PRIMARY KEY,
        subsidiary_code   VARCHAR,
        source_schema     VARCHAR,
        source_table      VARCHAR,
        target_schema     VARCHAR,
        target_table      VARCHAR,
        load_strategy     VARCHAR,
        incremental_column VARCHAR,
        primary_key_column VARCHAR,
        active            BOOLEAN DEFAULT TRUE,
        last_loaded_at    TIMESTAMP_NTZ
    )
""")
print(f"[OK] Table {SNOWFLAKE_DATABASE}.control.ingestion_config ensured.")

# ── Seed ingestion_config (MERGE = idempotent) ─────────────────────────────
cur.execute(f"""
    MERGE INTO {SNOWFLAKE_DATABASE}.control.ingestion_config AS tgt
    USING (
        SELECT * FROM VALUES
            ('SUB_A', 'sub_a_pos', 'sales_transactions', 'bronze', 'raw_sub_a_sales',     'INCREMENTAL', 'updated_at',   'order_id',    TRUE),
            ('SUB_A', 'sub_a_pos', 'customers',          'bronze', 'raw_sub_a_customers', 'FULL',        NULL,           'customer_id', TRUE),
            ('SUB_B', 'sub_b_tms', 'shipments',          'bronze', 'raw_sub_b_shipments', 'INCREMENTAL', 'modified_ts',  'shipment_id', TRUE),
            ('SUB_C', 'sub_c_core','loan_accounts',      'bronze', 'raw_sub_c_loans',     'INCREMENTAL', 'last_updated', 'loan_id',     TRUE),
            ('SUB_D', 'sub_d_sap', 'sales_orders',       'bronze', 'raw_sub_d_orders',    'INCREMENTAL', 'change_date',  'order_num',   TRUE),
            ('SUB_E', 'sub_e_pms', 'lease_contracts',    'bronze', 'raw_sub_e_leases',    'FULL',        NULL,           'contract_id', TRUE)
        AS src (subsidiary_code, source_schema, source_table, target_schema, target_table,
                load_strategy, incremental_column, primary_key_column, active)
    ) AS src
    ON  tgt.subsidiary_code = src.subsidiary_code
    AND tgt.source_table    = src.source_table
    WHEN NOT MATCHED THEN INSERT (
        subsidiary_code, source_schema, source_table, target_schema, target_table,
        load_strategy, incremental_column, primary_key_column, active, last_loaded_at
    ) VALUES (
        src.subsidiary_code, src.source_schema, src.source_table, src.target_schema,
        src.target_table, src.load_strategy, src.incremental_column,
        src.primary_key_column, src.active, NULL
    )
""")
print("[OK] ingestion_config seeded (MERGE — no duplicates).")

conn.commit()
cur.close()
conn.close()
print("[OK] Snowflake init complete.")
