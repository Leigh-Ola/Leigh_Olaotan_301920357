-- Deterministic synthetic snapshot; run after P1_Schema.sql in a separate empty
-- database such as mit8103_benchmark. Never run against the P1 fixture.
\set ON_ERROR_STOP on
\pset pager off
SET TIME ZONE 'UTC';

SELECT
    current_database(),
    current_timestamp,
    version();

BEGIN;
LOCK TABLE public.customer,
public.product,
public.sales_order,
public.order_item,
public.payment IN SHARE ROW EXCLUSIVE MODE;
DO $$
BEGIN
    IF current_database() = 'mit8103_portfolio' THEN
        RAISE EXCEPTION 'Refusing P1 database';
    END IF;
    IF EXISTS (
        SELECT
            1
        FROM
            public.customer)
        OR EXISTS (
            SELECT
                1
            FROM
                public.product)
        OR EXISTS (
            SELECT
                1
            FROM
                public.sales_order)
        OR EXISTS (
            SELECT
                1
            FROM
                public.order_item)
        OR EXISTS (
            SELECT
                1
            FROM
                public.payment) THEN
        RAISE EXCEPTION 'Benchmark requires empty tables';
END IF;
END
$$;
INSERT INTO public.customer (customer_code, full_name, email)
SELECT
    'BC' || lpad(g::text, 5, '0'),
    'Fictional customer ' || g,
    'bench.' || g || '@example.com'
FROM
    generate_series(1, 10000) g
    ORDER BY
        g;
INSERT INTO public.product (sku, product_name, unit_price, stock_quantity)
SELECT
    'BP' || lpad(g::text, 3, '0'),
    'Synthetic product ' || g,
    100 + 10 * g,
    1000000
FROM
    generate_series(1, 100) g
    ORDER BY
        g;
INSERT INTO public.sales_order (order_number, customer_id, ordered_at, order_status, cancelled_at)
SELECT
    'BO' || lpad(g::text, 6, '0'),
    c.customer_id,
    TIMESTAMPTZ '2024-01-01T00:00:00Z' + (g - 1) * interval '1 minute',
    CASE WHEN g % 10 = 0 THEN
        'cancelled'
    ELSE
        'placed'
    END,
    CASE WHEN g % 10 = 0 THEN
        TIMESTAMPTZ '2024-01-01T00:00:00Z' + (g - 1) * interval '1 minute' + interval '1 day'
    END
FROM
    generate_series(1, 300000) g
        JOIN public.customer c ON c.customer_code = 'BC' || lpad(((g - 1) % 10000 + 1)::text, 5, '0')
    ORDER BY
        g;
INSERT INTO public.order_item (order_id, product_id, quantity, unit_price_at_order)
SELECT
    o.order_id,
    p.product_id,
    v.quantity,
    p.unit_price
FROM
    public.sales_order o
    CROSS JOIN (
        VALUES (0, 1),
            (37, 2)) v (offset_value, quantity)
    JOIN public.product p ON p.sku = 'BP' || lpad(((substring(o.order_number FROM 3)::integer - 1 + v.offset_value) % 100 + 1)::text, 3, '0');
INSERT INTO public.payment (order_id, payment_reference, paid_at, amount)
SELECT
    o.order_id,
    'BPay' || substring(o.order_number FROM 3),
    o.ordered_at + interval '5 minutes',
    sum(i.quantity * i.unit_price_at_order)
FROM
    public.sales_order o
    JOIN public.order_item i USING (order_id)
WHERE
    o.order_status = 'placed'
    AND substring(o.order_number FROM 3)::integer % 2 = 0
GROUP BY
    o.order_id;
DO $$
BEGIN
    IF (
        SELECT
            count(*)
        FROM
            public.customer) <> 10000 OR (
    SELECT
        count(*)
    FROM
        public.product) <> 100 OR (
    SELECT
        count(*)
    FROM
        public.sales_order) <> 300000 OR (
    SELECT
        count(*)
    FROM
        public.order_item) <> 600000 OR (
    SELECT
        count(*)
    FROM
        public.payment) <> 120000 THEN
        RAISE EXCEPTION 'Benchmark count mismatch';
    END IF;
    IF EXISTS (
        SELECT
            1
        FROM
            public.sales_order o
        LEFT JOIN public.order_item i USING (order_id)
    GROUP BY
        o.order_id
    HAVING
        count(i.product_id) <> 2) THEN
RAISE EXCEPTION 'Expected two lines per order';
END IF;
END
$$;
COMMIT;
-- Both phases use these same statistics and visibility map; no data changes later.
VACUUM (ANALYZE) public.customer;
VACUUM (ANALYZE) public.product;
VACUUM (ANALYZE) public.sales_order;
VACUUM (ANALYZE) public.order_item;
VACUUM (ANALYZE) public.payment;
SELECT
    'customer' AS table_name,
    count(*)
FROM
    public.customer
UNION ALL
SELECT
    'product',
    count(*)
FROM
    public.product
UNION ALL
SELECT
    'sales_order',
    count(*)
FROM
    public.sales_order
UNION ALL
SELECT
    'order_item',
    count(*)
FROM
    public.order_item
UNION ALL
SELECT
    'payment',
    count(*)
FROM
    public.payment;
SELECT
    order_status,
    count(*)
FROM
    public.sales_order
GROUP BY
    order_status
ORDER BY
    order_status;
