-- models/staging/stg_sub_b_shipments.sql
{{ config(materialized='view') }}

SELECT
    -- Integration keys
    shipment_id                                     AS transaction_nk,
    'SUB_B'                                         AS subsidiary_code,
    client_id                                       AS customer_id_nk,

    -- Dates
    ship_date::DATE                                 AS transaction_date,

    -- Financial
    total_revenue                                   AS amount_local,
    'PHP'                                           AS currency_code,
    'FREIGHT_REVENUE'                               AS gl_account_code,

    -- SUB_B logistics-specific columns (passed through for mart_freight_ops)
    origin_city,
    dest_city,
    service_type,
    weight_kg,
    volume_cbm,
    freight_revenue,
    fuel_surcharge,
    delay_days,
    expected_del::DATE                              AS expected_del,
    actual_del::DATE                                AS actual_del,

    -- Audit
    modified_ts::TIMESTAMP                          AS _loaded_at

FROM {{ source('bronze', 'raw_sub_b_shipments') }}