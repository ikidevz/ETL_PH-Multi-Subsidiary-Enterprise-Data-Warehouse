-- models/integration/ent_account.sql
{{ config(materialized='table') }}


WITH sub_a_accounts AS (
    SELECT DISTINCT
        MD5('SUB_A' || customer_id_nk)         AS account_key,
        customer_id_nk                          AS account_id_nk,
        MD5('SUB_A' || customer_id_nk)         AS customer_key,
        'SUB_A'                                 AS subsidiary_code,
        'RETAIL_ACCOUNT'                        AS account_type,
        MIN(transaction_date)                   AS open_date
    FROM {{ ref('stg_sub_a_sales') }}
    GROUP BY 1, 2, 3, 4, 5
),

sub_b_accounts AS (
    SELECT DISTINCT
        MD5('SUB_B' || customer_id_nk)         AS account_key,
        customer_id_nk                          AS account_id_nk,
        MD5('SUB_B' || customer_id_nk)         AS customer_key,
        'SUB_B'                                 AS subsidiary_code,
        'FREIGHT_ACCOUNT'                       AS account_type,
        MIN(transaction_date)                   AS open_date
    FROM {{ ref('stg_sub_b_shipments') }}
    GROUP BY 1, 2, 3, 4, 5
),

sub_c_accounts AS (
    -- Each loan is a separate account in lending
    SELECT
        MD5('SUB_C' || transaction_nk)         AS account_key,
        transaction_nk                          AS account_id_nk,
        MD5('SUB_C' || customer_id_nk)         AS customer_key,
        'SUB_C'                                 AS subsidiary_code,
        loan_type                               AS account_type,
        transaction_date                        AS open_date
    FROM {{ ref('stg_sub_c_loans') }}
),

sub_d_accounts AS (
    SELECT DISTINCT
        MD5('SUB_D' || customer_id_nk)         AS account_key,
        customer_id_nk                          AS account_id_nk,
        MD5('SUB_D' || customer_id_nk)         AS customer_key,
        'SUB_D'                                 AS subsidiary_code,
        'MANUFACTURING_ACCOUNT'                 AS account_type,
        MIN(transaction_date)                   AS open_date
    FROM {{ ref('stg_sub_d_orders') }}
    GROUP BY 1, 2, 3, 4, 5
),

sub_e_accounts AS (
    -- Each lease contract is a separate account
    SELECT
        MD5('SUB_E' || transaction_nk)         AS account_key,
        transaction_nk                          AS account_id_nk,
        MD5('SUB_E' || customer_id_nk)         AS customer_key,
        'SUB_E'                                 AS subsidiary_code,
        'LEASE_ACCOUNT'                         AS account_type,
        transaction_date                        AS open_date
    FROM {{ ref('stg_sub_e_leases') }}
)

SELECT * FROM sub_a_accounts
UNION ALL
SELECT * FROM sub_b_accounts
UNION ALL
SELECT * FROM sub_c_accounts
UNION ALL
SELECT * FROM sub_d_accounts
UNION ALL
SELECT * FROM sub_e_accounts