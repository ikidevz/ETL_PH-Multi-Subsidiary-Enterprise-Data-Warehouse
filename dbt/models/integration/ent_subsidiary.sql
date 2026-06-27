-- models/integration/ent_subsdiary.sql
{{ config(materialized='table') }}

SELECT 'SUB_A' AS subsidiary_code, 'RetailCo'      AS subsidiary_name, 'Retail'        AS industry_type, 'PHP' AS reporting_currency
UNION ALL
SELECT 'SUB_B',                     'LogisticsCo',  'Freight',          'PHP'
UNION ALL
SELECT 'SUB_C',                     'FinanceCo',    'Lending',          'PHP'
UNION ALL
SELECT 'SUB_D',                     'ManufactureCo','Manufacturing',    'PHP'
UNION ALL
SELECT 'SUB_E',                     'PropertyCo',   'Real Estate',      'PHP'