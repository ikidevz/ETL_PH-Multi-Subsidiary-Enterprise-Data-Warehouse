-- models/marts/mart_fx_exposure.sql

{{ config(materialized='table') }}

WITH base AS (
    SELECT
        t.subsidiary_code,
        t.currency_code,
        d.year,
        d.month_num,
        d.month_name,
        t.amount_local,
        t.amount_php,
        fx.usd_php_rate AS fx_rate_used

    FROM {{ ref('ent_transaction') }} t

    JOIN {{ ref('dim_date') }} d
        ON t.transaction_date = d.date_key

    LEFT JOIN {{ ref('fx_rates') }} fx
        ON t.transaction_date = fx.rate_date
       AND t.currency_code = fx.from_currency
)

SELECT
    year,
    month_num,
    month_name,
    subsidiary_code,
    currency_code,
    CASE
        WHEN currency_code = 'PHP' THEN FALSE
        ELSE TRUE
    END AS is_fx_exposed,
    COUNT(*) AS transaction_count,
    SUM(amount_local) AS total_local_amount,
    SUM(amount_php) AS total_php_equivalent,
    ROUND(
        SUM(amount_php) * 0.05,
        2
    ) AS fx_sensitivity_5pct_php,
    ROUND(
        AVG(fx_rate_used),
        6
    ) AS avg_fx_rate,
    ROUND(
        SUM(amount_php)
        /
        NULLIF(
            SUM(SUM(amount_php)) OVER (
                PARTITION BY year, month_num
            ),
            0
        ) * 100,
        2
    ) AS currency_revenue_share_pct
FROM base
GROUP BY
    year,
    month_num,
    month_name,
    subsidiary_code,
    currency_code,
    is_fx_exposed
ORDER BY
    year,
    month_num,
    subsidiary_code,
    currency_code