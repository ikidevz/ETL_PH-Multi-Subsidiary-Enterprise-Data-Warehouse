-- models/marts/mart_retail_sales.sql
{{ config(materialized='table') }}

SELECT
    d.year,
    d.month_num,
    d.month_name,
    src.channel,
    src.category,
    src.region,
    -- Sales Volume
    COUNT(*) AS order_count,
    SUM(src.qty) AS units_sold,
    COUNT(DISTINCT src.customer_id_nk) AS unique_customers,
    -- Revenue Metrics
    SUM(src.amount_local) AS net_sales_php,
    SUM(src.unit_price * src.qty) AS gross_sales_php,
    SUM((src.unit_price * src.qty) - src.amount_local) AS discount_amount_php,
    ROUND(
        AVG(src.discount_pct),
        2
    ) AS avg_discount_pct,
    ROUND(
        SUM(src.amount_local)
        / NULLIF(COUNT(DISTINCT src.customer_id_nk), 0),
        2
    ) AS revenue_per_customer,
    ROUND(
        SUM(src.amount_local)
        / NULLIF(COUNT(*), 0),
        2
    ) AS avg_order_value,
    -- Channel Contribution
    ROUND(
        SUM(src.amount_local)
        /
        NULLIF(
            SUM(SUM(src.amount_local)) OVER (
                PARTITION BY
                    d.year,
                    d.month_num
            ),
            0
        ) * 100,
        2
    ) AS channel_revenue_share_pct
FROM {{ ref('stg_sub_a_sales') }} src
JOIN {{ ref('dim_date') }} d
    ON src.transaction_date = d.date_key

GROUP BY
    d.year,
    d.month_num,
    d.month_name,
    src.channel,
    src.category,
    src.region
ORDER BY
    d.year,
    d.month_num,
    src.channel,
    net_sales_php DESC