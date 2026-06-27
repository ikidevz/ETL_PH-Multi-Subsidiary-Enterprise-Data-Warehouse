-- models/marts/mart_product_performance.sql

{{ config(materialized='table') }}

SELECT
    d.year,
    d.month_num,
    d.month_name,
    t.subsidiary_code,
    p.product_category,
    p.cost_center,
    -- Transaction Metrics
    COUNT(DISTINCT t.transaction_key) AS transaction_count,
    COUNT(DISTINCT t.customer_id_nk) AS unique_customers,
    -- Revenue Metrics
    SUM(t.amount_php) AS revenue_php,
    ROUND(
        SUM(t.amount_php)
        / NULLIF(COUNT(DISTINCT t.transaction_key), 0),
        2
    ) AS avg_revenue_per_txn,
    -- Category Revenue Ranking
    RANK() OVER (
        PARTITION BY
            t.subsidiary_code,
            d.year,
            d.month_num
        ORDER BY
            SUM(t.amount_php) DESC
    ) AS category_revenue_rank,
    -- Revenue Share within Subsidiary
    ROUND(
        SUM(t.amount_php)
        /
        NULLIF(
            SUM(SUM(t.amount_php)) OVER (
                PARTITION BY
                    t.subsidiary_code,
                    d.year,
                    d.month_num
            ),
            0
        ) * 100,
        2
    ) AS subsidiary_category_share_pct,
    -- Revenue Share across Entire Group
    ROUND(
        SUM(t.amount_php)
        /
        NULLIF(
            SUM(SUM(t.amount_php)) OVER (
                PARTITION BY
                    d.year,
                    d.month_num
            ),
            0
        ) * 100,
        2
    ) AS group_category_share_pct

FROM {{ ref('ent_transaction') }} t
JOIN {{ ref('ent_product') }} p
    ON t.product_key = p.product_key
   AND t.subsidiary_code = p.subsidiary_code
JOIN {{ ref('dim_date') }} d
    ON t.transaction_date = d.date_key
WHERE t.gl_account_code LIKE '%REVENUE%'
GROUP BY
    d.year,
    d.month_num,
    d.month_name,
    t.subsidiary_code,
    p.product_category,
    p.cost_center
ORDER BY
    d.year,
    d.month_num,
    t.subsidiary_code,
    revenue_php DESC