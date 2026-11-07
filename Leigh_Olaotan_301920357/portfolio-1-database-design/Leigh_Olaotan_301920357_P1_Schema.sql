-- Harbour Office Supplies: PostgreSQL 17 relational schema.
-- Olaotan Leigh | 301920357 | MIT 8103, Portfolio 1.
-- Run against a fresh, explicitly selected practice database with psql.
-- No DROP or automatic reset: existing tables cause an atomic failure.
\set ON_ERROR_STOP on
\pset pager off
SET TIME ZONE 'UTC';

SELECT
    current_database() AS database,
    current_user AS executed_by,
    current_timestamp AS executed_at,
    version();

BEGIN;
CREATE TABLE public.customer (
    customer_id BIGINT GENERATED ALWAYS AS IDENTITY,
    customer_code VARCHAR(20) NOT NULL,
    full_name VARCHAR(120) NOT NULL,
    email VARCHAR(254) NOT NULL,
    CONSTRAINT pk_customer PRIMARY KEY (customer_id),
    CONSTRAINT uq_customer_code UNIQUE (customer_code),
    CONSTRAINT uq_customer_email UNIQUE (email),
    CONSTRAINT ck_customer_code_nonblank CHECK (customer_code ~ '[^[:space:]]'),
    CONSTRAINT ck_customer_name_nonblank CHECK (full_name ~ '[^[:space:]]'),
    CONSTRAINT ck_customer_email_normalised CHECK (email ~ '[^[:space:]]' AND email = lower(btrim(email)) AND email !~ '[[:space:]]')
);
CREATE TABLE public.product (
    product_id BIGINT GENERATED ALWAYS AS IDENTITY,
    sku VARCHAR(30) NOT NULL,
    product_name VARCHAR(160) NOT NULL,
    unit_price NUMERIC(12, 2) NOT NULL,
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT pk_product PRIMARY KEY (product_id),
    CONSTRAINT uq_product_sku UNIQUE (sku),
    CONSTRAINT ck_product_sku_nonblank CHECK (sku ~ '[^[:space:]]'),
    CONSTRAINT ck_product_name_nonblank CHECK (product_name ~ '[^[:space:]]'),
    CONSTRAINT ck_product_price_positive CHECK (unit_price > 0 AND unit_price <> 'NaN'::numeric),
    CONSTRAINT ck_product_stock_nonnegative CHECK (stock_quantity >= 0)
);
CREATE TABLE public.sales_order (
    order_id BIGINT GENERATED ALWAYS AS IDENTITY,
    order_number VARCHAR(30) NOT NULL,
    customer_id BIGINT NOT NULL,
    ordered_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    order_status VARCHAR(10) NOT NULL DEFAULT 'placed',
    cancelled_at TIMESTAMPTZ,
    CONSTRAINT pk_sales_order PRIMARY KEY (order_id),
    CONSTRAINT uq_sales_order_number UNIQUE (order_number),
    CONSTRAINT fk_sales_order_customer FOREIGN KEY (customer_id) REFERENCES public.customer (customer_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_sales_order_number_nonblank CHECK (order_number ~ '[^[:space:]]'),
    CONSTRAINT ck_sales_order_status CHECK (order_status IN ('placed', 'cancelled')),
    CONSTRAINT ck_sales_order_time_finite CHECK (isfinite(ordered_at)),
    CONSTRAINT ck_sales_order_cancellation CHECK ((order_status <> 'placed' OR cancelled_at IS NULL) AND (order_status <> 'cancelled' OR (cancelled_at IS NOT NULL AND isfinite(cancelled_at) AND cancelled_at >= ordered_at)))
);
CREATE TABLE public.order_item (
    order_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price_at_order NUMERIC(12, 2) NOT NULL,
    CONSTRAINT pk_order_item PRIMARY KEY (order_id, product_id),
    CONSTRAINT fk_order_item_order FOREIGN KEY (order_id) REFERENCES public.sales_order (order_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_order_item_product FOREIGN KEY (product_id) REFERENCES public.product (product_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_order_item_quantity_positive CHECK (quantity > 0),
    CONSTRAINT ck_order_item_price_positive CHECK (unit_price_at_order > 0 AND unit_price_at_order <> 'NaN'::numeric)
);
CREATE TABLE public.payment (
    payment_id BIGINT GENERATED ALWAYS AS IDENTITY,
    order_id BIGINT NOT NULL,
    payment_reference VARCHAR(40) NOT NULL,
    paid_at TIMESTAMPTZ NOT NULL,
    amount NUMERIC(14, 2) NOT NULL,
    CONSTRAINT pk_payment PRIMARY KEY (payment_id),
    CONSTRAINT uq_payment_order UNIQUE (order_id),
    CONSTRAINT uq_payment_reference UNIQUE (payment_reference),
    CONSTRAINT fk_payment_order FOREIGN KEY (order_id) REFERENCES public.sales_order (order_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_payment_reference_nonblank CHECK (payment_reference ~ '[^[:space:]]'),
    CONSTRAINT ck_payment_time_finite CHECK (isfinite(paid_at)),
    CONSTRAINT ck_payment_amount_positive CHECK (amount > 0 AND amount <> 'NaN'::numeric)
);
COMMIT;
\echo 'Schema catalogue: compare these 25 attributes with the design dictionary.'
SELECT
    c.relname AS table_name,
    a.attnum AS position,
    a.attname AS column_name,
    format_type(a.atttypid, a.atttypmod) AS data_type,
    a.attnotnull AS required,
    a.attidentity AS identity_kind,
    pg_get_expr(d.adbin, d.adrelid) AS default_expression
FROM
    pg_attribute a
    JOIN pg_class c ON c.oid = a.attrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid
        AND d.adnum = a.attnum
WHERE
    n.nspname = 'public'
    AND c.relname IN ('customer', 'product', 'sales_order', 'order_item', 'payment')
    AND a.attnum > 0
    AND NOT a.attisdropped
ORDER BY
    c.relname,
    a.attnum;
\echo 'Named constraints: p=primary, u=unique, f=foreign, c=check.'
SELECT
    c.relname AS table_name,
    con.conname AS constraint_name,
    con.contype AS kind,
    pg_get_constraintdef(con.oid) AS definition
FROM
    pg_constraint con
    JOIN pg_class c ON c.oid = con.conrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE
    n.nspname = 'public'
    AND c.relname IN ('customer', 'product', 'sales_order', 'order_item', 'payment')
ORDER BY
    c.relname,
    con.contype,
    con.conname;
\echo 'Initial indexes: only those supporting the primary and unique keys.'
SELECT
    tablename,
    indexname,
    indexdef
FROM
    pg_indexes
WHERE
    schemaname = 'public'
    AND tablename IN ('customer', 'product', 'sales_order', 'order_item', 'payment')
ORDER BY
    tablename,
    indexname;
