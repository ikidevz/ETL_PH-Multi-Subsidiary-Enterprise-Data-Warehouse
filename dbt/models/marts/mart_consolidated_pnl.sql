-- models/marts/mart_consolidated_pnl.sql
{{ config(materialized='table') }}

SELECT
    EXTRACT(YEAR FROM t.transaction_date)       AS year,
    EXTRACT(QUARTER FROM t.transaction_date)    AS quarter,
    TO_VARCHAR(t.transaction_date, 'Month')     AS month_name,
    s.subsidiary_code,
    s.subsidiary_name,
    s.industry_type,
    t.gl_account_code,
    SUM(t.amount_php)                           AS revenue_php,
    COUNT(DISTINCT t.customer_id_nk)            AS unique_customers,
    COUNT(*)                                    AS transaction_count,
    ROUND(
        SUM(t.amount_php) / NULLIF(COUNT(DISTINCT t.customer_id_nk), 0), 
        2
    )                                           AS revenue_per_customer
FROM {{ ref('ent_transaction') }} t
JOIN {{ ref('ent_subsidiary') }} s 
  USING (subsidiary_code)

WHERE t.gl_account_code IN (
        'RETAIL_REVENUE', 
        'FREIGHT_REVENUE', 
        'MANUFACTURING_REVENUE',
        'INTEREST_INCOME',      -- SUB_C
        'RENTAL_INCOME'         -- SUB_E
    )
   OR t.gl_account_code LIKE '%REVENUE%'

GROUP BY 1, 2, 3, 4, 5, 6, 7