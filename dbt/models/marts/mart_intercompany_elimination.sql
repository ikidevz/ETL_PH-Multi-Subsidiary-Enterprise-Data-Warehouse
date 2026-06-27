{{ config(materialized='table') }}

WITH interco_transactions AS (
    SELECT
        t.transaction_key,
        t.transaction_nk,
        t.subsidiary_code,
        t.customer_id_nk,
        t.transaction_date,
        t.gl_account_code,
        t.amount_php,
        gl.group_gl_code,
        gl.group_gl_name
    FROM {{ ref('ent_transaction') }} t
    JOIN {{ ref('gl_account_mapping') }} gl
      ON t.gl_account_code = gl.subsidiary_gl_code
     AND t.subsidiary_code = gl.subsidiary_code
    WHERE gl.gl_sub_category = 'INTERCOMPANY_REVENUE'
)

SELECT
    t1.transaction_key                          AS selling_txn_key,
    t2.transaction_key                          AS buying_txn_key,
    t1.subsidiary_code                          AS seller_subsidiary,
    t2.subsidiary_code                          AS buyer_subsidiary,
    t1.customer_id_nk                           AS shared_counterparty,
    t1.transaction_date,
    
    t1.gl_account_code                          AS seller_gl_code,
    t2.gl_account_code                          AS buyer_gl_code,
    
    t1.amount_php                               AS seller_amount_php,
    t2.amount_php                               AS buyer_amount_php,
    
    -- For easier validation and testing
    t1.amount_php                               AS interco_amount_php,
    t1.amount_php * -1                          AS elimination_debit_php,
    t2.amount_php                               AS elimination_credit_php,
    
    ABS(t1.amount_php - t2.amount_php)          AS amount_difference

FROM interco_transactions t1
JOIN interco_transactions t2
    ON  t1.customer_id_nk     = t2.customer_id_nk
    AND t1.transaction_date   = t2.transaction_date
    AND t1.subsidiary_code   != t2.subsidiary_code
WHERE t1.subsidiary_code < t2.subsidiary_code