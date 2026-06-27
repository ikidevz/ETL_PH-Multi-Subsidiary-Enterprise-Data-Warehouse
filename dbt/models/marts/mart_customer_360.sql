-- models/marts/mart_customer_360.sql
{{ config(materialized='table') }}

SELECT
    c.customer_id_nk,
    c.customer_type,
    COUNT(DISTINCT c.subsidiary_code) AS subsidiary_count,
    ARRAY_AGG(DISTINCT c.subsidiary_code) AS subsidiaries,
    SUM(t.amount_php) AS total_group_revenue_php,
    MIN(t.transaction_date) AS first_transaction,
    MAX(t.transaction_date) AS last_transaction,
    COUNT(*) AS total_transactions
FROM {{ ref('ent_customer') }} c
JOIN {{ ref('ent_transaction') }} t USING (customer_id_nk, subsidiary_code)
GROUP BY 1, 2
 
