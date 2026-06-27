-- models/marts/mart_subsidiary_kpi.sql
{{
  config(materialized='table')
}}

SELECT
    s.subsidiary_code,
    s.subsidiary_name,
    s.industry_type,
    d.year,
    d.month_num,
    d.month_name,

    -- Volume
    COUNT(*)                                            AS transaction_count,
    COUNT(DISTINCT t.customer_id_nk)                   AS active_customers,

    -- Revenue
    SUM(t.amount_php)                                  AS revenue_php,
    AVG(t.amount_php)                                  AS avg_transaction_php,

    -- Month-over-month revenue growth (lag over subsidiary partition)
    ROUND(
        (SUM(t.amount_php)
         - LAG(SUM(t.amount_php)) OVER (
               PARTITION BY s.subsidiary_code
               ORDER BY d.year, d.month_num))
        / NULLIF(LAG(SUM(t.amount_php)) OVER (
               PARTITION BY s.subsidiary_code
               ORDER BY d.year, d.month_num), 0) * 100,
        2
    )                                                  AS mom_revenue_growth_pct,

    -- Revenue share within group for the period
    ROUND(
        SUM(t.amount_php)
        / NULLIF(SUM(SUM(t.amount_php)) OVER (
               PARTITION BY d.year, d.month_num), 0) * 100,
        2
    )                                                  AS group_revenue_share_pct

FROM {{ ref('ent_transaction') }}   t
JOIN {{ ref('ent_subsidiary') }}    s USING (subsidiary_code)
JOIN {{ ref('dim_date') }}          d ON t.transaction_date = d.date_key
WHERE t.gl_account_code LIKE '%REVENUE%'
GROUP BY 1, 2, 3, 4, 5, 6