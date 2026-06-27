import random
import pandas as pd
from pathlib import Path
from datetime import datetime, timedelta
from ikidatagen import IkiDataGenerator

random.seed(42)

LOANS_N = 8000
PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"
OUTPUT_PATH = DATA_DIR / "sub_c/loan_accounts.csv"
LOAN_TYPES = ["Personal", "Home", "Auto", "Motorcycle", "Salary", "SME", "Business", "Commercial", "Agricultural", "Construction",
              "Education", "Medical", "Credit Line", "Bridge", "Microfinance", "Secured", "Unsecured", "Housing Improvement", "Appliance", "OFW"]
LOAN_STATUS = ["Current", "Current", "Current", "Current", "Grace Period", "30 DPD", "60 DPD", "90 DPD", "120+ DPD", "Restructured", "Refinanced",
               "Past Due", "Default", "Non-Performing Loan (NPL)", "Charged Off", "Written Off", "Under Collection", "Legal Action", "Foreclosed", "Closed", "Paid Off"]
BORROWERS = [f"C-BORR-{str(i).zfill(5)}" for i in range(1, 30001)]
TERM_MONTHS = {"Personal": 24, "Home": 240, "Auto": 60, "Motorcycle": 36, "Salary": 12, "SME": 36, "Business": 60, "Commercial": 120, "Agricultural": 48, "Construction": 180,
               "Education": 48, "Medical": 24, "Credit Line": 12, "Bridge": 18, "Microfinance": 12, "Secured": 60, "Unsecured": 36, "Housing Improvement": 120, "Appliance": 24, "OFW": 36}


schema = [
    {'label': 'loan_id', 'key_label': 'character_sequence',
     'options': {'pattern': "C-LOAN-####-########"}},
    {'label': 'borrower_id', 'key_label': 'custom_list',
     'options': {'values': BORROWERS}},
    {'label': 'loan_type', 'key_label': 'custom_list',
     'options': {'values': LOAN_TYPES}},
    {"label": "origination_date", "key_label": "datetime", "options": {
        "from_date": '1/1/2020', "to_date": '06/01/2026', "date_format": "iso"
    }},
    {'label': '_term_months', 'key_label': 'lambda',
     'options': {'func': lambda row: TERM_MONTHS[row['loan_type']]}},
    {'label': 'maturity_date', 'key_label': 'lambda',
     'options': {'func': lambda row: (datetime.fromisoformat(row['origination_date']) + timedelta(days=row['_term_months'] * 30)).isoformat()}},
    {'label': 'term_months', 'key_label': 'lambda',
     'options': {'func': lambda row: row['_term_months']}},
    {"label": "principal_amount", "key_label": "number", "options": {
        "min": 10000, "max": 5000000, "decimals": 2
    }},
    {"label": "interest_rate", "key_label": "number", "options": {
        "min": 4.5, "max": 24.0, "decimals": 2
    }},
    {'label': 'outstanding_balance', 'key_label': 'lambda',
     'options': {'func': lambda row: round(row['principal_amount'] * random.uniform(0.1, 1.0), 2)}},
    {'label': 'monthly_payment', 'key_label': 'lambda',
     'options': {'func': lambda row: round(row['principal_amount'] / row['term_months'] * (1 + row['interest_rate'] / 100 / 12), 2)}},
    {'label': 'loan_status', 'key_label': 'lambda',
     'options': {'func': lambda: random.choices(LOAN_STATUS, weights=[55, 55, 55, 55, 8, 6, 5, 4, 2, 3, 2, 3, 2, 1, 1, 1, 2, 1, 1, 10, 15])[0]}},
    {'label': 'days_past_due', 'key_label': 'custom_list',
     'options': {'values': [0, 0, 0, 0, 0, 30, 60, 90, 120]}},
    {'label': 'branch_id', 'key_label': 'lambda',
     'options': {'func': lambda: f"C-BR-{random.randint(1, 20):03d}"}},
    {'label': 'currency', 'key_label': 'lambda',
     'options': {'func': lambda: "PHP"}},
    {'label': 'last_updated', 'key_label': 'lambda',
     'options': {'func': lambda row: (datetime.fromisoformat(row['origination_date']) + timedelta(days=random.randint(0, 365))).isoformat()}},
]

payload = IkiDataGenerator(schema).many(LOANS_N).data
df = pd.DataFrame(payload)
df = df.drop(columns=['_term_months'])
df.to_csv(OUTPUT_PATH, index=False)
print(f"SUB_C loans: {len(df):,} rows")
