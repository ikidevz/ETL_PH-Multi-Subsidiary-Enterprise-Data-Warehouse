-- models/staging/stg_sub_a_sales.sql
{{ config(materialized='view') }}

SELECT
    order_id                                        AS transaction_nk,
    'SUB_A'                                         AS subsidiary_code,
    customer_id                                     AS customer_id_nk,

    -- Dates
    order_date::DATE                                AS transaction_date,

    -- Financial
    net_sales                                       AS amount_local,
    'PHP'                                           AS currency_code,
    'RETAIL_REVENUE'                                AS gl_account_code,

    product_sku,
    channel,
    category,
    region,
    qty,
    unit_price,
    discount_pct,

    -- Audit
    updated_at::TIMESTAMP                           AS _loaded_at

FROM {{ source('bronze', 'raw_sub_a_sales') }}