-- TPC-C New-Order Transaction (Simplified)
-- Compatible with all pgbench versions

\set ol_cnt random(5, 15)
\set c_id_nurand random(1, 3000)
\set d_id random(1, 10)
\set w_id :client_id
\set ol_i_id random(1, 100000)
\set ol_quantity random(1, 10)

-- \begin

-- Get and update district next_o_id in one statement
UPDATE district
SET d_next_o_id = d_next_o_id + 1
WHERE d_w_id = :w_id AND d_id = :d_id;

-- Insert order (use a subquery for o_id)
INSERT INTO orders (o_id, o_d_id, o_w_id, o_c_id, o_entry_d, o_ol_cnt, o_all_local)
SELECT d_next_o_id - 1, :d_id, :w_id, :c_id_nurand, CURRENT_TIMESTAMP, :ol_cnt, 1
FROM district
WHERE d_w_id = :w_id AND d_id = :d_id;

-- Insert into new_order
INSERT INTO new_order (no_o_id, no_d_id, no_w_id)
SELECT o_id, :d_id, :w_id
FROM orders
WHERE o_w_id = :w_id AND o_d_id = :d_id
ORDER BY o_id DESC
LIMIT 1;

-- Insert order_line (simplified - no item/stock lookup)
INSERT INTO order_line (ol_o_id, ol_d_id, ol_w_id, ol_number, ol_i_id, ol_supply_w_id, ol_quantity, ol_amount, ol_dist_info)
SELECT o_id, :d_id, :w_id, 1, :ol_i_id, :w_id, :ol_quantity, :ol_quantity * 10.00, 'dist_info'
FROM orders
WHERE o_w_id = :w_id AND o_d_id = :d_id
ORDER BY o_id DESC
LIMIT 1;

-- Update stock (simplified)
UPDATE stock
SET s_quantity = CASE
    WHEN s_quantity >= :ol_quantity + 10 THEN s_quantity - :ol_quantity
    ELSE s_quantity - :ol_quantity + 91
END
WHERE s_i_id = :ol_i_id AND s_w_id = :w_id;

-- \end
