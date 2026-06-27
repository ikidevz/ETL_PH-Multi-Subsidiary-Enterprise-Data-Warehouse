-- models/marts/mart_cohort_retention.sql

{{
    config(
        materialized='table'
    )
}}

WITH customer_cohorts AS (
    SELECT
        customer_id_nk,
        subsidiary_code,
        DATE_TRUNC(
            'MONTH',
            acquire_date
        ) AS cohort_month
    FROM {{ ref('ent_customer') }}
    WHERE acquire_date IS NOT NULL
),

cohort_sizes AS (
    SELECT
        subsidiary_code,
        cohort_month,
        COUNT(DISTINCT customer_id_nk) AS cohort_size
    FROM customer_cohorts
    GROUP BY
        subsidiary_code,
        cohort_month
),

monthly_activity AS (
    SELECT DISTINCT
        cc.customer_id_nk,
        cc.subsidiary_code,
        cc.cohort_month,
        DATE_TRUNC(
            'MONTH',
            t.transaction_date
        ) AS activity_month,

        DATEDIFF(
            'MONTH',
            cc.cohort_month,
            DATE_TRUNC('MONTH', t.transaction_date)
        ) AS months_since_acquisition

    FROM customer_cohorts cc

    INNER JOIN {{ ref('ent_transaction') }} t
        ON cc.customer_id_nk = t.customer_id_nk
       AND cc.subsidiary_code = t.subsidiary_code

    WHERE t.transaction_date >= cc.cohort_month
),

retention_summary AS (
    SELECT
        ma.subsidiary_code,
        ma.cohort_month,
        cs.cohort_size,
        ma.months_since_acquisition,
        COUNT(DISTINCT ma.customer_id_nk) AS retained_customers

    FROM monthly_activity ma

    INNER JOIN cohort_sizes cs
        ON ma.subsidiary_code = cs.subsidiary_code
       AND ma.cohort_month = cs.cohort_month

    GROUP BY
        ma.subsidiary_code,
        ma.cohort_month,
        cs.cohort_size,
        ma.months_since_acquisition
)

SELECT
    subsidiary_code,
    cohort_month,
    cohort_size,
    months_since_acquisition,
    retained_customers,
    ROUND(
        retained_customers * 100.0
        / NULLIF(cohort_size, 0),
        2
    ) AS retention_rate_pct
FROM retention_summary
ORDER BY
    subsidiary_code,
    cohort_month,
    months_since_acquisition