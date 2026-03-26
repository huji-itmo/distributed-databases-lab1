-- +goose Up
-- +goose StatementBegin

-- ITEM Table (Fixed cardinality 100k, independent of warehouses)
CREATE TABLE item (
    i_id        INTEGER NOT NULL,
    i_im_id     INTEGER,
    i_name      VARCHAR(24),
    i_price     NUMERIC(5, 2),
    i_data      VARCHAR(50),
    PRIMARY KEY (i_id)
);

-- WAREHOUSE Table
CREATE TABLE warehouse (
    w_id        INTEGER NOT NULL,
    w_name      VARCHAR(10),
    w_street_1  VARCHAR(20),
    w_street_2  VARCHAR(20),
    w_city      VARCHAR(20),
    w_state     CHAR(2),
    w_zip       CHAR(9),
    w_tax       NUMERIC(4, 4),
    w_ytd       NUMERIC(12, 2),
    PRIMARY KEY (w_id)
);

-- DISTRICT Table
CREATE TABLE district (
    d_id        INTEGER NOT NULL,
    d_w_id      INTEGER NOT NULL,
    d_name      VARCHAR(10),
    d_street_1  VARCHAR(20),
    d_street_2  VARCHAR(20),
    d_city      VARCHAR(20),
    d_state     CHAR(2),
    d_zip       CHAR(9),
    d_tax       NUMERIC(4, 4),
    d_ytd       NUMERIC(12, 2),
    d_next_o_id INTEGER,
    PRIMARY KEY (d_w_id, d_id),
    FOREIGN KEY (d_w_id) REFERENCES warehouse(w_id)
);

-- CUSTOMER Table
CREATE TABLE customer (
    c_id        INTEGER NOT NULL,
    c_d_id      INTEGER NOT NULL,
    c_w_id      INTEGER NOT NULL,
    c_first     VARCHAR(16),
    c_middle    CHAR(2),
    c_last      VARCHAR(16),
    c_street_1  VARCHAR(20),
    c_street_2  VARCHAR(20),
    c_city      VARCHAR(20),
    c_state     CHAR(2),
    c_zip       CHAR(9),
    c_phone     CHAR(16),
    c_since     TIMESTAMP,
    c_credit    CHAR(2),
    c_credit_lim NUMERIC(12, 2),
    c_discount  NUMERIC(4, 4),
    c_balance   NUMERIC(12, 2),
    c_ytd_payment NUMERIC(12, 2),
    c_payment_cnt INTEGER,
    c_delivery_cnt INTEGER,
    c_data      TEXT,
    PRIMARY KEY (c_w_id, c_d_id, c_id),
    FOREIGN KEY (c_w_id, c_d_id) REFERENCES district(d_w_id, d_id)
);

-- HISTORY Table (No Primary Key as per Spec 1.3)
CREATE TABLE history (
    h_c_id      INTEGER,
    h_c_d_id    INTEGER,
    h_c_w_id    INTEGER,
    h_d_id      INTEGER,
    h_w_id      INTEGER,
    h_date      TIMESTAMP,
    h_amount    NUMERIC(6, 2),
    h_data      VARCHAR(24),
    FOREIGN KEY (h_c_w_id, h_c_d_id, h_c_id) REFERENCES customer(c_w_id, c_d_id, c_id),
    FOREIGN KEY (h_w_id, h_d_id) REFERENCES district(d_w_id, d_id)
);

-- ORDERS Table
CREATE TABLE orders (
    o_id        INTEGER NOT NULL,
    o_d_id      INTEGER NOT NULL,
    o_w_id      INTEGER NOT NULL,
    o_c_id      INTEGER,
    o_entry_d   TIMESTAMP,
    o_carrier_id INTEGER,
    o_ol_cnt    INTEGER,
    o_all_local INTEGER,
    PRIMARY KEY (o_w_id, o_d_id, o_id),
    FOREIGN KEY (o_w_id, o_d_id, o_c_id) REFERENCES customer(c_w_id, c_d_id, c_id)
);

-- NEW-ORDER Table
CREATE TABLE new_order (
    no_o_id     INTEGER NOT NULL,
    no_d_id     INTEGER NOT NULL,
    no_w_id     INTEGER NOT NULL,
    PRIMARY KEY (no_w_id, no_d_id, no_o_id),
    FOREIGN KEY (no_w_id, no_d_id, no_o_id) REFERENCES orders (o_w_id, o_d_id, o_id)
);

-- STOCK Table
CREATE TABLE stock (
    s_i_id      INTEGER NOT NULL,
    s_w_id      INTEGER NOT NULL,
    s_quantity  INTEGER,
    s_dist_01   CHAR(24),
    s_dist_02   CHAR(24),
    s_dist_03   CHAR(24),
    s_dist_04   CHAR(24),
    s_dist_05   CHAR(24),
    s_dist_06   CHAR(24),
    s_dist_07   CHAR(24),
    s_dist_08   CHAR(24),
    s_dist_09   CHAR(24),
    s_dist_10   CHAR(24),
    s_ytd       INTEGER,
    s_order_cnt INTEGER,
    s_remote_cnt INTEGER,
    s_data      VARCHAR(50),
    PRIMARY KEY (s_w_id, s_i_id),
    FOREIGN KEY (s_w_id) REFERENCES warehouse(w_id),
    FOREIGN KEY (s_i_id) REFERENCES item(i_id)
);

-- ORDER-LINE Table
CREATE TABLE order_line (
    ol_o_id     INTEGER NOT NULL,
    ol_d_id     INTEGER NOT NULL,
    ol_w_id     INTEGER NOT NULL,
    ol_number   INTEGER NOT NULL,
    ol_i_id     INTEGER,
    ol_supply_w_id INTEGER,
    ol_delivery_d TIMESTAMP,
    ol_quantity INTEGER,
    ol_amount   NUMERIC(6, 2),
    ol_dist_info CHAR(24),
    PRIMARY KEY (ol_w_id, ol_d_id, ol_o_id, ol_number),
    FOREIGN KEY (ol_w_id, ol_d_id, ol_o_id) REFERENCES orders(o_w_id, o_d_id, o_id),
    FOREIGN KEY (ol_supply_w_id, ol_i_id) REFERENCES stock(s_w_id, s_i_id)
);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP TABLE IF EXISTS history CASCADE;
DROP TABLE IF EXISTS order_line CASCADE;
DROP TABLE IF EXISTS new_order CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS customer CASCADE;
DROP TABLE IF EXISTS stock CASCADE;
DROP TABLE IF EXISTS district CASCADE;
DROP TABLE IF EXISTS warehouse CASCADE;
DROP TABLE IF EXISTS item CASCADE;

-- +goose StatementEnd
