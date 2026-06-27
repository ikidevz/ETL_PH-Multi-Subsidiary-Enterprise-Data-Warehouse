-- models/marts/mart_cost_center_spend.sql
{{
    config(
        materialized='incremental',
        unique_key=['year', 'month_num', 'subsidiary_code', 'cost_center'],
        on_schema_change='append_new_columns'
    )
}}

WITH source_transactions AS (
    SELECT *
    FROM {{ ref('ent_transaction') }}

    WHERE gl_account_code NOT LIKE '%REVENUE%'
      AND gl_account_code NOT LIKE '%INCOME%'

    {% if is_incremental() %}
      AND _loaded_at >
      (
          SELECT COALESCE(
              MAX(load_timestamp),
              '1900-01-01'::TIMESTAMP
          )
          FROM {{ this }}
      )
    {% endif %}
),

aggregated_spend AS (
    SELECT
        d.year,
        d.month_num,
        d.month_name,
        t.subsidiary_code,
        p.cost_center,
        p.product_category,
        COUNT(*)                        AS posting_count,
        SUM(t.amount_php)               AS total_spend_php,
        ROUND(AVG(t.amount_php), 2)     AS avg_posting_php
    FROM source_transactions t

    JOIN {{ ref('ent_product') }} p
      ON t.product_key = p.product_key
     AND t.subsidiary_code = p.subsidiary_code

    JOIN {{ ref('dim_date') }} d
      ON t.transaction_date = d.date_key

    GROUP BY
        d.year,
        d.month_num,
        d.month_name,
        t.subsidiary_code,
        p.cost_center,
        p.product_category
),

final AS (
    SELECT
        *,
        ROUND(
            (
                total_spend_php
                -
                LAG(total_spend_php) OVER (
                    PARTITION BY subsidiary_code, cost_center
                    ORDER BY year, month_num
                )
            )
            /
            NULLIF(
                LAG(total_spend_php) OVER (
                    PARTITION BY subsidiary_code, cost_center
                    ORDER BY year, month_num
                ),
                0
            ) * 100,
            2
        ) AS mom_spend_change_pct,

        ROUND(
            total_spend_php
            /
            NULLIF(
                SUM(total_spend_php) OVER (
                    PARTITION BY subsidiary_code, year, month_num
                ),
                0
            ) * 100,
            2
        ) AS subsidiary_spend_share_pct,

        ROUND(
            total_spend_php
            /
            NULLIF(
                SUM(total_spend_php) OVER (
                    PARTITION BY year, month_num
                ),
                0
            ) * 100,
            2
        ) AS group_spend_share_pct,

        CURRENT_TIMESTAMP() AS load_timestamp
    FROM aggregated_spend
)

SELECT *
FROM final