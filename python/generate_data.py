import random
from datetime import date, timedelta
from pathlib import Path
import csv

random.seed(42)

OUT_DIR = Path("data")
OUT_DIR.mkdir(parents=True, exist_ok=True)

N_CUSTOMERS = 500
N_PRODUCTS = 120
N_ORDERS = 2500

COUNTRIES = ["Mexico", "USA", "Canada", "Colombia", "Spain", "Argentina", "Chile", "Peru"]
CATEGORIES = ["Electronics", "Home", "Beauty", "Sports", "Fashion", "Books", "Toys"]
PAY_METHODS = ["card", "paypal", "bank_transfer", "cash_on_delivery"]
ORDER_STATUS = ["completed", "completed", "completed", "cancelled", "refunded"]  # sesgo realista

FIRST_NAMES = ["Ana", "Luis", "Carlos", "Maria", "Sofia", "Juan", "Valeria", "Miguel", "Laura", "Diego"]
LAST_NAMES = ["Garcia", "Hernandez", "Lopez", "Martinez", "Gonzalez", "Perez", "Sanchez", "Ramirez", "Torres", "Flores"]

PRODUCT_WORDS = ["Pro", "Max", "Mini", "Plus", "Air", "Smart", "Ultra", "Eco", "Lite", "Prime"]

def rand_date(start: date, end: date) -> date:
    delta = (end - start).days
    return start + timedelta(days=random.randint(0, delta))

start_date = date(2023, 1, 1)
end_date = date(2025, 12, 1)

# ---------- customers ----------
customers = []
for cid in range(1, N_CUSTOMERS + 1):
    fn = random.choice(FIRST_NAMES)
    ln = random.choice(LAST_NAMES)
    name = f"{fn} {ln}"
    email = f"{fn.lower()}.{ln.lower()}{cid}@example.com"
    country = random.choice(COUNTRIES)
    signup = rand_date(date(2022, 1, 1), end_date)
    customers.append([cid, name, email, country, signup.isoformat()])

# ---------- products ----------
products = []
for pid in range(1, N_PRODUCTS + 1):
    category = random.choice(CATEGORIES)
    base = random.choice(["Headphones", "Blender", "Cream", "Sneakers", "Jersey", "Notebook", "Drone", "Lamp", "Backpack", "Watch"])
    suffix = random.choice(PRODUCT_WORDS)
    pname = f"{base} {suffix} {pid}"
    # precio realista por categoría
    if category == "Electronics":
        price = round(random.uniform(25, 850), 2)
    elif category in ("Fashion", "Sports"):
        price = round(random.uniform(10, 220), 2)
    elif category in ("Home", "Beauty"):
        price = round(random.uniform(5, 180), 2)
    else:
        price = round(random.uniform(3, 60), 2)
    products.append([pid, pname, category, price])

# ---------- orders + order_items + payments ----------
orders = []
order_items = []
payments = []

order_id = 1
order_item_id = 1
payment_id = 1

for _ in range(N_ORDERS):
    customer_id = random.randint(1, N_CUSTOMERS)
    odate = rand_date(start_date, end_date)
    status = random.choice(ORDER_STATUS)

    orders.append([order_id, customer_id, odate.isoformat(), status])

    # items: 1-5 productos por orden
    n_items = random.randint(1, 5)
    chosen_products = random.sample(range(1, N_PRODUCTS + 1), n_items)

    total_amount = 0.0
    for pid in chosen_products:
        qty = random.randint(1, 4)
        price = products[pid - 1][3]
        total_amount += float(price) * qty
        order_items.append([order_item_id, order_id, pid, qty])
        order_item_id += 1

    # pagos: si completed, se paga; si cancelled/refunded, puede haber 0 o pago con ajuste
    if status == "completed":
        pdate = odate + timedelta(days=random.randint(0, 3))
        method = random.choice(PAY_METHODS)
        payments.append([payment_id, order_id, pdate.isoformat(), round(total_amount, 2), method])
        payment_id += 1
    elif status == "refunded":
        # pago y luego devolución parcial/total (simplificado: pago negativo como ajuste)
        pdate = odate + timedelta(days=random.randint(0, 2))
        method = random.choice(PAY_METHODS)
        payments.append([payment_id, order_id, pdate.isoformat(), round(total_amount, 2), method])
        payment_id += 1
        rdate = pdate + timedelta(days=random.randint(3, 20))
        payments.append([payment_id, order_id, rdate.isoformat(), round(-total_amount, 2), "refund"])
        payment_id += 1

    order_id += 1

# ---------- write CSV ----------
def write_csv(path: Path, header, rows):
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)

write_csv(OUT_DIR / "customers.csv", ["customer_id", "full_name", "email", "country", "signup_date"], customers)
write_csv(OUT_DIR / "products.csv", ["product_id", "product_name", "category", "price"], products)
write_csv(OUT_DIR / "orders.csv", ["order_id", "customer_id", "order_date", "status"], orders)
write_csv(OUT_DIR / "order_items.csv", ["order_item_id", "order_id", "product_id", "quantity"], order_items)
write_csv(OUT_DIR / "payments.csv", ["payment_id", "order_id", "payment_date", "amount", "payment_method"], payments)

print("✅ CSV generados en /data:")
for p in ["customers.csv", "products.csv", "orders.csv", "order_items.csv", "payments.csv"]:
    print(" -", OUT_DIR / p)
