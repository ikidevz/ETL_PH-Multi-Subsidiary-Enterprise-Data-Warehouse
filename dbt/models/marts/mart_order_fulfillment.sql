-- models/marts/mart_order_fulfillment.sql

{{ config(materialized='table') }}

SELECT
    d.year,
    d.month_num,
    d.month_name,
    src.plant,
    src.sales_org,
    src.doc_type,
    -- Order Volume
    COUNT(*) AS order_count,
    SUM(src.order_qty) AS total_order_qty,
    SUM(src.delivered_qty) AS total_delivered_qty,
    -- Revenue
    SUM(src.amount_local) AS order_value_php,
    ROUND(
        SUM(src.amount_local)
        / NULLIF(COUNT(*), 0),
        2
    ) AS avg_order_value_php,
    -- Fulfillment
    ROUND(
        SUM(src.delivered_qty)
        / NULLIF(SUM(src.order_qty), 0) * 100,
        2
    ) AS fill_rate_pct,
    -- Status Counts
    COUNT(CASE WHEN src.status = 'DELIVERED' THEN 1 END) AS delivered_count,
    COUNT(CASE WHEN src.status = 'BILLED' THEN 1 END) AS billed_count,
    COUNT(CASE WHEN src.status = 'OPEN' THEN 1 END) AS open_count,
    COUNT(CASE WHEN src.status = 'CANCELLED' THEN 1 END) AS cancelled_count,
    -- Cancellation Rate
    ROUND(
        COUNT(CASE WHEN src.status = 'CANCELLED' THEN 1 END)
        / NULLIF(COUNT(*), 0) * 100,
        2
    ) AS cancellation_rate_pct,
    -- Lead Time
    ROUND(
        AVG(
            DATEDIFF(
                'day',
                src.transaction_date,
                src.confirmed_del
            )
        ),
        1
    ) AS avg_lead_time_days

FROM {{ ref('stg_sub_d_orders') }} src
JOIN {{ ref('dim_date') }} d
    ON src.transaction_date = d.date_key
GROUP BY
    d.year,
    d.month_num,
    d.month_name,
    src.plant,
    src.sales_org,
    src.doc_type
ORDER BY
    d.year,
    d.month_num,
    src.plant,
    src.sales_org,
    src.doc_type