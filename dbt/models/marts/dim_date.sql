-- models/marts/dim_date.sql
{{
  config(materialized='table')
}}

WITH date_spine AS (
    {{ dbt_utils.date_spine(
        datepart   = 'day',
        start_date = "cast('2018-01-01' as date)",
        end_date   = "cast('2030-12-31' as date)"
    ) }}
)
SELECT
    cast(date_day AS DATE)              AS date_key,
    YEAR(date_day)                      AS year,
    QUARTER(date_day)                   AS quarter,
    MONTH(date_day)                     AS month_num,
    MONTHNAME(date_day)                 AS month_name,
    DAY(date_day)                       AS day_of_month,
    DAYOFWEEK(date_day)                 AS day_of_week,
    DAYNAME(date_day)                   AS day_name,
    WEEKOFYEAR(date_day)                AS week_of_year,
    CASE WHEN DAYOFWEEK(date_day) IN (1,7) THEN TRUE ELSE FALSE END AS is_weekend,
    TO_CHAR(date_day, 'YYYY-MM')        AS year_month,
    TO_CHAR(date_day, 'YYYY-"Q"Q')      AS year_quarter
FROM date_spine