WITH missing AS (
    SELECT 
        s.subsidiary_code,
        s.subsidiary_name
    FROM {{ ref('ent_subsidiary') }} s
    LEFT JOIN {{ ref('mart_consolidated_pnl') }} p 
           ON s.subsidiary_code = p.subsidiary_code
    WHERE p.subsidiary_code IS NULL
)

SELECT * FROM missing
WHERE subsidiary_code NOT IN ('SUB_C', 'SUB_E')