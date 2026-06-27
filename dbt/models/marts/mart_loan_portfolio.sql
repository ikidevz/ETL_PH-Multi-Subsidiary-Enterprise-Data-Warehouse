-- models/marts/mart_loan_portfolio.sql
{{
  config(materialized='table')
}}

/*
  Reads from stg_sub_c_loans which normalizes raw loan_status values
  (e.g. '30 DPD', 'Non-Performing Loan (NPL)') into standard codes
  ('30DPD', 'NPL') so CASE WHEN filters work correctly.
*/

SELECT
    src.loan_type,
    src.branch_id,

    COUNT(*)                                                AS loan_count,
    SUM(src.principal_amount)                               AS total_principal_php,
    SUM(src.outstanding_balance)                            AS total_outstanding_php,
    ROUND(AVG(src.interest_rate), 2)                        AS avg_interest_rate_pct,
    ROUND(AVG(src.term_months), 0)                          AS avg_term_months,

    -- DPD bucket distribution (IFRS 9 staging)
    COUNT(CASE WHEN src.loan_status = 'CURRENT'       THEN 1 END) AS current_count,
    COUNT(CASE WHEN src.loan_status = 'GRACE_PERIOD'  THEN 1 END) AS grace_period_count,
    COUNT(CASE WHEN src.loan_status = '30DPD'         THEN 1 END) AS dpd_30_count,
    COUNT(CASE WHEN src.loan_status = '60DPD'         THEN 1 END) AS dpd_60_count,
    COUNT(CASE WHEN src.loan_status = '90DPD'         THEN 1 END) AS dpd_90_count,
    COUNT(CASE WHEN src.loan_status = 'NPL'           THEN 1 END) AS npl_count,
    COUNT(CASE WHEN src.loan_status = 'RESTRUCTURED'  THEN 1 END) AS restructured_count,
    COUNT(CASE WHEN src.loan_status = 'CHARGED_OFF'   THEN 1 END) AS charged_off_count,

    -- NPL rate — key credit risk KPI
    ROUND(
        COUNT(CASE WHEN src.loan_status = 'NPL' THEN 1 END)
        / NULLIF(COUNT(*), 0) * 100,
        2
    )                                                       AS npl_rate_pct,

    -- Balance at risk (90DPD + NPL outstanding)
    SUM(CASE WHEN src.loan_status IN ('90DPD', 'NPL')
             THEN src.outstanding_balance ELSE 0 END)       AS balance_at_risk_php,

    ROUND(
        SUM(CASE WHEN src.loan_status IN ('90DPD', 'NPL')
                 THEN src.outstanding_balance ELSE 0 END)
        / NULLIF(SUM(src.outstanding_balance), 0) * 100,
        2
    )                                                       AS balance_at_risk_pct

FROM {{ ref('stg_sub_c_loans') }}  src
WHERE src.loan_status != 'CLOSED'
GROUP BY 1, 2