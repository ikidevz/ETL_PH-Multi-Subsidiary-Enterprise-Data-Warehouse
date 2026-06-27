-- models/integration/ent_transaction.sql
{{
    config(
        materialized='incremental',
        unique_key='transaction_key',
        on_schema_change='sync_all_columns'
    )
}}


WITH sub_a AS (
    SELECT
        MD5('SUB_A' || transaction_nk)          AS transaction_key,
        -- For SUB_A, account is at customer level (retail account)
        MD5('SUB_A' || customer_id_nk)          AS account_key,
        -- Product key: derived from product_sku in staging
        MD5('SUB_A' || product_sku)             AS product_key,
        transaction_nk,
        subsidiary_code,
        customer_id_nk,
        transaction_date,
        amount_local,
        currency_code,
        gl_account_code,
        _loaded_at
    FROM {{ ref('stg_sub_a_sales') }}
    {% if is_incremental() %}
    WHERE _loaded_at > (
        SELECT COALESCE(MAX(_loaded_at), '1900-01-01'::TIMESTAMP)
        FROM {{ this }}
        WHERE subsidiary_code = 'SUB_A'
    )
    {% endif %}
),

sub_b AS (
    SELECT
        MD5('SUB_B' || transaction_nk)          AS transaction_key,
        MD5('SUB_B' || customer_id_nk)          AS account_key,
        MD5('SUB_B' || service_type)            AS product_key,
        transaction_nk,
        subsidiary_code,
        customer_id_nk,
        transaction_date,
        amount_local,
        currency_code,
        gl_account_code,
        _loaded_at
    FROM {{ ref('stg_sub_b_shipments') }}
    {% if is_incremental() %}
    WHERE _loaded_at > (
        SELECT COALESCE(MAX(_loaded_at), '1900-01-01'::TIMESTAMP)
        FROM {{ this }}
        WHERE subsidiary_code = 'SUB_B'
    )
    {% endif %}
),

sub_c AS (
    SELECT
        MD5('SUB_C' || transaction_nk)          AS transaction_key,
        -- Each loan is its own account in SUB_C
        MD5('SUB_C' || transaction_nk)          AS account_key,
        MD5('SUB_C' || loan_type)               AS product_key,
        transaction_nk,
        subsidiary_code,
        customer_id_nk,
        transaction_date,
        amount_local,
        currency_code,
        gl_account_code,
        _loaded_at
    FROM {{ ref('stg_sub_c_loans') }}
    {% if is_incremental() %}
    WHERE _loaded_at > (
        SELECT COALESCE(MAX(_loaded_at), '1900-01-01'::TIMESTAMP)
        FROM {{ this }}
        WHERE subsidiary_code = 'SUB_C'
    )
    {% endif %}
),

sub_d AS (
    SELECT
        MD5('SUB_D' || transaction_nk)          AS transaction_key,
        MD5('SUB_D' || customer_id_nk)          AS account_key,
        MD5('SUB_D' || material_id)             AS product_key,
        transaction_nk,
        subsidiary_code,
        customer_id_nk,
        transaction_date,
        amount_local,
        currency_code,
        gl_account_code,
        _loaded_at
    FROM {{ ref('stg_sub_d_orders') }}
    {% if is_incremental() %}
    WHERE _loaded_at > (
        SELECT COALESCE(MAX(_loaded_at), '1900-01-01'::TIMESTAMP)
        FROM {{ this }}
        WHERE subsidiary_code = 'SUB_D'
    )
    {% endif %}
),

sub_e AS (
    SELECT
        MD5('SUB_E' || transaction_nk)          AS transaction_key,
        -- Each lease contract is its own account
        MD5('SUB_E' || transaction_nk)          AS account_key,
        MD5('SUB_E' || lease_type || '|' || unit_type) AS product_key,
        transaction_nk,
        subsidiary_code,
        customer_id_nk,
        transaction_date,
        amount_local,
        currency_code,
        gl_account_code,
        _loaded_at
    FROM {{ ref('stg_sub_e_leases') }}
    {% if is_incremental() %}
    WHERE _loaded_at > (
        SELECT COALESCE(MAX(_loaded_at), '1900-01-01'::TIMESTAMP)
        FROM {{ this }}
        WHERE subsidiary_code = 'SUB_E'
    )
    {% endif %}
),

all_transactions AS (
    SELECT * FROM sub_a
    UNION ALL
    SELECT * FROM sub_b
    UNION ALL
    SELECT * FROM sub_c
    UNION ALL
    SELECT * FROM sub_d
    UNION ALL
    SELECT * FROM sub_e
)

SELECT
    t.transaction_key,
    t.account_key,
    t.product_key,
    t.transaction_nk,
    t.subsidiary_code,
    t.customer_id_nk,
    t.transaction_date,
    t.amount_local,
    t.currency_code,
    t.gl_account_code,
    t._loaded_at,

    CASE
        WHEN t.currency_code = 'PHP'
            THEN t.amount_local
        ELSE
            ROUND(t.amount_local / NULLIF(fx.rate, 0), 2)
    END                                             AS amount_php

FROM all_transactions t
LEFT JOIN {{ ref('fx_rates') }} fx
    ON  t.transaction_date = fx.rate_date
    AND t.currency_code    = fx.from_currency