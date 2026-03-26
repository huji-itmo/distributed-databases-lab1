#!/usr/bin/env python3
"""
TPC-C Database Seeding Script with Batching (Core API)
Based on TPC-C Specification v5.11.0, Clause 4.3
"""

import os
import random
import sys
from datetime import datetime
from decimal import Decimal
from typing import Any, Dict, List

from dotenv import load_dotenv
from faker import Faker
from sqlalchemy import MetaData, Table, create_engine, insert, text
from sqlalchemy.orm import sessionmaker
from tqdm import tqdm

# Configuration
WAREHOUSES = 1
DISTRICTS_PER_WAREHOUSE = 10
CUSTOMERS_PER_DISTRICT = 3000
ITEMS_COUNT = 100000
ORDERS_PER_DISTRICT = 3000
DELIVERED_ORDERS = 2100
NEW_ORDERS = 900

# Batching configuration
BATCH_SIZE = 2000
COMMIT_INTERVAL = 10000

load_dotenv()
DATABASE_URL = os.getenv("DB_DSN")
fake = Faker()

C_LAST_SYLLABLES = [
    "BAR",
    "OUGHT",
    "ABLE",
    "PRI",
    "PRES",
    "ESE",
    "ANTI",
    "CALLY",
    "ATION",
    "EING",
]


def generate_c_last(num: int) -> str:
    c1 = C_LAST_SYLLABLES[(num // 100) % 10]
    c2 = C_LAST_SYLLABLES[(num // 10) % 10]
    c3 = C_LAST_SYLLABLES[num % 10]
    return f"{c1}{c2}{c3}"


def generate_zip() -> str:
    n_string = str(random.randint(0, 9999)).zfill(4)
    return f"{n_string}11111"


def generate_original_data(field_type: str, max_length: int = 50) -> str:
    if random.randint(1, 100) <= 10:
        base = fake.text(max_nb_chars=max_length - 8)
        pos = random.randint(0, max(0, len(base) - 8))
        return base[:pos] + "ORIGINAL" + base[pos + 8 :][: max_length - 8]
    return fake.text(max_nb_chars=max_length)[:max_length]


def nurand(A: int, x: int, y: int, C: int) -> int:
    return (((random.randint(0, A) | random.randint(x, y)) + C) % (y - x + 1)) + x


class TPCCLoader:
    def __init__(self, database_url: str, warehouses: int = 1):
        self.engine = create_engine(database_url, pool_pre_ping=True)
        self.Session = sessionmaker(bind=self.engine)
        self.session = self.Session()
        self.warehouses = warehouses
        self.metadata = MetaData()
        self.metadata.reflect(bind=self.engine)

        self.tables = {
            "item": self.metadata.tables["item"],
            "warehouse": self.metadata.tables["warehouse"],
            "stock": self.metadata.tables["stock"],
            "district": self.metadata.tables["district"],
            "customer": self.metadata.tables["customer"],
            "history": self.metadata.tables["history"],
            "orders": self.metadata.tables["orders"],
            "order_line": self.metadata.tables["order_line"],
            "new_order": self.metadata.tables["new_order"],
        }

        self.C_LOAD_C_LAST = random.randint(0, 255)
        self.C_LOAD_C_ID = random.randint(0, 1023)
        self.C_LOAD_I_ID = random.randint(0, 8191)

        print(f"TPC-C Loader initialized with {warehouses} warehouse(s)")
        print(
            f"NURand C values: C_LAST={self.C_LOAD_C_LAST}, C_ID={self.C_LOAD_C_ID}, I_ID={self.C_LOAD_I_ID}"
        )

    def _bulk_insert_core(self, table: Table, records: List[Dict[str, Any]]):
        if not records:
            return
        stmt = insert(table)
        self.session.execute(stmt, records)

    def _flush_order_batches(
        self,
        order_batch,
        order_line_batch,
        new_order_batch,
        order_table,
        order_line_table,
        new_order_table,
        force_flush=False,
    ):
        """Flush order-related batches in dependency order: orders -> order_lines -> new_order"""
        # Always flush orders first to satisfy foreign key constraints
        if force_flush or len(order_batch) >= BATCH_SIZE // 3:
            if order_batch:
                self._bulk_insert_core(order_table, order_batch)
                order_batch.clear()

        # Then flush order_lines (now safe - parent orders are committed)
        if force_flush or len(order_line_batch) >= BATCH_SIZE * 5:
            if order_line_batch:
                self._bulk_insert_core(order_line_table, order_line_batch)
                order_line_batch.clear()

        # Finally flush new_order (depends on orders)
        if force_flush or len(new_order_batch) >= BATCH_SIZE // 3:
            if new_order_batch:
                self._bulk_insert_core(new_order_table, new_order_batch)
                new_order_batch.clear()

        return order_batch, order_line_batch, new_order_batch

    def load_items(self):
        """Load ITEM table with progress bar"""
        print("Loading ITEM table...")
        batch = []
        table = self.tables["item"]

        with tqdm(total=ITEMS_COUNT, desc="Items", unit="row", ncols=100) as pbar:
            for i_id in range(1, ITEMS_COUNT + 1):
                batch.append(
                    {
                        "i_id": i_id,
                        "i_im_id": random.randint(1, 10000),
                        "i_name": fake.text(max_nb_chars=24)[:24],
                        "i_price": round(random.uniform(1.00, 100.00), 2),
                        "i_data": generate_original_data("item", 50),
                    }
                )

                if len(batch) >= BATCH_SIZE:
                    self._bulk_insert_core(table, batch)
                    batch.clear()
                    if i_id % COMMIT_INTERVAL == 0:
                        self.session.commit()

                pbar.update(1)
                if i_id % COMMIT_INTERVAL == 0:
                    pbar.set_postfix({"committed": f"{i_id}/{ITEMS_COUNT}"})

        if batch:
            self._bulk_insert_core(table, batch)
        self.session.commit()
        print(f"ITEM table loaded: {ITEMS_COUNT} rows")

    def load_warehouse(self, w_id: int):
        """Load warehouse with nested progress bars"""
        print(f"\n{'=' * 60}")
        print(f"Loading Warehouse {w_id}/{self.warehouses}...")
        print(f"{'=' * 60}")

        # WAREHOUSE (single row)
        self.session.execute(
            insert(self.tables["warehouse"]),
            [
                {
                    "w_id": w_id,
                    "w_name": fake.text(max_nb_chars=10)[:10],
                    "w_street_1": fake.text(max_nb_chars=20)[:20],
                    "w_street_2": fake.text(max_nb_chars=20)[:20],
                    "w_city": fake.text(max_nb_chars=20)[:20],
                    "w_state": fake.state_abbr(),
                    "w_zip": generate_zip(),
                    "w_tax": round(random.uniform(0.0000, 0.2000), 4),
                    "w_ytd": Decimal("300000.00"),
                }
            ],
        )

        # STOCK with progress bar
        print(f"  Loading STOCK ({ITEMS_COUNT:,} items)...")
        stock_batch = []
        stock_table = self.tables["stock"]

        with tqdm(
            total=ITEMS_COUNT, desc="  Stock", unit="row", ncols=80, leave=False
        ) as pbar:
            for s_i_id in range(1, ITEMS_COUNT + 1):
                s_dist = [fake.text(max_nb_chars=24)[:24] for _ in range(10)]
                stock_batch.append(
                    {
                        "s_i_id": s_i_id,
                        "s_w_id": w_id,
                        "s_quantity": random.randint(10, 100),
                        "s_dist_01": s_dist[0],
                        "s_dist_02": s_dist[1],
                        "s_dist_03": s_dist[2],
                        "s_dist_04": s_dist[3],
                        "s_dist_05": s_dist[4],
                        "s_dist_06": s_dist[5],
                        "s_dist_07": s_dist[6],
                        "s_dist_08": s_dist[7],
                        "s_dist_09": s_dist[8],
                        "s_dist_10": s_dist[9],
                        "s_ytd": 0,
                        "s_order_cnt": 0,
                        "s_remote_cnt": 0,
                        "s_data": generate_original_data("stock", 50),
                    }
                )

                if len(stock_batch) >= BATCH_SIZE:
                    self._bulk_insert_core(stock_table, stock_batch)
                    stock_batch.clear()
                    if s_i_id % COMMIT_INTERVAL == 0:
                        self.session.commit()
                pbar.update(1)

        if stock_batch:
            self._bulk_insert_core(stock_table, stock_batch)

        # Districts with progress bar
        print(f"  Loading {DISTRICTS_PER_WAREHOUSE} districts...")
        with tqdm(
            total=DISTRICTS_PER_WAREHOUSE, desc="  Districts", unit="district", ncols=80
        ) as dpbar:
            for d_id in range(1, DISTRICTS_PER_WAREHOUSE + 1):
                self.load_district(w_id, d_id)
                dpbar.update(1)

        self.session.commit()
        print(f"Warehouse {w_id} completed")

    def load_district(self, w_id: int, d_id: int):
        """Load district with batched data and progress bars"""
        # DISTRICT (single row)
        self.session.execute(
            insert(self.tables["district"]),
            [
                {
                    "d_id": d_id,
                    "d_w_id": w_id,
                    "d_name": fake.text(max_nb_chars=10)[:10],
                    "d_street_1": fake.text(max_nb_chars=20)[:20],
                    "d_street_2": fake.text(max_nb_chars=20)[:20],
                    "d_city": fake.text(max_nb_chars=20)[:20],
                    "d_state": fake.state_abbr(),
                    "d_zip": generate_zip(),
                    "d_tax": round(random.uniform(0.0000, 0.2000), 4),
                    "d_ytd": Decimal("30000.00"),
                    "d_next_o_id": 3001,
                }
            ],
        )

        # CUSTOMER + HISTORY with progress bar
        customer_batch, history_batch = [], []
        customer_table = self.tables["customer"]
        history_table = self.tables["history"]

        with tqdm(
            total=CUSTOMERS_PER_DISTRICT,
            desc=f"    Customers D{d_id}",
            unit="cust",
            ncols=70,
            leave=False,
        ) as pbar:
            for c_id in range(1, CUSTOMERS_PER_DISTRICT + 1):
                c_last_num = (
                    c_id - 1
                    if c_id <= 1000
                    else nurand(255, 0, 999, self.C_LOAD_C_LAST)
                )

                customer_batch.append(
                    {
                        "c_id": c_id,
                        "c_d_id": d_id,
                        "c_w_id": w_id,
                        "c_first": fake.first_name()[:16],
                        "c_middle": "OE",
                        "c_last": generate_c_last(c_last_num),
                        "c_street_1": fake.text(max_nb_chars=20)[:20],
                        "c_street_2": fake.text(max_nb_chars=20)[:20],
                        "c_city": fake.text(max_nb_chars=20)[:20],
                        "c_state": fake.state_abbr(),
                        "c_zip": generate_zip(),
                        "c_phone": "".join(
                            [str(random.randint(0, 9)) for _ in range(16)]
                        ),
                        "c_since": datetime.now(),
                        "c_credit": "BC" if random.randint(1, 100) <= 10 else "GC",
                        "c_credit_lim": Decimal("50000.00"),
                        "c_discount": round(random.uniform(0.0000, 0.5000), 4),
                        "c_balance": Decimal("-10.00"),
                        "c_ytd_payment": Decimal("10.00"),
                        "c_payment_cnt": 1,
                        "c_delivery_cnt": 0,
                        "c_data": fake.text(max_nb_chars=500)[:500],
                    }
                )

                history_batch.append(
                    {
                        "h_c_id": c_id,
                        "h_c_d_id": d_id,
                        "h_c_w_id": w_id,
                        "h_d_id": d_id,
                        "h_w_id": w_id,
                        "h_date": datetime.now(),
                        "h_amount": Decimal("10.00"),
                        "h_data": fake.text(max_nb_chars=24)[:24],
                    }
                )

                if len(customer_batch) >= BATCH_SIZE:
                    self._bulk_insert_core(customer_table, customer_batch)
                    customer_batch.clear()
                if len(history_batch) >= BATCH_SIZE:
                    self._bulk_insert_core(history_table, history_batch)
                    history_batch.clear()
                if c_id % COMMIT_INTERVAL == 0:
                    self.session.commit()
                pbar.update(1)

        if customer_batch:
            self._bulk_insert_core(customer_table, customer_batch)
        if history_batch:
            self._bulk_insert_core(history_table, history_batch)

        # ORDERS with progress bar - FIXED: dependency-aware batching
        order_batch, order_line_batch, new_order_batch = [], [], []
        order_table = self.tables["orders"]
        order_line_table = self.tables["order_line"]
        new_order_table = self.tables["new_order"]

        with tqdm(
            total=ORDERS_PER_DISTRICT,
            desc=f"    Orders D{d_id}",
            unit="order",
            ncols=70,
            leave=False,
        ) as pbar:
            for o_id in range(1, ORDERS_PER_DISTRICT + 1):
                o_c_id = random.randint(1, CUSTOMERS_PER_DISTRICT)
                o_entry_d = datetime.now()
                o_ol_cnt = random.randint(5, 15)
                is_delivered = o_id <= DELIVERED_ORDERS
                o_carrier_id = random.randint(1, 10) if is_delivered else None
                ol_delivery_d = o_entry_d if is_delivered else None

                order_batch.append(
                    {
                        "o_id": o_id,
                        "o_d_id": d_id,
                        "o_w_id": w_id,
                        "o_c_id": o_c_id,
                        "o_entry_d": o_entry_d,
                        "o_carrier_id": o_carrier_id,
                        "o_ol_cnt": o_ol_cnt,
                        "o_all_local": 1,
                    }
                )

                for ol_number in range(1, o_ol_cnt + 1):
                    order_line_batch.append(
                        {
                            "ol_o_id": o_id,
                            "ol_d_id": d_id,
                            "ol_w_id": w_id,
                            "ol_number": ol_number,
                            "ol_i_id": random.randint(1, ITEMS_COUNT),
                            "ol_supply_w_id": w_id,
                            "ol_delivery_d": ol_delivery_d,
                            "ol_quantity": 5,
                            "ol_amount": Decimal("0.00")
                            if is_delivered
                            else round(Decimal(random.uniform(0.01, 9999.99)), 2),
                            "ol_dist_info": fake.text(max_nb_chars=24)[:24],
                        }
                    )

                if not is_delivered:
                    new_order_batch.append(
                        {"no_o_id": o_id, "no_d_id": d_id, "no_w_id": w_id}
                    )

                # FIXED: Flush in dependency order to satisfy foreign keys
                order_batch, order_line_batch, new_order_batch = (
                    self._flush_order_batches(
                        order_batch,
                        order_line_batch,
                        new_order_batch,
                        order_table,
                        order_line_table,
                        new_order_table,
                    )
                )

                if o_id % 500 == 0:
                    self.session.commit()
                pbar.update(1)

        # Final flush with force=True to ensure all batches are written in order
        self._flush_order_batches(
            order_batch,
            order_line_batch,
            new_order_batch,
            order_table,
            order_line_table,
            new_order_table,
            force_flush=True,
        )
        self.session.commit()

    def load_all(self):
        print("\n" + "=" * 60)
        print("TPC-C Database Seeding Started (Core API Batching)")
        print("=" * 60)
        start_time = datetime.now()

        self.load_items()

        with tqdm(
            total=self.warehouses, desc="Warehouses", unit="wh", ncols=100
        ) as wh_pbar:
            for w_id in range(1, self.warehouses + 1):
                self.load_warehouse(w_id)
                wh_pbar.update(1)

        duration = datetime.now() - start_time
        print("\n" + "=" * 60)
        print("TPC-C Database Seeding Completed!")
        print(f"  Duration: {duration}")
        print(f"  Warehouses: {self.warehouses}")
        print(f"  Total Items: {ITEMS_COUNT:,}")
        print(
            f"  Total Customers: {self.warehouses * DISTRICTS_PER_WAREHOUSE * CUSTOMERS_PER_DISTRICT:,}"
        )
        print(
            f"  Total Orders: {self.warehouses * DISTRICTS_PER_WAREHOUSE * ORDERS_PER_DISTRICT:,}"
        )
        print("=" * 60)

    def verify_consistency(self):
        """Verify TPC-C consistency conditions"""
        print("\nVerifying database consistency...")
        result = self.session.execute(
            text("""
            SELECT w_id, w_ytd,
                   (SELECT SUM(d_ytd) FROM district WHERE d_w_id = w.w_id) as sum_d_ytd
            FROM warehouse w
        """)
        ).fetchall()
        for row in result:
            status = "OK" if row[1] == row[2] else "FAILED"
            symbol = "[+]" if row[1] == row[2] else "[!]"
            print(f"{symbol} Condition 1 {status} for warehouse {row[0]}")

        result = self.session.execute(
            text("""
            SELECT d_id, d_w_id, d_next_o_id - 1 as expected_max,
                   (SELECT MAX(o_id) FROM "orders" WHERE o_d_id = d.d_id AND o_w_id = d.d_w_id) as actual_max
            FROM district d
        """)
        ).fetchall()
        for row in result:
            status = "OK" if row[2] == row[3] else "FAILED"
            symbol = "[+]" if row[2] == row[3] else "[!]"
            print(f"{symbol} Condition 2 {status} for district {row[0]}")

        result = self.session.execute(
            text(
                "SELECT no_w_id, no_d_id, COUNT(*) FROM new_order GROUP BY no_w_id, no_d_id"
            )
        ).fetchall()
        for row in result:
            status = "OK" if row[2] == NEW_ORDERS else "INCORRECT"
            symbol = "[+]" if row[2] == NEW_ORDERS else "[!]"
            print(f"{symbol} NEW-ORDER count {status} for W{row[0]}D{row[1]}")

    def close(self):
        self.session.close()
        self.engine.dispose()


if __name__ == "__main__":
    if DATABASE_URL is None:
        print("Error: DB_DSN not set. Run: source .env")
        sys.exit(1)

    warehouses = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    loader = TPCCLoader(DATABASE_URL, warehouses)

    try:
        loader.load_all()
        loader.verify_consistency()
    except Exception as e:
        print(f"Error: {e}")
        loader.session.rollback()
        raise
    finally:
        loader.close()
