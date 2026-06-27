-- models/staging/stg_sub_d_orders.sql
{{ config(materialized='view') }}

SELECT
    -- Integration keys
    order_num                                       AS transaction_nk,
    'SUB_D'                                         AS subsidiary_code,
    customer_id                                     AS customer_id_nk,

    -- Dates
    order_date::DATE                                AS transaction_date,

    -- Financial
    order_value_php                                 AS amount_local,
    'PHP'                                           AS currency_code,
    'MANUFACTURING_REVENUE'                         AS gl_account_code,

    -- SUB_D manufacturing-specific columns (passed through for mart_order_fulfillment)
    order_item,
    doc_type,
    sales_org,
    material_id,
    plant,
    order_qty,
    delivered_qty::INTEGER                          AS delivered_qty,
    net_price,
    status,
    requested_del::DATE                             AS requested_del,
    confirmed_del::DATE                             AS confirmed_del,

    -- Audit
    change_date::TIMESTAMP                          AS _loaded_at

FROM {{ source('bronze', 'raw_sub_d_orders') }}