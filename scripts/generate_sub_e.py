import random
import pandas as pd
from pathlib import Path
from datetime import date, datetime, timedelta
from ikidatagen import IkiDataGenerator

random.seed(42)

LEASE_N = 3000
PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"
OUTPUT_PATH = DATA_DIR / "sub_e/lease_contracts.csv"

PROPERTIES = [f"E-PROP-{str(i).zfill(4)}" for i in range(1, 101)]
TENANTS = [f"E-TENANT-{str(i).zfill(5)}" for i in range(1, 301)]
LEASE_TYPES = ["Commercial", "Residential", "Industrial", "Office", "Retail", "Mixed-Use", "Warehouse", "Land",
               "Build-to-Suit", "Co-Working", "Serviced Office", "Cold Storage", "Manufacturing", "Hospitality", "Healthcare"]
UNIT_TYPES = ["Office Unit", "Retail Space", "Warehouse", "Condo Unit", "Parking", "Studio Unit", "One-Bedroom", "Two-Bedroom", "Penthouse", "Townhouse",
              "Commercial Lot", "Industrial Lot", "Factory", "Storage Unit", "Kiosk", "Food Stall", "Co-Working Desk", "Meeting Room", "Showroom", "Distribution Center"]
TERMS_YEARS = [1, 2, 3, 5, 10]
schema = [
    {'label': '_row_number', 'key_label': 'row_number'},
    {'label': 'contract_id', 'key_label': 'lambda',
     'options': {'func': lambda row: f"E-LEASE-{str(row['_row_number']).zfill(6)}"}},
    {'label': 'property_id', 'key_label': 'custom_list',
     'options': {'values': PROPERTIES}},
    {'label': 'tenant_id', 'key_label': 'custom_list',
     'options': {'values': TENANTS}},
    {'label': 'unit_type', 'key_label': 'custom_list',
     'options': {'values': UNIT_TYPES}},
    {'label': 'lease_type', 'key_label': 'custom_list',
     'options': {'values': LEASE_TYPES}},
    {"label": "area_sqm", "key_label": "number", "options": {
        "min": 20, "max": 2000, "decimals": 2
    }},
    {"label": "_term_years", "key_label": "custom_list",
        "options": {"values": TERMS_YEARS}},
    {"label": "start_date", "key_label": "datetime", "options": {
        "from_date": '1/1/2022', "to_date": '06/01/2026', "date_format": "iso"
    }},
    {'label': 'end_date', 'key_label': 'lambda',
     'options': {'func': lambda row: (datetime.fromisoformat(row['start_date']) + timedelta(days=row['_term_years'] * 365)).isoformat()}},
    {'label': 'term_years', 'key_label': 'lambda',
     'options': {'func': lambda row: row['_term_years']}},
    {"label": "monthly_rent_php", "key_label": "number", "options": {
        "min": 5000, "max": 500000, "decimals": 2
    }},
    {'label': 'annual_rent_php', 'key_label': 'lambda',
     'options': {'func': lambda row: round(row['monthly_rent_php'] * 12, 2)}},
    {'label': 'security_deposit', 'key_label': 'lambda',
     'options': {'func': lambda row: round(row['monthly_rent_php'] * 2, 2)}},
    {"label": "rent_escalation_pct", "key_label": "number", "options": {
        "min": 3, "max": 8, "decimals": 2
    }},
    {'label': 'status', 'key_label': 'lambda',
     'options': {'func': lambda row: "ACTIVE" if datetime.fromisoformat(row['end_date']).date() > date.today() else "EXPIRED"}},
    {'label': 'city', 'key_label': 'custom_list',
     'options': {'values': ["Makati", "BGC", "Cebu City", "Davao City"]}},
]

payload = IkiDataGenerator(schema).many(LEASE_N).data
df = pd.DataFrame(payload)
df = df.drop(columns=['_row_number', '_term_years'])
df.to_csv(OUTPUT_PATH, index=False)
print(f"SUB_E leases: {len(df):,} rows")
