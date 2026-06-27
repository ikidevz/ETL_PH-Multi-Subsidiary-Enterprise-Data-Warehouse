import csv
import random
import pandas as pd
from datetime import date, timedelta
from pathlib import Path

random.seed(42)

OUTPUT_DIR = Path("dbt/seeds")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# ── GL Account Mapping ─────────────────────────────────────────────────────
GL_FIELDS = ["subsidiary_code", "subsidiary_gl_code", "group_gl_code",
             "group_gl_name", "gl_category", "gl_sub_category"]

GL_MAPPING = [
    # SUB_A
    ("SUB_A", "RETAIL_REVENUE",        "GRP-4100", "Group Product Revenue",
     "REVENUE", "PRODUCT_REVENUE"),
    ("SUB_A", "RETAIL_COGS",           "GRP-5100",
     "Group Cost of Goods Sold",                       "COGS",    "PRODUCT_COGS"),
    ("SUB_A", "RETAIL_OPEX",           "GRP-6100",
     "Group Selling & Distribution Expense",           "OPEX",    "SELLING_OPEX"),
    ("SUB_A", "INTERCO_REVENUE",       "GRP-4900",
     "Intercompany Revenue (Elimination)",             "REVENUE", "INTERCOMPANY_REVENUE"),
    # SUB_B
    ("SUB_B", "FREIGHT_REVENUE",       "GRP-4200",
     "Group Freight & Logistics Revenue",              "REVENUE", "FREIGHT_REVENUE"),
    ("SUB_B", "FUEL_COST",             "GRP-5200", "Group Fuel & Fleet Cost",
     "COGS",    "LOGISTICS_COGS"),
    ("SUB_B", "LOGISTICS_OPEX",        "GRP-6200",
     "Group Logistics Operating Expense",              "OPEX",    "LOGISTICS_OPEX"),
    ("SUB_B", "INTERCO_FREIGHT",       "GRP-4910",
     "Intercompany Freight Revenue (Elimination)",     "REVENUE", "INTERCOMPANY_REVENUE"),
    # SUB_C
    ("SUB_C", "INTEREST_INCOME",       "GRP-4300", "Group Interest & Fee Income",
     "REVENUE", "INTEREST_INCOME"),
    ("SUB_C", "LOAN_PROVISION",        "GRP-5300", "Group Credit Loss Provision",
     "COGS",    "CREDIT_PROVISION"),
    ("SUB_C", "BANKING_OPEX",          "GRP-6300",
     "Group Banking & Financial Services Expense",     "OPEX",    "BANKING_OPEX"),
    ("SUB_C", "INTERCO_INTEREST",      "GRP-4920",
     "Intercompany Interest Income (Elimination)",     "REVENUE", "INTERCOMPANY_REVENUE"),
    # SUB_D
    ("SUB_D", "MANUFACTURING_REVENUE", "GRP-4400",
     "Group Manufacturing & Product Sales Revenue",    "REVENUE", "PRODUCT_REVENUE"),
    ("SUB_D", "RAW_MATERIAL_COST",     "GRP-5400",
     "Group Raw Material & Production Cost",           "COGS",    "MANUFACTURING_COGS"),
    ("SUB_D", "PLANT_OPEX",            "GRP-6400",
     "Group Plant & Manufacturing Overhead",           "OPEX",    "PLANT_OPEX"),
    ("SUB_D", "INTERCO_SUPPLIES",      "GRP-4930",
     "Intercompany Supplies Revenue (Elimination)",    "REVENUE", "INTERCOMPANY_REVENUE"),
    # SUB_E
    ("SUB_E", "RENTAL_INCOME",         "GRP-4500",
     "Group Rental & Lease Revenue",                   "REVENUE", "RENTAL_REVENUE"),
    ("SUB_E", "PROPERTY_DEPRECIATION", "GRP-5500",
     "Group Property Depreciation",                    "COGS",    "DEPRECIATION"),
    ("SUB_E", "PROPERTY_OPEX",         "GRP-6500",
     "Group Property & Facilities Expense",            "OPEX",    "PROPERTY_OPEX"),
    ("SUB_E", "INTERCO_LEASE",         "GRP-4940",
     "Intercompany Lease Revenue (Elimination)",       "REVENUE", "INTERCOMPANY_REVENUE"),
]

gl_path = OUTPUT_DIR / "gl_account_mapping.csv"
with open(gl_path, "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow(GL_FIELDS)
    writer.writerows(GL_MAPPING)
print(f"[OK] gl_account_mapping.csv → {len(GL_MAPPING)} rows")

# ── FX Rates ───────────────────────────────────────────────────────────────
START_DATE = "2018-01-01"
END_DATE = date.today().isoformat()

CURRENCY_TICKERS = {
    "USD": "USDPHP=X",
    "SGD": "SGDPHP=X",
    "EUR": "EURPHP=X",
    "JPY": "JPYPHP=X",
    "CNY": "CNYPHP=X",
}

FALLBACK_BASE_RATES = {
    "USD": (52.00, 0.003),
    "SGD": (39.00, 0.003),
    "EUR": (62.00, 0.004),
    "JPY": (0.475, 0.004),
    "CNY": (8.00,  0.003),
}

fx_path = OUTPUT_DIR / "fx_rates.csv"

try:
    import yfinance as yf

    print(f"  Downloading FX tickers from Yahoo Finance ...")
    raw = yf.download(list(CURRENCY_TICKERS.values()), start=START_DATE,
                      end=END_DATE, auto_adjust=True, progress=False)

    close = raw["Close"] if isinstance(
        raw.columns, pd.MultiIndex) else raw[["Close"]]
    close.rename(
        columns={v: k for k, v in CURRENCY_TICKERS.items()}, inplace=True)
    close = close.reindex(pd.date_range(
        START_DATE, END_DATE, freq="D")).ffill().bfill()
    close.dropna(how="all", inplace=True)
    close.index.name = "rate_date"

    df = close.reset_index().melt(id_vars="rate_date",
                                  var_name="from_currency", value_name="usd_php_rate")
    df["rate_date"] = df["rate_date"].dt.strftime("%Y-%m-%d")
    df["to_currency"] = "PHP"
    df["rate"] = (1 / df["usd_php_rate"]).round(8)
    df["usd_php_rate"] = df["usd_php_rate"].round(6)
    df = df[df["from_currency"].isin(CURRENCY_TICKERS)][
        ["rate_date", "from_currency", "to_currency", "rate", "usd_php_rate"]
    ].sort_values(["from_currency", "rate_date"])

    print(f"[OK] fx_rates.csv → {len(df):,} rows (Yahoo Finance)")

except Exception as exc:
    print(
        f"  [WARN] Yahoo Finance unavailable: {exc} — using synthetic fallback.")

    rows = []
    start = date(2018, 1, 1)
    end = date.today()
    for currency, (base_rate, vol) in FALLBACK_BASE_RATES.items():
        rate = base_rate
        d = start
        while d <= end:
            rate = max(
                round(rate * (1 + random.uniform(-vol, vol)), 6), base_rate * 0.20)
            rows.append({"rate_date": d.isoformat(), "from_currency": currency,
                         "to_currency": "PHP", "rate": round(1 / rate, 8), "usd_php_rate": rate})
            d += timedelta(days=1)

    df = pd.DataFrame(rows)
    print(f"[OK] fx_rates.csv → {len(df):,} rows (synthetic fallback)")

df.to_csv(fx_path, index=False)
