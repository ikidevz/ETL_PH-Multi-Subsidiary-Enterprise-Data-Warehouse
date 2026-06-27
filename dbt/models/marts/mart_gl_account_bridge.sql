-- models/marts/mart_gl_account_bridge.sql

{{ config(materialized='table') }}

SELECT
    d.year,
    d.month_num,
    d.month_name,

    t.subsidiary_code,

    -- Group-standard GL mapping
    gl.group_gl_code,
    gl.group_gl_name,
    gl.gl_category,
    gl.gl_sub_category,

    -- Original subsidiary GL account
    t.gl_account_code AS subsidiary_gl_code,

    -- Metrics
    SUM(t.amount_php) AS balance_php,
    COUNT(*) AS posting_count,

    ROUND(
        SUM(t.amount_php)
        /
        NULLIF(
            SUM(SUM(t.amount_php)) OVER (
                PARTITION BY
                    gl.group_gl_code,
                    d.year,
                    d.month_num
            ),
            0
        ) * 100,
        2
    ) AS subsidiary_gl_share_pct

FROM {{ ref('ent_transaction') }} t

JOIN {{ ref('gl_account_mapping') }} gl
    ON t.gl_account_code = gl.subsidiary_gl_code
   AND t.subsidiary_code = gl.subsidiary_code

JOIN {{ ref('dim_date') }} d
    ON t.transaction_date = d.date_key

GROUP BY
    d.year,
    d.month_num,
    d.month_name,
    t.subsidiary_code,
    gl.group_gl_code,
    gl.group_gl_name,
    gl.gl_category,
    gl.gl_sub_category,
    t.gl_account_code

ORDER BY
    d.year,
    d.month_num,
    gl.group_gl_code,
    t.subsidiary_code