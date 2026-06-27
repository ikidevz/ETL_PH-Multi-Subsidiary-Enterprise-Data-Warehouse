-- models/marts/mart_freight_ops.sql
{{
    config(
        materialized='incremental',
        unique_key=['year', 'month_num', 'origin_city', 'dest_city', 'service_type'],
        on_schema_change='append_new_columns'
    )
}}

WITH source_shipments AS (
    SELECT *
    FROM {{ ref('stg_sub_b_shipments') }}

    {% if is_incremental() %}
    WHERE _loaded_at >
    (
        SELECT COALESCE(
            MAX(load_timestamp),
            '1900-01-01'::TIMESTAMP
        )
        FROM {{ this }}
    )
    {% endif %}
),

aggregated_shipments AS (
    SELECT
        d.year,
        d.month_num,
        d.month_name,
        s.origin_city,
        s.dest_city,
        s.origin_city || ' → ' || s.dest_city      AS route,
        s.service_type,
        COUNT(*)                                   AS shipment_count,
        SUM(s.weight_kg)                           AS total_weight_kg,
        SUM(s.volume_cbm)                          AS total_volume_cbm,
        SUM(s.freight_revenue)                     AS freight_revenue_php,
        SUM(s.fuel_surcharge)                      AS fuel_surcharge_php,
        SUM(s.amount_local)                        AS total_revenue_php,
        ROUND(
            SUM(s.amount_local)
            / NULLIF(SUM(s.weight_kg), 0),
            4
        )                                          AS revenue_per_kg,
        COUNT(
            CASE
                WHEN s.delay_days = 0 THEN 1
            END
        )                                          AS on_time_count,
        ROUND(
            COUNT(
                CASE
                    WHEN s.delay_days = 0 THEN 1
                END
            )
            / NULLIF(COUNT(*), 0) * 100,
            2
        )                                          AS otd_rate_pct,
        ROUND(AVG(s.delay_days), 2)                AS avg_delay_days,
        MAX(s.delay_days)                          AS max_delay_days,
        COUNT(
            CASE
                WHEN s.delay_days > 3 THEN 1
            END
        )                                          AS severely_delayed_count

    FROM source_shipments s
    JOIN {{ ref('dim_date') }} d
        ON s.transaction_date = d.date_key
    GROUP BY
        d.year,
        d.month_num,
        d.month_name,
        s.origin_city,
        s.dest_city,
        route,
        s.service_type
),

final AS (
    SELECT
        *,
        CURRENT_TIMESTAMP() AS load_timestamp
    FROM aggregated_shipments
)

SELECT *
FROM final