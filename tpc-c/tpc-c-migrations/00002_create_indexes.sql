-- +goose Up
-- +goose StatementBegin

-- Indexes for Foreign Keys and Search Paths
CREATE INDEX idx_customer_w_d ON customer(c_w_id, c_d_id);
CREATE INDEX idx_customer_last ON customer(c_w_id, c_d_id, c_last);
CREATE INDEX idx_order_w_d_c ON orders(o_w_id, o_d_id, o_c_id);
CREATE INDEX idx_order_line_w_d_o ON order_line(ol_w_id, ol_d_id, ol_o_id);
CREATE INDEX idx_stock_w_i ON stock(s_w_id, s_i_id);
CREATE INDEX idx_new_order_w_d ON new_order(no_w_id, no_d_id, no_o_id);
CREATE INDEX idx_history_c ON history(h_c_w_id, h_c_d_id, h_c_id);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP INDEX IF EXISTS idx_customer_w_d;
DROP INDEX IF EXISTS idx_customer_last;
DROP INDEX IF EXISTS idx_order_w_d_c;
DROP INDEX IF EXISTS idx_order_line_w_d_o;
DROP INDEX IF EXISTS idx_stock_w_i;
DROP INDEX IF EXISTS idx_new_order_w_d;
DROP INDEX IF EXISTS idx_history_c;

-- +goose StatementEnd
