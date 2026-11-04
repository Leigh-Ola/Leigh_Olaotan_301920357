-- Fictional Harbour Office Supplies snapshot; all money is NGN.
-- Requires P1_Schema.sql and five empty tables. Never truncates or upserts.
-- Generated IDs are resolved through business keys, not assumed to start at 1.
-- This fixture load is not evidence of stock/payment workflow execution.
\set ON_ERROR_STOP on
\pset pager off
SET TIME ZONE 'UTC';
SELECT current_database() AS database, current_timestamp AS executed_at, version();

BEGIN;
LOCK TABLE public.customer, public.product, public.sales_order, public.order_item,
           public.payment IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM public.customer) OR EXISTS (SELECT 1 FROM public.product)
       OR EXISTS (SELECT 1 FROM public.sales_order) OR EXISTS (SELECT 1 FROM public.order_item)
       OR EXISTS (SELECT 1 FROM public.payment) THEN
        RAISE EXCEPTION 'Seed refused: all five portfolio tables must be empty';
    END IF;
END $$;

INSERT INTO public.customer (customer_code, full_name, email) VALUES
    ('C001', 'Ada Ojo', 'ada.ojo@example.com'),
    ('C002', 'Ben Eze', 'ben.eze@example.com'),
    ('C003', 'Chika Nwosu', 'chika.nwosu@example.com'),
    ('C004', 'Dami Bello', 'dami.bello@example.com'),
    ('C005', 'Efe Okoro', 'efe.okoro@example.com'),
    ('C006', 'Fola Adeyemi', 'fola.adeyemi@example.com');

-- Available balances after all placed orders; cancelled orders have net zero effect.
-- CAL01 was active when O1006 was placed, then deactivated (fixture assumption).
INSERT INTO public.product (sku, product_name, unit_price, stock_quantity, is_active) VALUES
    ('PEN01', 'Pen pack',       1000.00, 20, true),
    ('PAP01', 'Paper ream',     2500.00, 10, true),
    ('NTB01', 'Notebook',       1500.00, 12, true),
    ('STP01', 'Stapler',        3500.00,  5, true),
    ('ENV01', 'Envelope pack',  1200.00,  0, true),
    ('MRK01', 'Marker',         1800.00,  1, true),
    ('CAL01', 'Calculator',     8000.00,  3, false),
    ('FLD01', 'Folder',          500.00, 30, true);

INSERT INTO public.sales_order
    (order_number, customer_id, ordered_at, order_status, cancelled_at)
SELECT v.order_number, c.customer_id, v.ordered_at::timestamptz,
       v.order_status, v.cancelled_at::timestamptz
FROM (VALUES
    ('O1001','C001','2026-11-01T08:00:00Z','placed',    NULL),
    ('O1002','C002','2026-11-02T09:00:00Z','placed',    NULL),
    ('O1003','C003','2026-11-02T10:00:00Z','placed',    NULL),
    ('O1004','C001','2026-11-02T11:00:00Z','cancelled', '2026-11-03T08:00:00Z'),
    ('O1005','C004','2026-11-03T09:00:00Z','placed',    NULL),
    ('O1006','C005','2026-11-03T10:00:00Z','placed',    NULL),
    ('O1007','C002','2026-11-04T08:00:00Z','placed',    NULL),
    ('O1008','C003','2026-11-04T09:00:00Z','cancelled', '2026-11-04T10:00:00Z')
) AS v(order_number, customer_code, ordered_at, order_status, cancelled_at)
JOIN public.customer c USING (customer_code)
ORDER BY v.order_number;

INSERT INTO public.order_item (order_id, product_id, quantity, unit_price_at_order)
SELECT o.order_id, p.product_id, v.quantity, v.unit_price
FROM (VALUES
    ('O1001','PEN01',2, 900.00), -- Historical price differs from today's 1,000.
    ('O1001','PAP01',1,2500.00),
    ('O1002','PEN01',1,1000.00),
    ('O1003','NTB01',3,1500.00),
    ('O1003','STP01',1,3500.00),
    ('O1004','PAP01',2,2500.00),
    ('O1005','ENV01',2,1200.00),
    ('O1005','MRK01',1,1800.00),
    ('O1006','CAL01',1,8000.00),
    ('O1007','PAP01',1,2500.00),
    ('O1007','NTB01',2,1500.00),
    ('O1008','PEN01',1,1000.00),
    ('O1008','STP01',1,3500.00)
) AS v(order_number, sku, quantity, unit_price)
JOIN public.sales_order o USING (order_number)
JOIN public.product p USING (sku)
ORDER BY v.order_number, v.sku;

INSERT INTO public.payment (order_id, payment_reference, paid_at, amount)
SELECT o.order_id, v.reference, v.paid_at::timestamptz, v.amount
FROM (VALUES
    ('O1001','PAY5001','2026-11-01T08:10:00Z',4300.00),
    ('O1003','PAY5003','2026-11-02T10:05:00Z',8000.00),
    ('O1005','PAY5005','2026-11-03T09:05:00Z',4200.00),
    ('O1006','PAY5006','2026-11-03T10:05:00Z',8000.00)
) AS v(order_number, reference, paid_at, amount)
JOIN public.sales_order o USING (order_number)
ORDER BY v.reference;

-- Verify the fixture before committing, including relationships a row CHECK
-- cannot enforce. These assertions validate this dataset, not future writes.
DO $$ BEGIN
    IF (SELECT count(*) FROM public.customer) <> 6
       OR (SELECT count(*) FROM public.product) <> 8
       OR (SELECT count(*) FROM public.sales_order) <> 8
       OR (SELECT count(*) FROM public.order_item) <> 13
       OR (SELECT count(*) FROM public.payment) <> 4 THEN
        RAISE EXCEPTION 'Fixture row counts do not match 6/8/8/13/4';
    END IF;
    IF EXISTS (SELECT 1 FROM public.sales_order o WHERE NOT EXISTS
        (SELECT 1 FROM public.order_item i WHERE i.order_id = o.order_id)) THEN
        RAISE EXCEPTION 'Fixture contains an order without lines';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.payment p JOIN public.sales_order o USING (order_id)
        WHERE o.order_status <> 'placed' OR p.paid_at < o.ordered_at
           OR p.amount <> (SELECT sum(i.quantity * i.unit_price_at_order)
                          FROM public.order_item i WHERE i.order_id = o.order_id)
    ) THEN
        RAISE EXCEPTION 'Fixture payment eligibility, timing or total is invalid';
    END IF;
    IF EXISTS (
        SELECT 1 FROM (VALUES
            ('PEN01',23),('PAP01',12),('NTB01',17),('STP01',6),
            ('ENV01',2),('MRK01',2),('CAL01',4),('FLD01',30)
        ) AS opening(sku, quantity)
        JOIN public.product p USING (sku)
        WHERE p.stock_quantity <> opening.quantity - coalesce((
            SELECT sum(i.quantity) FROM public.order_item i
            JOIN public.sales_order o USING (order_id)
            WHERE i.product_id = p.product_id AND o.order_status = 'placed'
        ), 0)
    ) THEN
        RAISE EXCEPTION 'Fixture opening stock minus placed quantities does not reconcile';
    END IF;
    RAISE NOTICE 'PASS: 39 fixture rows; all orders have lines; payments reconcile; stock snapshot reconciles.';
END $$;
COMMIT;

\echo 'Fictional customers; example.com addresses are not real customer records.'
SELECT customer_code, full_name, email FROM public.customer ORDER BY customer_code;
\echo 'Catalogue and available stock snapshot.'
SELECT sku, product_name, unit_price, stock_quantity, is_active FROM public.product ORDER BY sku;
\echo 'Historical order lines, resolved through business identifiers.'
SELECT o.order_number, p.sku, i.quantity, i.unit_price_at_order,
       i.quantity * i.unit_price_at_order AS line_total
FROM public.order_item i JOIN public.sales_order o USING (order_id)
JOIN public.product p USING (product_id) ORDER BY o.order_number, p.sku;
\echo 'Order and payment reconciliation; totals are derived, not stored on the header.'
SELECT o.order_number, c.customer_code, o.ordered_at, o.order_status, o.cancelled_at,
       (SELECT sum(i.quantity * i.unit_price_at_order) FROM public.order_item i
        WHERE i.order_id = o.order_id) AS order_total,
       p.payment_reference, p.paid_at, p.amount AS payment_amount
FROM public.sales_order o JOIN public.customer c USING (customer_id)
LEFT JOIN public.payment p USING (order_id) ORDER BY o.order_number;
SELECT 'customer' AS table_name, count(*) AS rows FROM public.customer
UNION ALL SELECT 'product', count(*) FROM public.product
UNION ALL SELECT 'sales_order', count(*) FROM public.sales_order
UNION ALL SELECT 'order_item', count(*) FROM public.order_item
UNION ALL SELECT 'payment', count(*) FROM public.payment ORDER BY table_name;
