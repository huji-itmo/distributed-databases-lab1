# TPC-C New-Order Transaction Explained

## Overview

TPC-C is a benchmark that simulates a wholesale parts ordering system. It models a company with multiple warehouses, each serving multiple districts, each district has customers, and orders are placed for items in stock.

The **New-Order** transaction is the most common and important transaction in TPC-C - it represents placing a new order for parts.

## Database Schema

### Core Tables

1. **ITEM** (100,000 rows)
   - The catalog of salable parts
   - Independent of warehouses (same items sold at all warehouses)
   - Fields: `i_id` (ID), `i_im_id` (image ID), `i_name`, `i_price`, `i_data` (description)

2. **WAREHOUSE** (1-10 rows)
   - Physical locations that fulfill orders
   - Fields: `w_id`, `w_name`, `w_street`, `w_city`, `w_state`, `w_zip`, `w_tax`, `w_ytd` (year-to-date balance)

3. **DISTRICT** (10 per warehouse)
   - Sub-divisions of a warehouse
   - Fields: `d_id`, `d_w_id` (warehouse ref), `d_name`, `d_address`, `d_tax`, `d_ytd`, `d_next_o_id` (next order ID)

4. **CUSTOMER** (3,000 per district = 30,000 per warehouse)
   - Fields: `c_id`, `c_d_id`, `c_w_id`, `c_name`, `c_address`, `c_phone`, `c_credit` (BC or GC), `c_balance`, `c_discount`

5. **ORDERS** (varies per district)
   - Fields: `o_id`, `o_d_id`, `o_w_id`, `o_c_id` (customer), `o_entry_d`, `o_carrier_id`, `o_ol_cnt` (order line count), `o_all_local`

6. **NEW_ORDER** (varies per district)
   - Contains orders that haven't been delivered yet
   - Fields: `no_o_id`, `no_d_id`, `no_w_id`
   - Used to track pending orders for delivery

7. **ORDER_LINE** (varies per order, ~10 lines per order)
   - Individual line items in an order
   - Fields: `ol_o_id`, `ol_d_id`, `ol_w_id`, `ol_number`, `ol_i_id` (item), `ol_supply_w_id`, `ol_quantity`, `ol_amount`, `ol_delivery_d`

8. **STOCK** (100,000 items per warehouse)
   - Inventory levels for each item at each warehouse
   - Fields: `s_i_id`, `s_w_id`, `s_quantity`, `s_dist_01` through `s_dist_10`, `s_ytd`, `s_order_cnt`, `s_remote_cnt`, `s_data`

9. **HISTORY** (1 per payment)
   - Transaction history
   - Fields: `h_c_id`, `h_c_d_id`, `h_c_w_id`, `h_d_id`, `h_w_id`, `h_date`, `h_amount`, `h_data`

## The New-Order Transaction

This is what the benchmark is actually running. Here's what happens:

### Inputs (Randomly Generated)
- `w_id`: Random warehouse (1)
- `d_id`: Random district (1-10)
- `c_id`: Random customer (standard: 1-3000)
- `o_id`: Next order ID for district
- `ol_cnt`: Number of order lines (5-15)

### Step-by-Step Operations

1. **Get District Info**
   ```sql
   SELECT d_next_o_id, d_tax FROM district WHERE d_w_id = :w_id AND d_id = :d_id
   ```
   - Gets the next order number and district tax rate
   - Must increment next order ID

2. **Update District**
   ```sql
   UPDATE district SET d_next_o_id = :new_order_id WHERE d_w_id = :w_id AND d_id = :d_id
   ```
   - Atomically increment the next order ID

3. **Create Order Record**
   ```sql
   INSERT INTO orders (o_id, o_d_id, o_w_id, o_c_id, o_entry_d, o_ol_cnt, o_all_local)
   VALUES (:o_id, :d_id, :w_id, :c_id, NOW(), :ol_cnt, 1)
   ```
   - Insert the new order

4. **Create New-Order Record**
   ```sql
   INSERT INTO new_order (no_o_id, no_d_id, no_w_id)
   VALUES (:o_id, :d_id, :w_id)
   ```
   - Track that this order is pending delivery

5. **For Each Order Line (5-15 items)**
   
   a. **Get Item Info**
   ```sql
   SELECT i_price, i_name, i_data FROM item WHERE i_id = :ol_i_id
   ```
   
   b. **Get Stock Info**
   ```sql
   SELECT s_quantity, s_data, s_dist_xx FROM stock WHERE s_i_id = :ol_i_id AND s_w_id = :ol_w_id
   ```
   - `xx` is the district number (01-10)
   
   c. **Update Stock**
   ```sql
   UPDATE stock SET s_quantity = :new_qty, s_ytd = s_ytd + :ol_quantity,
                    s_order_cnt = s_order_cnt + 1
   WHERE s_i_id = :ol_i_id AND s_w_id = :ol_w_id
   ```
   - Decrement stock, track statistics

   d. **Calculate Amount**
   - `ol_amount = ol_quantity * i_price * (1 + w_tax + d_tax) * (1 - c_discount)`

   e. **Insert Order Line**
   ```sql
   INSERT INTO order_line (ol_o_id, ol_d_id, ol_w_id, ol_number, ol_i_id, ol_supply_w_id,
                          ol_quantity, ol_amount, ol_dist_info)
   VALUES (:o_id, :d_id, :w_id, :ol_number, :ol_i_id, :ol_w_id,
           :ol_quantity, :ol_amount, :s_dist_xx)
   ```

### Return
- Success: Order ID, number of order lines, total amount
- The transaction commits atomically

## Why This Benchmark Matters

1. **Write-Heavy**: Most operations are updates (stock decrement, district update)
2. **Transactional**: Must maintain ACID properties across multiple tables
3. **Hot Spots**: Current district and stock are frequently accessed
4. **Realistic**: Models real-world OLTP workload

## Key Performance Considerations

1. **Indexes**: Foreign key indexes on (d_w_id, d_id), (c_w_id, c_d_id, c_id), (s_w_id, s_i_id), (o_w_id, o_d_id, o_id)

2. **Foreign Keys**: Enforce referential integrity (validated but can slow inserts)

3. **Sequential ID Generation**: d_next_o_id must be atomic - causes contention

4. **Stock Updates**: Each order line updates stock - high contention on popular items

## Tuning for New-Order

- **shared_buffers**: Cache district and stock data
- **fsync=off**: Skip WAL fsync (unsafe but faster)
- **synchronous_commit=off**: Don't wait for WAL write
- **commit_delay**: Batch multiple commits
- **Effective connection count**: 48 clients optimal on this system
