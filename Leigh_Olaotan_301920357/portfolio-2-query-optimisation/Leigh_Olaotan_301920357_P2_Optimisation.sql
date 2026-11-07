-- Apply only AFTER preserving and committing the unindexed baseline.
\set ON_ERROR_STOP on
\pset pager off
SELECT
    current_database(),
    current_timestamp,
    version();

BEGIN;
DO $$
BEGIN
    IF current_database() = 'mit8103_portfolio' THEN
        RAISE EXCEPTION 'Refusing P1 database';
    END IF;
    IF (
        SELECT
            count(*)
        FROM
            public.sales_order) <> 300000 THEN
        RAISE EXCEPTION 'Unexpected benchmark fixture';
    END IF;
END
$$;
CREATE INDEX idx_sales_order_customer_history ON public.sales_order (customer_id, ordered_at DESC, order_id DESC);
COMMIT;
SELECT
    indexname,
    indexdef
FROM
    pg_indexes
WHERE
    indexname = 'idx_sales_order_customer_history';
SELECT
    pg_relation_size('public.idx_sales_order_customer_history') AS index_bytes,
    pg_size_pretty(pg_relation_size('public.idx_sales_order_customer_history')) AS index_size;
