import random
import pandas as pd
from pathlib import Path
from ikidatagen import IkiDataGenerator


SUB_A_N_CUSTOMERS = 5000
PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"
sales_transaction_output_path = DATA_DIR / "sub_a/sales_transactions.csv"
sales_customer_output_path = DATA_DIR / "sub_a/customers.csv"

CHANNELS = ["In-Store", "Flagship Store", "Mall Branch", "Outlet Store", "Pop-up Store", "Website", "Mobile App", "Lazada", "Shopee",
            "TikTok Shop", "Facebook Shop", "Instagram Shop", "Call Center", "Live Selling", "Corporate Sales", "Wholesale", "Distributor"]
CATEGORIES = ["Electronics", "Mobile Phones", "Computers", "Tablets", "Gaming", "Home Appliances", "Kitchen Appliances", "Furniture", "Home", "Office Supplies", "Apparel", "Footwear",
              "Fashion Accessories", "Beauty", "Personal Care", "Health", "Grocery", "Beverages", "Snacks", "Baby", "Pet Supplies", "Sports & Outdoors", "Automotive", "Toys & Games", "Books & Stationery"]
REGIONS = ["NCR", "CAR", "Region I", "Region II", "Region III", "Region IV-A", "Region IV-B", "Region V", "Region VI",
           "Region VII", "Region VIII", "Region IX", "Region X", "Region XI", "Region XII", "Region XIII", "BARMM"]


customer_schema = [
    {'label': '_row_number', 'key_label': 'row_number'},
    {'label': 'customer_id', 'key_label': 'lambda',
     'options': {'func': lambda row: f"A-CUST-{str(row['_row_number']).zfill(4)}"}},
    {'label': 'full_name', 'key_label': 'full_name'},
    {'label': 'email', 'key_label': 'email_address'},
    {'label': 'phone', 'key_label': 'phone', 'options': {'format': "09#########"}},
    {'label': 'region', 'key_label': 'custom_list',
     'options': {'values': REGIONS}},
    {'label': 'segment', 'key_label': 'custom_list',
     'options': {'values': ['VIP', 'Regular', 'New', 'At-Risk']}},
    {"label": "join_date", "key_label": "datetime", "options": {
        "from_date": '1/1/2022', "to_date": '06/01/2026', "date_format": "iso"
    }},
    {'label': 'is_active', 'key_label': 'lambda',
     'options': {'func': lambda: random.random() > 0.1}},
]

customer_payload = IkiDataGenerator(
    customer_schema).many(SUB_A_N_CUSTOMERS).data
customer_df = pd.DataFrame(customer_payload)
customer_df = customer_df.drop(columns=['_row_number'])
customer_df.to_csv(sales_customer_output_path, index=False)
print(f"SUB_A customers: {len(customer_df):,} rows")

sales_payload = []
for _, i in customer_df.iterrows():
    for _ in range(random.randint(1, 10)):
        sales_schema = [
            {'label': "order_id", "key_label": "uuid_v4"},
            {"label": "order_date", "key_label": "datetime", "options": {
                "from_date": '1/1/2022', "to_date": '06/01/2026', "date_format": "iso"
            }},
            {'label': 'customer_id', 'key_label': 'lambda',
             'options': {'func': lambda: i['customer_id']}},
            {'label': 'product_sku', 'key_label': 'character_sequence',
                'options': {'pattern': "A-SKU-%%%%-########"}},
            {'label': 'channel', 'key_label': 'custom_list',
             'options': {'values': CHANNELS}},
            {'label': 'category', 'key_label': 'custom_list',
             'options': {'values': CATEGORIES}},
            {'label': 'region', 'key_label': 'custom_list',
             'options': {'values': i['region']}},
            {"label": "qty", "key_label": "number", "options": {
                "min": 1, "max": 10
            }},
            {"label": "unit_price", "key_label": "number", "options": {
                "min": 100, "max": 5000, "decimals": 2
            }},
            {'label': 'discount_pct', 'key_label': 'custom_list',
             'options': {'values': [0, 0, 5, 10, 15, 20]}},
            {'label': 'net_sales', 'key_label': 'lambda',
             'options': {'func': lambda row: round(row["unit_price"] * row["qty"] * (1 - row["discount_pct"] / 100), 2)}},
            {'label': 'currency', 'key_label': 'lambda',
             'options': {'func': lambda: "PHP"}},
            {'label': 'updated_at', 'key_label': 'lambda',
             'options': {'func': lambda row: row['order_date']}},
        ]

        sales_payload.append(IkiDataGenerator(sales_schema).one())

sales_df = pd.DataFrame(sales_payload)
sales_df.to_csv(sales_transaction_output_path, index=False)
print(f"SUB_A sales: {len(sales_df):,} rows")
