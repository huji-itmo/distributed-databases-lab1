#!/usr/bin/env python3
import os
import sys

from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv()
DATABASE_URL = os.getenv("DB_DSN")

if DATABASE_URL is None:
    print("Error: DB_DSN not set")
    sys.exit(1)

# Add connect_args to increase timeout if necessary (example for PostgreSQL)
engine = create_engine(
    DATABASE_URL, execution_options={"isolation_level": "AUTOCOMMIT"}
)

TABLES = [
    "order_line",
    "new_order",
    "orders",
    "history",
    "customer",
    "stock",
    "district",
    "warehouse",
    "item",
]

with engine.connect() as conn:
    for table in TABLES:
        print(f"Truncating {table}...")
        conn.execute(text(f"TRUNCATE TABLE {table} RESTART IDENTITY CASCADE"))

print("All entries truncated")
