USE DATABASE enterprise_dw;

INSERT INTO enterprise_dw.control.ingestion_config
    (subsidiary_code, source_schema, source_table, target_schema, target_table, load_strategy, incremental_column, primary_key_column, active, last_loaded_at)
VALUES
    ('SUB_A', 'sub_a_pos', 'sales_transactions', 'bronze', 'raw_sub_a_sales', 'INCREMENTAL', 'updated_at', 'order_id', TRUE, NULL),
    ('SUB_A', 'sub_a_pos', 'customers', 'bronze', 'raw_sub_a_customers', 'FULL', NULL, 'customer_id', TRUE, NULL),
    ('SUB_B', 'sub_b_tms', 'shipments', 'bronze', 'raw_sub_b_shipments', 'INCREMENTAL', 'modified_ts', 'shipment_id', TRUE, NULL),
    ('SUB_C', 'sub_c_core', 'loan_accounts', 'bronze', 'raw_sub_c_loans', 'INCREMENTAL', 'last_updated', 'loan_id', TRUE, NULL),
    ('SUB_D', 'sub_d_sap', 'sales_orders', 'bronze', 'raw_sub_d_orders', 'INCREMENTAL', 'change_date', 'order_num', TRUE, NULL),
    ('SUB_E', 'sub_e_pms', 'lease_contracts', 'bronze', 'raw_sub_e_leases', 'FULL', NULL, 'contract_id', TRUE, NULL);
