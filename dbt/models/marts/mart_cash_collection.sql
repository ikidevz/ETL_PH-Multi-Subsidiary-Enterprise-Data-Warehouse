-- models/marts/mart_cash_collection.sql

{{
    config(
        materialized = 'table'
    )
}}

WITH billed AS (
    SELECT
        'SUB_A' AS subsidiary_code,
        DATE_TRUNC(
            'MONTH',
            src.transaction_date
        ) AS billed_month,
        SUM(src.amount_local) AS billed_php,
        0 AS avg_collection_lag_days,
        SUM(src.amount_local) AS collected_on_time_php,
        0 AS collected_1_7d_php,
        0 AS collected_7d_plus_php
    FROM {{ ref('stg_sub_a_sales') }} src
    GROUP BY
        DATE_TRUNC('MONTH', src.transaction_date)
    UNION ALL
    SELECT
        'SUB_B' AS subsidiary_code,
        DATE_TRUNC('MONTH', src.transaction_date) AS billed_month,
        SUM(src.amount_local) AS billed_php,
        AVG(src.delay_days) AS avg_collection_lag_days,
        SUM(
            CASE
                WHEN src.delay_days = 0
                THEN src.amount_local
                ELSE 0
            END
        ) AS collected_on_time_php,
        SUM(
            CASE
                WHEN src.delay_days BETWEEN 1 AND 7
                THEN src.amount_local
                ELSE 0
            END
        ) AS collected_1_7d_php,
        SUM(
            CASE
                WHEN src.delay_days > 7
                THEN src.amount_local
                ELSE 0
            END
        ) AS collected_7d_plus_php

    FROM {{ ref('stg_sub_b_shipments') }} src
    GROUP BY
        DATE_TRUNC('MONTH', src.transaction_date)
    UNION ALL
    SELECT
        'SUB_C' AS subsidiary_code,
        DATE_TRUNC('MONTH', src.transaction_date) AS billed_month,
        SUM(src.monthly_payment) AS billed_php,
        AVG(src.days_past_due) AS avg_collection_lag_days,
        SUM(
            CASE
                WHEN src.days_past_due = 0
                THEN src.monthly_payment
                ELSE 0
            END
        ) AS collected_on_time_php,
        SUM(
            CASE
                WHEN src.days_past_due BETWEEN 1 AND 30
                THEN src.monthly_payment
                ELSE 0
            END
        ) AS collected_1_7d_php,
        SUM(
            CASE
                WHEN src.days_past_due > 30
                THEN src.monthly_payment
                ELSE 0
            END
        ) AS collected_7d_plus_php
    FROM {{ ref('stg_sub_c_loans') }} src
    WHERE src.loan_status <> 'CLOSED'
    GROUP BY
        DATE_TRUNC('MONTH', src.transaction_date)
)

SELECT

    d.year,
    d.month_num,
    d.month_name,

    b.subsidiary_code,

    b.billed_php,

    b.collected_on_time_php,

    b.collected_1_7d_php,

    b.collected_7d_plus_php,

    ROUND(
        b.avg_collection_lag_days,
        1
    ) AS avg_dso_days,

    ROUND(
        b.collected_on_time_php
        / NULLIF(b.billed_php, 0)
        * 100,
        2
    ) AS on_time_collection_rate_pct,

    ROUND(
        b.billed_php
        - b.collected_on_time_php
        - b.collected_1_7d_php,
        2
    ) AS est_outstanding_php

FROM billed b

INNER JOIN {{ ref('dim_date') }} d
    ON b.billed_month = d.date_key

ORDER BY
    d.year,
    d.month_num,
    b.subsidiary_code
