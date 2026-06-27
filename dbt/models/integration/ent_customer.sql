-- models/integration/ent_customer.sql
{{ config(materialized='table') }}

WITH sub_a_customers AS (
    SELECT
        MD5('SUB_A' || customer_id)             AS customer_key,
        customer_id                             AS customer_id_nk,
        'SUB_A'                                 AS subsidiary_code,
        CASE segment
            WHEN 'VIP'     THEN 'HIGH_VALUE'
            WHEN 'Regular' THEN 'STANDARD'
            WHEN 'New'     THEN 'NEW'
            WHEN 'At-Risk' THEN 'AT_RISK'
            ELSE 'UNKNOWN'
        END                                     AS customer_type,
        'RETAIL'                                AS industry_segment,
        join_date::DATE                         AS acquire_date,
        full_name,
        email,
        region                                  AS customer_region,
        is_active::BOOLEAN                      AS is_active
    FROM {{ source('bronze', 'raw_sub_a_customers') }}
),

sub_b_customers AS (
    -- SUB_B: no customer attribute table; derive from transactions
    SELECT DISTINCT
        MD5('SUB_B' || customer_id_nk)         AS customer_key,
        customer_id_nk,
        'SUB_B'                                 AS subsidiary_code,
        'B2B'                                   AS customer_type,
        'FREIGHT'                               AS industry_segment,
        MIN(transaction_date) OVER (
            PARTITION BY customer_id_nk
        )                                       AS acquire_date,
        NULL::VARCHAR                           AS full_name,
        NULL::VARCHAR                           AS email,
        NULL::VARCHAR                           AS customer_region,
        TRUE                                    AS is_active
    FROM {{ ref('stg_sub_b_shipments') }}
),

sub_c_customers AS (
    -- SUB_C: borrowers — origination date of first loan as acquire_date
    SELECT DISTINCT
        MD5('SUB_C' || customer_id_nk)         AS customer_key,
        customer_id_nk,
        'SUB_C'                                 AS subsidiary_code,
        'BORROWER'                              AS customer_type,
        'LENDING'                               AS industry_segment,
        MIN(transaction_date) OVER (
            PARTITION BY customer_id_nk
        )                                       AS acquire_date,
        NULL::VARCHAR                           AS full_name,
        NULL::VARCHAR                           AS email,
        NULL::VARCHAR                           AS customer_region,
        TRUE                                    AS is_active
    FROM {{ ref('stg_sub_c_loans') }}
),

sub_d_customers AS (
    -- SUB_D: manufacturing customers
    SELECT DISTINCT
        MD5('SUB_D' || customer_id_nk)         AS customer_key,
        customer_id_nk,
        'SUB_D'                                 AS subsidiary_code,
        'B2B'                                   AS customer_type,
        'MANUFACTURING'                         AS industry_segment,
        MIN(transaction_date) OVER (
            PARTITION BY customer_id_nk
        )                                       AS acquire_date,
        NULL::VARCHAR                           AS full_name,
        NULL::VARCHAR                           AS email,
        NULL::VARCHAR                           AS customer_region,
        TRUE                                    AS is_active
    FROM {{ ref('stg_sub_d_orders') }}
),

sub_e_customers AS (
    -- SUB_E: property tenants
    SELECT DISTINCT
        MD5('SUB_E' || customer_id_nk)         AS customer_key,
        customer_id_nk,
        'SUB_E'                                 AS subsidiary_code,
        'TENANT'                                AS customer_type,
        'REAL_ESTATE'                           AS industry_segment,
        MIN(transaction_date) OVER (
            PARTITION BY customer_id_nk
        )                                       AS acquire_date,
        NULL::VARCHAR                           AS full_name,
        NULL::VARCHAR                           AS email,
        NULL::VARCHAR                           AS customer_region,
        TRUE                                    AS is_active
    FROM {{ ref('stg_sub_e_leases') }}
)

SELECT * FROM sub_a_customers
UNION ALL
SELECT * FROM sub_b_customers
UNION ALL
SELECT * FROM sub_c_customers
UNION ALL
SELECT * FROM sub_d_customers
UNION ALL
SELECT * FROM sub_e_customers