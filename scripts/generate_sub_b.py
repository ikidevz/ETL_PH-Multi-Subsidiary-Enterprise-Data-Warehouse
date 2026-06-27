import random
import pandas as pd
from pathlib import Path
from datetime import datetime, timedelta
from ikidatagen import IkiDataGenerator

random.seed(42)

SHIPMENTS_N = 15000
PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"
OUTPUT_PATH = DATA_DIR / "sub_b/shipments.csv"

CLIENTS = [f"B-CLIENT-{str(i).zfill(4)}" for i in range(1, 201)]
ROUTES = [
    ("MANILA", "CEBU"), ("MANILA", "DAVAO"), ("MANILA", "ILOILO"),
    ("MANILA", "BACOLOD"), ("MANILA", "CAGAYAN DE ORO"), ("MANILA", "ZAMBOANGA"),
    ("MANILA", "GENERAL SANTOS"), ("MANILA",
                                   "PUERTO PRINCESA"), ("MANILA", "TACLOBAN"),
    ("MANILA", "DUMAGUETE"), ("CEBU", "DAVAO"), ("CEBU", "ILOILO"),
    ("CEBU", "BACOLOD"), ("CEBU", "CAGAYAN DE ORO"), ("CEBU", "ZAMBOANGA"),
    ("CEBU", "GENERAL SANTOS"), ("CEBU", "TACLOBAN"), ("DAVAO", "CAGAYAN DE ORO"),
    ("DAVAO", "GENERAL SANTOS"), ("DAVAO", "ZAMBOANGA"), ("DAVAO", "BUTUAN"),
    ("ILOILO", "BACOLOD"), ("ILOILO", "CEBU"), ("CAGAYAN DE ORO", "BUTUAN"),
    ("CAGAYAN DE ORO", "GENERAL SANTOS"), ("ZAMBOANGA",
                                           "GENERAL SANTOS"), ("TACLOBAN", "CEBU"),
    ("PUERTO PRINCESA", "MANILA"), ("DUMAGUETE", "CEBU"), ("BUTUAN", "DAVAO")
]

SERVICE_TYPES = ["LCL", "FCL", "Express", "Economy", "Same Day", "Next Day", "Standard", "Priority", "Refrigerated",
                 "Oversized Cargo", "Hazardous Cargo", "Door-to-Door", "Port-to-Port", "Door-to-Port", "Port-to-Door"]

schema = [
    {'label': "shipment_id", "key_label": "uuid_v4"},
    {'label': 'client_id', 'key_label': 'custom_list',
     'options': {'values': CLIENTS}},
    {'label': '_route', 'key_label': 'custom_list',
     'options': {'values': ROUTES}},
    {'label': 'origin_city', 'key_label': 'lambda',
     'options': {'func': lambda row: row['_route'][0]}},
    {'label': 'dest_city', 'key_label': 'lambda',
     'options': {'func': lambda row: row['_route'][1]}},
    {'label': 'service_type', 'key_label': 'custom_list',
     'options': {'values': SERVICE_TYPES}},
    {"label": "ship_date", "key_label": "datetime", "options": {
        "from_date": '1/1/2022', "to_date": '06/01/2026', "date_format": "iso"
    }},
    {'label': '_delay', 'key_label': 'lambda',
     'options': {'func': lambda: random.choices([0, random.randint(1, 5)], weights=[70, 30])[0]}},
    {'label': '_lead_days', 'key_label': 'number',
     'options': {'min': 1, 'max': 14}},
    {'label': 'expected_del', 'key_label': 'lambda',
     'options': {'func': lambda row: (datetime.fromisoformat(row['ship_date']) + timedelta(days=row['_lead_days'])).isoformat()}},
    {'label': 'actual_del', 'key_label': 'lambda',
     'options': {'func': lambda row: (datetime.fromisoformat(row['ship_date']) + timedelta(days=row['_lead_days'] + row['_delay'])).isoformat()}},
    {'label': 'delay_days', 'key_label': 'lambda',
     'options': {'func': lambda row: row['_delay']}},
    {"label": "weight_kg", "key_label": "number", "options": {
        "min": 10, "max": 5000, "decimals": 2
    }},
    {"label": "volume_cbm", "key_label": "number", "options": {
        "min": 0.1, "max": 50, "decimals": 2
    }},
    {"label": "freight_revenue", "key_label": "number", "options": {
        "min": 500, "max": 150000, "decimals": 2
    }},
    {'label': 'fuel_surcharge', 'key_label': 'lambda',
     'options': {'func': lambda row: round(row['freight_revenue'] * 0.08, 2)}},
    {'label': 'total_revenue', 'key_label': 'lambda',
     'options': {'func': lambda row: round(row['freight_revenue'] + row['fuel_surcharge'], 2)}},
    {'label': 'currency', 'key_label': 'lambda',
     'options': {'func': lambda: "PHP"}},
    {'label': 'modified_ts', 'key_label': 'lambda',
     'options': {'func': lambda row: row['ship_date']}},
]
payload = IkiDataGenerator(schema).many(SHIPMENTS_N).data
df = pd.DataFrame(payload)
df = df.drop(columns=['_route', '_delay', '_lead_days'])
df.to_csv(OUTPUT_PATH, index=False)
print(f"SUB_B shipments: {len(df):,} rows")
