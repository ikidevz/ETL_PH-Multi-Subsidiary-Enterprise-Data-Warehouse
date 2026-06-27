SELECT *
FROM {{ ref('mart_intercompany_elimination') }}
WHERE interco_amount_php IS NULL
   OR seller_amount_php IS NULL
   OR buyer_amount_php IS NULL
   OR elimination_debit_php IS NULL
   OR elimination_credit_php IS NULL
   OR amount_difference >= 0.01