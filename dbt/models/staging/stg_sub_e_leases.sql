-- models/staging/stg_sub_e_leases.sql
{{ config(materialized='view') }}

SELECT
    -- Integration keys
    contract_id                                     AS transaction_nk,
    'SUB_E'                                         AS subsidiary_code,
    tenant_id                                       AS customer_id_nk,

    -- Dates
    start_date::DATE                                AS transaction_date,

    -- Financial
    annual_rent_php                                 AS amount_local,
    'PHP'                                           AS currency_code,
    -- Fixed: was 'LEASE_REVENUE' which doesn't exist in gl_account_mapping seed
    'RENTAL_INCOME'                                 AS gl_account_code,

    -- SUB_E property-specific columns (passed through for mart_lease_portfolio)
    property_id,
    unit_type,
    lease_type,
    area_sqm,
    term_years,
    end_date::DATE                                  AS end_date,
    monthly_rent_php,
    annual_rent_php,
    security_deposit,
    rent_escalation_pct,
    status,
    city,

    -- Audit
    -- SUB_E has no CDC watermark; use start_date as a reasonable proxy
    start_date::TIMESTAMP                           AS _loaded_at

FROM {{ source('bronze', 'raw_sub_e_leases') }}