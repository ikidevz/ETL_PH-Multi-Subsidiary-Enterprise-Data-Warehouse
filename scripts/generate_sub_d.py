import random
import pandas as pd
from pathlib import Path
from datetime import datetime, timedelta
from ikidatagen import IkiDataGenerator

random.seed(42)

ORDERS_N = 20000
PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"
OUTPUT_PATH = DATA_DIR / "sub_d/sales_orders.csv"

PLANTS = ["D-PLANT-BULACAN", "D-PLANT-LAGUNA", "D-PLANT-CEBU", "D-PLANT-DAVAO", "D-PLANT-BATANGAS",
          "D-PLANT-PAMPANGA", "D-PLANT-ILOILO", "D-PLANT-CAGAYAN", "D-PLANT-ZAMBOANGA", "D-PLANT-GENERAL-SANTOS"]
DOC_TYPES = ["STANDARD", "RUSH", "RETURN", "CONSIGNMENT", "TRANSFER", "EXPORT", "IMPORT", "SAMPLE",
             "PROMOTIONAL", "REPLACEMENT", "DAMAGE-RETURN", "WARRANTY", "INTERCOMPANY", "EMERGENCY", "BACKORDER"]
CUSTOMERS = [f"D-CUST-{str(i).zfill(5)}" for i in range(1, 5001)]
SALES_ORGS = ["D-SO-PH01", "D-SO-PH02", "D-SO-PH03", "D-SO-PH04", "D-SO-PH05"]

schema = [
    {'label': 'order_num', 'key_label': 'character_sequence',
     'options': {'pattern': "D-SO-##########"}},
    {'label': 'order_item', 'key_label': 'lambda',
     'options': {'func': lambda: f"{random.randint(1000, 9900):03d}"}},
    {'label': 'doc_type', 'key_label': 'custom_list',
     'options': {'values': DOC_TYPES}},
    {'label': 'sales_org', 'key_label': 'custom_list',
     'options': {'values': SALES_ORGS}},
    {'label': 'customer_id', 'key_label': 'custom_list',
     'options': {'values': CUSTOMERS}},

    {'label': 'material_id', 'key_label': 'character_sequence',
     'options': {'pattern': "D-MAT-%%%%-########"}},

    {'label': 'plant', 'key_label': 'custom_list',
     'options': {'values': PLANTS}},
    {"label": "order_date", "key_label": "datetime", "options": {
        "from_date": '1/1/2020', "to_date": '06/01/2026', "date_format": "iso"
    }},
    {'label': 'requested_del', 'key_label': 'lambda',
     'options': {'func': lambda row: (datetime.fromisoformat(row['order_date']) + timedelta(days=random.randint(3, 30))).isoformat()}},
    {'label': 'confirmed_del', 'key_label': 'lambda',
     'options': {'func': lambda row: (datetime.fromisoformat(row['requested_del']) + timedelta(days=random.randint(1, 5))).isoformat()}},
    {"label": "order_qty", "key_label": "number", "options": {
        "min": 10, "max": 1000
    }},
    {'label': 'delivered_qty', 'key_label': 'lambda',
     'options': {'func': lambda row: f"{random.randint(int(row['order_qty'] * 0.8), row['order_qty']):03d}"}},
    {"label": "net_price", "key_label": "number", "options": {
        "min": 50, "max": 10000, "decimals": 2
    }},
    {'label': 'order_value_php', 'key_label': 'lambda',
     'options': {'func': lambda row: round(row['order_qty'] * row['net_price'], 2)}},
    {'label': 'currency', 'key_label': 'lambda',
     'options': {'func': lambda: "PHP"}},
    {'label': 'status', 'key_label': 'custom_list',
     'options': {'values': ["OPEN", "DELIVERED", "BILLED", "CANCELLED"]}},
    {'label': 'change_date', 'key_label': 'lambda',
     'options': {'func': lambda row: (datetime.fromisoformat(row['order_date']) + timedelta(days=random.randint(0, 10))).isoformat()}},
]
payload = IkiDataGenerator(schema).many(ORDERS_N).data
df = pd.DataFrame(payload)
df.to_csv(OUTPUT_PATH, index=False)
print(f"SUB_D orders: {len(df):,} rows")
