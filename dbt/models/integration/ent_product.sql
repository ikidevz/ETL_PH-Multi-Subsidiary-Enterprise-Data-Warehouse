-- models/integration/ent_product.sql
{{
    config(
        materialized='incremental',
        unique_key='product_key',
        on_schema_change='sync_all_columns'
    )
}}

WITH sub_a AS (
    SELECT
        MD5('SUB_A' || product_sku)             AS product_key,
        product_sku                             AS product_id_nk,
        'SUB_A'                                 AS subsidiary_code,
        category                                AS product_category,
        'RETAIL'                                AS product_class,
        'CC-RETAIL-' || category                AS cost_center,
        MAX(_loaded_at)                         AS _loaded_at
    FROM {{ ref('stg_sub_a_sales') }}
    GROUP BY product_sku, category
),

sub_b AS (
    SELECT
        MD5('SUB_B' || service_type)            AS product_key,
        service_type                            AS product_id_nk,
        'SUB_B'                                 AS subsidiary_code,
        service_type                            AS product_category,
        'FREIGHT_SERVICE'                       AS product_class,
        'CC-LOGISTICS-OPS'                      AS cost_center,
        MAX(_loaded_at)                         AS _loaded_at
    FROM {{ ref('stg_sub_b_shipments') }}
    GROUP BY service_type
),

sub_c AS (
    SELECT
        MD5('SUB_C' || loan_type)               AS product_key,
        loan_type                               AS product_id_nk,
        'SUB_C'                                 AS subsidiary_code,
        loan_type                               AS product_category,
        'LOAN_PRODUCT'                          AS product_class,
        'CC-BANKING-' || loan_type              AS cost_center,
        MAX(_loaded_at)                         AS _loaded_at
    FROM {{ ref('stg_sub_c_loans') }}
    GROUP BY loan_type
),

sub_d AS (
    SELECT
        MD5('SUB_D' || material_id)             AS product_key,
        material_id                             AS product_id_nk,
        'SUB_D'                                 AS subsidiary_code,
        'MANUFACTURED_GOOD'                     AS product_category,
        'MATERIAL'                              AS product_class,
        'CC-PLANT-' || plant                    AS cost_center,
        MAX(_loaded_at)                         AS _loaded_at
    FROM {{ ref('stg_sub_d_orders') }}
    GROUP BY material_id, plant
),

sub_e AS (
    SELECT
        MD5('SUB_E' || lease_type || '|' || unit_type) AS product_key,
        (lease_type || '|' || unit_type)        AS product_id_nk,
        'SUB_E'                                 AS subsidiary_code,
        lease_type                              AS product_category,
        'LEASE_UNIT'                            AS product_class,
        'CC-PROPERTY-' || lease_type            AS cost_center,
        MAX(_loaded_at)                         AS _loaded_at
    FROM {{ ref('stg_sub_e_leases') }}
    GROUP BY lease_type, unit_type
)

SELECT * FROM sub_a
UNION ALL SELECT * FROM sub_b
UNION ALL SELECT * FROM sub_c
UNION ALL SELECT * FROM sub_d
UNION ALL SELECT * FROM sub_e