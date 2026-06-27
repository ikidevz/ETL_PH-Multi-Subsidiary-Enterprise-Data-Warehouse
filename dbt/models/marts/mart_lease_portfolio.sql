-- models/marts/mart_lease_portfolio.sql
{{
  config(materialized='table')
}}

SELECT
    src.lease_type,
    src.unit_type,
    src.city,

    COUNT(*)                                            AS total_units,
    COUNT(CASE WHEN src.status = 'ACTIVE'  THEN 1 END) AS occupied_units,
    COUNT(CASE WHEN src.status = 'EXPIRED' THEN 1 END) AS vacant_units,

    ROUND(
        COUNT(CASE WHEN src.status = 'ACTIVE' THEN 1 END)
        / NULLIF(COUNT(*), 0) * 100,
        2
    )                                                   AS occupancy_rate_pct,

    SUM(src.area_sqm)                                   AS total_area_sqm,
    SUM(CASE WHEN src.status = 'ACTIVE'
             THEN src.area_sqm ELSE 0 END)              AS occupied_area_sqm,

    SUM(CASE WHEN src.status = 'ACTIVE'
             THEN src.monthly_rent_php ELSE 0 END)      AS monthly_rent_roll_php,
    SUM(CASE WHEN src.status = 'ACTIVE'
             THEN src.annual_rent_php ELSE 0 END)       AS arr_php,
    SUM(src.security_deposit)                           AS total_deposits_held_php,

    ROUND(
        SUM(CASE WHEN src.status = 'ACTIVE'
                 THEN src.rent_escalation_pct * src.monthly_rent_php ELSE 0 END)
        / NULLIF(SUM(CASE WHEN src.status = 'ACTIVE'
                          THEN src.monthly_rent_php ELSE 0 END), 0),
        2
    )                                                   AS wtd_avg_escalation_pct,

    -- Leases expiring within 90 days (renewal risk)
    COUNT(
        CASE WHEN src.status = 'ACTIVE'
              AND DATEDIFF('day', CURRENT_DATE(), src.end_date) <= 90
             THEN 1 END
    )                                                   AS expiring_90d_count,
    SUM(
        CASE WHEN src.status = 'ACTIVE'
              AND DATEDIFF('day', CURRENT_DATE(), src.end_date) <= 90
             THEN src.monthly_rent_php ELSE 0 END
    )                                                   AS expiring_90d_monthly_rent_php

FROM {{ ref('stg_sub_e_leases') }}  src
GROUP BY 1, 2, 3