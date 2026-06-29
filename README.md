# PH Multi-Subsidiary EDW

![cover_img](https://tdhghaslnufgtzjybhhf.supabase.co/storage/v1/object/public/content/ETL%20Engineer%20Portfoilo/ph_multi_subsdridary.png)

This project is a portfolio-grade enterprise data warehouse designed to unify five subsidiaries operating in different industries and using different source systems into one governed reporting layer. The ambition is not just to move data from point A to point B, but to create a trusted, conformed foundation for finance, operations, and executive reporting.

At the center of the design is a metadata-driven ingestion model: new subsidiaries can be onboarded through configuration rather than bespoke pipeline logic. That makes the platform feel less like a one-off demo and more like a serious enterprise architecture pattern.

---

## What this project represents

This is a full-stack data engineering story in one repository:

- heterogeneous source ingestion across retail, freight, lending, manufacturing, and property systems
- a normalized 3NF integration layer for enterprise-wide consistency
- conformed dimensional marts for business reporting
- data quality and schema evolution controls built into the workflow
- an operational pattern that scales beyond a single use case

In short, this is a strong example of how modern analytics engineering can be used to turn fragmented business data into a credible enterprise asset.

---

## Architecture at a glance

```text
Subsidiary source systems
  ↓
Bronze layer: per-subsidiary raw tables with CDC awareness
  ↓
Integration layer: normalized enterprise entities (ent_customer, ent_account, ent_transaction, ent_product, ent_subsidiary)
  ↓
Conformed marts: 15 business-ready reporting models across group, subsidiary, and industry lenses
  ↓
Governed control layer: metadata that drives ingestion behavior
```

The platform follows an Inmon-style approach:

- integration first
- business entities normalized once
- marts built on top of that shared foundation
- reporting logic separated from source complexity

That structure is what makes the warehouse resilient when each subsidiary defines the same concept differently.

---

## Why this design is compelling

A retail customer, a banking borrower, and a property tenant are not the same entity by default. They only become comparable once they are modeled in a common enterprise structure.

That is the core reason this project exists. Instead of forcing each business unit into a local interpretation of customer, account, or transaction, the warehouse creates one shared enterprise definition and lets the marts consume that definition consistently.

This is what makes the solution feel mature:

- one canonical model for shared entities
- no duplication of business logic across marts
- room for future expansion without rewriting the model
- a clear path from raw source data to executive reporting

---

## Subsidiary landscape

| Code  | Name          | Industry            | Source context             | Notes                                   |
| ----- | ------------- | ------------------- | -------------------------- | --------------------------------------- |
| SUB_A | RetailCo      | Retail              | Custom POS + ERP           | Revenue, customer activity, channel mix |
| SUB_B | LogisticsCo   | Logistics / Freight | Oracle TMS                 | Operational throughput, OTD, cost       |
| SUB_C | FinanceCo     | Lending             | Core banking system        | Credit risk, portfolio health, DPD      |
| SUB_D | ManufactureCo | Manufacturing       | SAP S/4 (simulated)        | Production, fulfillment, fill rate      |
| SUB_E | PropertyCo    | Real estate         | Property management system | Occupancy, rent roll, lease expiry      |

---

## The data model

### Integration layer

The foundation of the warehouse is a 3NF enterprise model that normalizes shared concepts across subsidiaries.

| Entity          | Purpose                                           |
| --------------- | ------------------------------------------------- |
| ent_subsidiary  | Master reference for all subsidiaries             |
| ent_customer    | Unified customer entity across source systems     |
| ent_account     | Shared account model for financial entities       |
| ent_transaction | Conformed transaction history with PHP conversion |
| ent_product     | Product and service reference data                |

### Conformed marts

These marts are the business-facing layer of the platform.

| Mart                            | Scope        | Business value                                                       |
| ------------------------------- | ------------ | -------------------------------------------------------------------- |
| `mart_consolidated_pnl`         | All subs     | Group-level revenue and profitability by month, subsidiary, GL line  |
| `mart_intercompany_elimination` | All subs     | Flags likely related-party transaction pairs for consolidation       |
| `mart_customer_360`             | All subs     | Cross-subsidiary customer visibility and cross-sell intelligence     |
| `mart_subsidiary_kpi`           | All subs     | Monthly subsidiary scorecards with MoM growth and group share        |
| `mart_fx_exposure`              | All subs     | Currency exposure, FX sensitivity, and PHP translation risk          |
| `mart_product_performance`      | All subs     | Category revenue rank and share using the `ent_product` entity       |
| `mart_gl_account_bridge`        | All subs     | Subsidiary GL codes mapped to group Chart of Accounts                |
| `mart_cost_center_spend`        | All subs     | OPEX and COGS tracked by cost center across all subsidiaries         |
| `mart_retail_sales`             | SUB_A        | Channel mix, category performance, regional revenue, discount impact |
| `mart_cohort_retention`         | SUB_A, SUB_C | Customer acquisition cohort retention rates by month                 |
| `mart_freight_ops`              | SUB_B        | OTD rate, route revenue, delay analysis, service mix                 |
| `mart_cash_collection`          | SUB_B, SUB_C | Days Sales Outstanding and on-time collection rate                   |
| `mart_loan_portfolio`           | SUB_C        | Portfolio health: NPL rate, DPD buckets, balance at risk             |
| `mart_order_fulfillment`        | SUB_D        | Fill rate, cancellation rate, lead time, plant throughput            |
| `mart_lease_portfolio`          | SUB_E        | Occupancy, ARR, rent escalation, 90-day expiry pipeline              |

---

## What makes the ingestion layer interesting

The ingestion engine is driven by metadata held in the control layer. Instead of hard-coding every subsidiary pipeline, the workflow reads configuration and applies the same pattern across active sources.

That gives the project a very practical advantage:

- new subsidiaries can be onboarded through configuration changes
- the pipeline remains consistent even as source shapes evolve
- the architecture feels reusable rather than handcrafted

Two seed files extend this configurability into the mart layer: `fx_rates.csv` provides daily PHP conversion rates consumed by `mart_fx_exposure`, and `gl_account_mapping.csv` provides the subsidiary-to-group GL code mapping consumed by `mart_gl_account_bridge`. Both are reference datasets that would live in a proper MDM system in production — the seed pattern is a deliberate, honest proxy for that.

---

## Engineering choices that strengthen the project

A few design decisions make this warehouse feel more intentional and production-oriented:

1. Integration-first modeling
   - shared entities are normalized before reporting marts are built
   - `ent_product` is fully consumed by `mart_product_performance` and `mart_cost_center_spend` — no integration entity sits unused

2. Conformed marts
   - analytics are not duplicated across inconsistent interpretations of the same business concept
   - `dim_date` is a single conformed date dimension built once via `dbt_utils.date_spine` and joined by every mart

3. Group COA harmonisation
   - `mart_gl_account_bridge` maps each subsidiary's raw GL codes to the group Chart of Accounts using the `gl_account_mapping.csv` seed
   - without this, a consolidated P&L across five different ERPs is a sum of incomparable line items

4. Schema evolution handling
   - incremental models are designed to absorb drift without silently breaking
   - `on_schema_change: sync_all_columns` means a subsidiary ERP upgrade adds columns to downstream models automatically

5. Data quality embedded in dbt
   - every mart has column-level tests in `schema.yml` covering `not_null`, `accepted_values`, range checks via `dbt_expectations`, and grain uniqueness via `dbt_utils`
   - custom singular tests (`assert_all_subsidiaries_present`, `assert_interco_balance`) enforce cross-subsidiary consistency

6. Metadata-driven orchestration
   - the ingestion engine reads `control.ingestion_config` at runtime — new subsidiaries are onboarded through a config row, not a new pipeline

7. Treasury and risk coverage
   - `mart_fx_exposure` tracks PHP translation risk and 5% rate sensitivity for every non-PHP currency across the group
   - `mart_cash_collection` computes Days Sales Outstanding for SUB_B and SUB_C where billed-vs-collected timing is embedded in the source data at no extra ingestion cost

8. Customer lifecycle visibility
   - `mart_cohort_retention` answers whether acquired customers are retained month over month, using `acquire_date` on `ent_customer` and `origination_date` from the lending system

---

## Project structure

```text
snowflake/          - warehouse, schema, and control table DDL
scripts/            - metadata ingestion engine and per-subsidiary data generators
enterprise_dbt/
  models/
    staging/        - per-subsidiary source staging models
    integration/    - 3NF enterprise entities (ent_*)
    marts/          - dim_date and all 15 conformed mart models
  seeds/            - fx_rates.csv and gl_account_mapping.csv reference data
  tests/            - singular cross-subsidiary consistency tests
dags/               - Airflow metadata-driven DAG for scheduled runs
data/               - sample source CSV files for each subsidiary
docs/               - architecture decision records
```

This repository is organized in a way that reflects the flow of data from raw source to governed analytics, with each layer clearly separated.

---

## Why this project stands out

What makes this repository particularly strong is that it goes beyond a simple data pipeline. It demonstrates a complete thinking process:

- understand the business domain across five very different industries
- model the enterprise carefully with a 3NF integration layer that creates shared canonical entities
- separate raw ingestion from trusted analytics at every layer
- make the system extensible through metadata-driven ingestion
- expose 15 business-ready marts covering group consolidation, subsidiary operations, credit risk, treasury, customer lifecycle, and cost management

The mart layer is deliberately broad: it covers both the cross-subsidiary questions only a holding company can ask (`mart_consolidated_pnl`, `mart_intercompany_elimination`, `mart_fx_exposure`, `mart_gl_account_bridge`) and the industry-specific operational questions each subsidiary needs (`mart_loan_portfolio`, `mart_freight_ops`, `mart_lease_portfolio`, `mart_order_fulfillment`, `mart_retail_sales`).

The result is a project that reads like an actual data platform blueprint rather than a toy example, and that is exactly the kind of documentation that makes a portfolio project memorable.
