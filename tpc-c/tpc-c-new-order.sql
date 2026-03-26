-- TPC-C New-Order Transaction
-- Based on Clause 2.4.2 of TPC-C Specification v5.11.0

-- Generate random values for this transaction
\setrandom ol_cnt 5 15
\setrandom rbk 1 100
\setrandom c_id_nurand 1 3000
\setrandom d_id 1 10

-- Select warehouse tax rate
\set w_id :client_id
SELECT w_tax INTO :w_tax FROM warehouse WHERE w_id = :w_id;

-- Select and update district (get next orders ID)
SELECT d_tax, d_next_o_id INTO :d_tax, :o_id
FROM district
WHERE d_w_id = :w_id AND d_id = :d_id;

UPDATE district
SET d_next_o_id = d_next_o_id + 1
WHERE d_w_id = :w_id AND d_id = :d_id;

-- Select customer information
SELECT c_discount, c_last, c_credit
INTO :c_discount, :c_last, :c_credit
FROM customer
WHERE c_w_id = :w_id AND c_d_id = :d_id AND c_id = :c_id_nurand;

-- Insert new orders header
INSERT INTO orders (o_id, o_d_id, o_w_id, o_c_id, o_entry_d, o_carrier_id, o_ol_cnt, o_all_local)
VALUES (:o_id, :d_id, :w_id, :c_id_nurand, CURRENT_TIMESTAMP, NULL, :ol_cnt, 1);

-- Insert into new_order table
INSERT INTO new_order (no_o_id, no_d_id, no_w_id)
VALUES (:o_id, :d_id, :w_id);

-- Process each orders line (simplified for pgbench - single item)
\setrandom ol_i_id 1 100000
\setrandom ol_quantity 1 10
\set ol_supply_w_id :w_id

-- Select item price and info
SELECT i_price, i_name, i_data
INTO :i_price, :i_name, :i_data
FROM item
WHERE i_id = :ol_i_id;

-- Select and update stock
SELECT s_quantity, s_dist_01, s_data
INTO :s_quantity, :s_dist_info, :s_data
FROM stock
WHERE s_i_id = :ol_i_id AND s_w_id = :ol_supply_w_id;

-- Update stock quantity based on TPC-C rules
UPDATE stock
SET s_quantity = CASE
    WHEN s_quantity >= :ol_quantity + 10 THEN s_quantity - :ol_quantity
    ELSE s_quantity - :ol_quantity + 91
END,
s_ytd = s_ytd + :ol_quantity,
s_order_cnt = s_order_cnt + 1
WHERE s_i_id = :ol_i_id AND s_w_id = :ol_supply_w_id;

-- Calculate orders line amount
\set ol_amount :ol_quantity * :i_price

-- Insert orders line
INSERT INTO order_line (ol_o_id, ol_d_id, ol_w_id, ol_number, ol_i_id, ol_supply_w_id, ol_delivery_d, ol_quantity, ol_amount, ol_dist_info)
VALUES (:o_id, :d_id, :w_id, 1, :ol_i_id, :ol_supply_w_id, NULL, :ol_quantity, :ol_amount, :s_dist_info);

-- Transaction complete (pgbench auto-commits)
