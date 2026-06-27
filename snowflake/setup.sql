CREATE WAREHOUSE IF NOT EXISTS portfolio_wh
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND   = 60
  AUTO_RESUME    = TRUE
  COMMENT        = 'Shared warehouse for all portfolio projects';

CREATE DATABASE IF NOT EXISTS enterprise_dw;
USE DATABASE enterprise_dw;

CREATE SCHEMA IF NOT EXISTS enterprise_dw.sub_a_pos;
CREATE SCHEMA IF NOT EXISTS enterprise_dw.sub_b_tms;
CREATE SCHEMA IF NOT EXISTS enterprise_dw.sub_c_core;
CREATE SCHEMA IF NOT EXISTS enterprise_dw.sub_d_sap;
CREATE SCHEMA IF NOT EXISTS enterprise_dw.sub_e_pms;

CREATE SCHEMA IF NOT EXISTS enterprise_dw.bronze;
CREATE SCHEMA IF NOT EXISTS enterprise_dw.integration;
CREATE SCHEMA IF NOT EXISTS enterprise_dw.marts;
CREATE SCHEMA IF NOT EXISTS enterprise_dw.control;

CREATE OR REPLACE TABLE enterprise_dw.control.ingestion_config (
    config_id           INTEGER AUTOINCREMENT PRIMARY KEY,
    subsidiary_code     VARCHAR NOT NULL,
    source_schema       VARCHAR NOT NULL,
    source_table        VARCHAR NOT NULL,
    target_schema       VARCHAR NOT NULL,
    target_table        VARCHAR NOT NULL,
    load_strategy       VARCHAR NOT NULL,
    incremental_column  VARCHAR,
    primary_key_column  VARCHAR NOT NULL,
    active              BOOLEAN DEFAULT TRUE,
    last_loaded_at      TIMESTAMP
);

CREATE OR REPLACE TABLE enterprise_dw.bronze.raw_sub_a_sales (
    order_id VARCHAR,
    order_date VARCHAR,
    customer_id VARCHAR,
    product_sku VARCHAR,
    channel VARCHAR,
    category VARCHAR,
    region VARCHAR,
    qty NUMBER,
    unit_price NUMBER,
    discount_pct NUMBER,
    net_sales NUMBER,
    currency VARCHAR,
    updated_at VARCHAR,
    _subsidiary_code VARCHAR,
    _loaded_at TIMESTAMP
);

CREATE OR REPLACE TABLE enterprise_dw.bronze.raw_sub_a_customers (
    customer_id VARCHAR,
    full_name VARCHAR,
    email VARCHAR,
    phone VARCHAR,
    region VARCHAR,
    segment VARCHAR,
    join_date VARCHAR,
    is_active BOOLEAN,
    _subsidiary_code VARCHAR,
    _loaded_at TIMESTAMP
);

CREATE OR REPLACE TABLE enterprise_dw.bronze.raw_sub_b_shipments (
    shipment_id VARCHAR,
    client_id VARCHAR,
    origin_city VARCHAR,
    dest_city VARCHAR,
    service_type VARCHAR,
    ship_date VARCHAR,
    expected_del VARCHAR,
    actual_del VARCHAR,
    delay_days NUMBER,
    weight_kg NUMBER,
    volume_cbm NUMBER,
    freight_revenue NUMBER,
    fuel_surcharge NUMBER,
    total_revenue NUMBER,
    currency VARCHAR,
    modified_ts VARCHAR,
    _subsidiary_code VARCHAR,
    _loaded_at TIMESTAMP
);

CREATE OR REPLACE TABLE enterprise_dw.bronze.raw_sub_c_loans (
    loan_id VARCHAR,
    borrower_id VARCHAR,
    loan_type VARCHAR,
    origination_date VARCHAR,
    maturity_date VARCHAR,
    term_months NUMBER,
    principal_amount NUMBER,
    interest_rate NUMBER,
    outstanding_balance NUMBER,
    monthly_payment NUMBER,
    loan_status VARCHAR,
    days_past_due NUMBER,
    branch_id VARCHAR,
    currency VARCHAR,
    last_updated VARCHAR,
    _subsidiary_code VARCHAR,
    _loaded_at TIMESTAMP
);

CREATE OR REPLACE TABLE enterprise_dw.bronze.raw_sub_d_orders (
    order_num VARCHAR,
    order_item VARCHAR,
    doc_type VARCHAR,
    sales_org VARCHAR,
    customer_id VARCHAR,
    material_id VARCHAR,
    plant VARCHAR,
    order_date VARCHAR,
    requested_del VARCHAR,
    confirmed_del VARCHAR,
    order_qty NUMBER,
    delivered_qty NUMBER,
    net_price NUMBER,
    order_value_php NUMBER,
    currency VARCHAR,
    status VARCHAR,
    change_date VARCHAR,
    _subsidiary_code VARCHAR,
    _loaded_at TIMESTAMP
);

CREATE OR REPLACE TABLE enterprise_dw.bronze.raw_sub_e_leases (
    contract_id VARCHAR,
    property_id VARCHAR,
    tenant_id VARCHAR,
    unit_type VARCHAR,
    lease_type VARCHAR,
    area_sqm NUMBER,
    start_date VARCHAR,
    end_date VARCHAR,
    term_years NUMBER,
    monthly_rent_php NUMBER,
    annual_rent_php NUMBER,
    security_deposit NUMBER,
    rent_escalation_pct NUMBER,
    status VARCHAR,
    payment_terms VARCHAR,
    city VARCHAR,
    _subsidiary_code VARCHAR,
    _loaded_at TIMESTAMP
);
