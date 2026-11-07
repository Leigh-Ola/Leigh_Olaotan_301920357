-- Harbour Office Supplies: six business questions on the P1 seed fixture.
\set ON_ERROR_STOP on
\pset pager off
SET TIME ZONE 'UTC';

BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
SELECT
    current_database() AS database,
    current_timestamp AS executed_at,
    version();
\echo 'Q1: What are the current placed orders, their historical totals and payment states?'
-- QUERY Q1
SELECT
    o.order_number,
    c.customer_code,
    count(*) AS line_count,
    sum(i.quantity * i.unit_price_at_order) AS order_total,
    CASE WHEN p.payment_id IS NULL THEN
        'unpaid'
    ELSE
        'paid'
    END AS payment_state
FROM
    public.sales_order o
    JOIN public.customer c USING (customer_id)
    JOIN public.order_item i USING (order_id)
    LEFT JOIN public.payment p USING (order_id)
WHERE
    o.order_status = 'placed'
GROUP BY
    o.order_id,
    o.order_number,
    c.customer_code,
    p.payment_id
ORDER BY
    o.order_number;

-- END Q1
\echo 'Q2: Which products generated the most paid sales, using agreed historical prices?'
-- QUERY Q2
SELECT
    p.sku,
    sum(i.quantity) AS units_sold,
    sum(i.quantity * i.unit_price_at_order) AS paid_sales
FROM
    public.product p
    JOIN public.order_item i USING (product_id)
    JOIN public.sales_order o USING (order_id)
    JOIN public.payment pay USING (order_id)
WHERE
    o.order_status = 'placed'
GROUP BY
    p.product_id,
    p.sku
ORDER BY
    paid_sales DESC,
    p.sku;

-- END Q2
\echo 'Q3: Which placed orders still await payment?'
-- QUERY Q3
SELECT
    o.order_number,
    c.customer_code,
    sum(i.quantity * i.unit_price_at_order) AS outstanding_amount
FROM
    public.sales_order o
    JOIN public.customer c USING (customer_id)
    JOIN public.order_item i USING (order_id)
WHERE
    o.order_status = 'placed'
    AND NOT EXISTS (
        SELECT
            1
        FROM
            public.payment p
        WHERE
            p.order_id = o.order_id)
GROUP BY
    o.order_id,
    o.order_number,
    c.customer_code
ORDER BY
    outstanding_amount DESC,
    o.order_number;

-- END Q3
\echo 'Q4: How many orders and how much settled value belong to each customer, including customers without orders?'
-- QUERY Q4
WITH order_totals AS (
    SELECT
        order_id,
        sum(quantity * unit_price_at_order) AS total
    FROM
        public.order_item
    GROUP BY
        order_id
)
SELECT
    c.customer_code,
    count(o.order_id) AS all_orders,
    count(o.order_id) FILTER (WHERE o.order_status = 'cancelled') AS cancelled_orders,
    count(p.payment_id) AS paid_orders,
    coalesce(sum(t.total) FILTER (WHERE p.payment_id IS NOT NULL), 0) AS settled_value
FROM
    public.customer c
    LEFT JOIN public.sales_order o USING (customer_id)
    LEFT JOIN order_totals t USING (order_id)
    LEFT JOIN public.payment p USING (order_id)
GROUP BY
    c.customer_id,
    c.customer_code
ORDER BY
    c.customer_code;

-- END Q4
\echo 'Q5: Which active products are at or below the five-unit reorder threshold?'
-- QUERY Q5
SELECT
    sku,
    stock_quantity,
    unit_price
FROM
    public.product
WHERE
    is_active
    AND stock_quantity <= 5
ORDER BY
    stock_quantity,
    sku;

-- END Q5
\echo 'Q6: Which catalogue products have never appeared on any order, including cancelled orders?'
-- QUERY Q6
SELECT
    p.sku,
    p.product_name
FROM
    public.product p
WHERE
    NOT EXISTS (
        SELECT
            1
        FROM
            public.order_item i
        WHERE
            i.product_id = p.product_id)
ORDER BY
    p.sku;

-- END Q6
COMMIT;
