-- models/staging/stg_sub_c_loans.sql
{{ config(materialized='view') }}

SELECT
    -- Make transaction_nk unique (loan_id can repeat across snapshots or reloads)
    MD5(loan_id || origination_date::DATE)      AS transaction_nk,
    
    'SUB_C'                                     AS subsidiary_code,
    borrower_id                                 AS customer_id_nk,

    origination_date::DATE                      AS transaction_date,

    outstanding_balance                         AS amount_local,
    'PHP'                                       AS currency_code,
    'INTEREST_INCOME'                           AS gl_account_code,

    loan_type,
    branch_id,
    principal_amount,
    interest_rate,
    outstanding_balance,
    monthly_payment,
    term_months,
    maturity_date::DATE                         AS maturity_date,
    days_past_due,

    CASE
        WHEN loan_status IN ('Current')                     THEN 'CURRENT'
        WHEN loan_status = 'Grace Period'                   THEN 'GRACE_PERIOD'
        WHEN loan_status = '30 DPD'                         THEN '30DPD'
        WHEN loan_status = '60 DPD'                         THEN '60DPD'
        WHEN loan_status = '90 DPD'                         THEN '90DPD'
        WHEN loan_status IN ('120+ DPD', 'Past Due', 'Default', 
                             'Non-Performing Loan (NPL)', 'Under Collection', 'Legal Action') 
                                                            THEN 'NPL'
        WHEN loan_status IN ('Restructured', 'Refinanced')  THEN 'RESTRUCTURED'
        WHEN loan_status IN ('Foreclosed', 'Charged Off', 'Written Off') 
                                                            THEN 'CHARGED_OFF'
        WHEN loan_status IN ('Closed', 'Paid Off')          THEN 'CLOSED'
        ELSE loan_status
    END                                         AS loan_status,

    last_updated::TIMESTAMP                     AS _loaded_at

FROM {{ source('bronze', 'raw_sub_c_loans') }}