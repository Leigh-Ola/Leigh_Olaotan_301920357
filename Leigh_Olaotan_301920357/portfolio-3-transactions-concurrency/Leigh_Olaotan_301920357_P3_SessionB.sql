-- MANUAL GUIDE: interleave blocks with Session A as documented. Keep this
-- connection open. Expected P3002/P3005/P3004 errors are followed by ROLLBACK.
-- Do not run the whole file sequentially. For manual psql use ON_ERROR_STOP off
-- during the expected error, then ROLLBACK; the runner verifies each SQLSTATE.
-- BLOCK STOCK_B_BEGIN
BEGIN ISOLATION LEVEL READ COMMITTED;
SET LOCAL ROLE mit8103_p3_app;
SELECT
    json_build_object('isolation', current_setting('transaction_isolation'), 'stock', (
            SELECT
                stock_quantity
            FROM public.product
            WHERE
                sku = 'MRK01'), 'visible_a_orders', (
            SELECT
                count(*)
            FROM public.sales_order
            WHERE
                order_number = 'CC-STOCK-A'));
-- END STOCK_B_BEGIN
-- BLOCK STOCK_B_ATTEMPT
SELECT
    shop_api.place_order ('CC-STOCK-B', 'C002', ARRAY['MRK01'], ARRAY[1], TIMESTAMPTZ '2026-11-07T08:00:00Z');
-- END STOCK_B_ATTEMPT
-- WAIT: A commits. Then expect P3002.
-- BLOCK B_ROLLBACK
ROLLBACK;

-- END B_ROLLBACK
-- BLOCK PAY_B_BEGIN
BEGIN ISOLATION LEVEL READ COMMITTED;
SET LOCAL ROLE mit8103_p3_app;
-- END PAY_B_BEGIN
-- BLOCK PAY_B_ATTEMPT
SELECT
    shop_api.cancel_order ('CC-PAY-FIRST', TIMESTAMPTZ '2026-11-07T08:02:00Z');
-- END PAY_B_ATTEMPT
-- WAIT: A commits payment. Expect P3005, then B_ROLLBACK.
-- BLOCK CANCEL_B_BEGIN
BEGIN ISOLATION LEVEL READ COMMITTED;
SET LOCAL ROLE mit8103_p3_app;
-- END CANCEL_B_BEGIN
-- BLOCK CANCEL_B_ATTEMPT
SELECT
    shop_api.record_payment ('CC-CANCEL-FIRST', 'CC-PAY-2', 500, TIMESTAMPTZ '2026-11-07T08:02:00Z');
-- END CANCEL_B_ATTEMPT
-- WAIT: A commits cancellation. Expect P3004, then B_ROLLBACK.
-- BLOCK VIS_B_BEGIN
BEGIN ISOLATION LEVEL READ COMMITTED;
SET LOCAL ROLE mit8103_p3_app;
-- END VIS_B_BEGIN
-- BLOCK VIS_B_READ
SELECT
    json_build_object('isolation', current_setting('transaction_isolation'), 'transaction_id', txid_current(), 'stock', (
        SELECT
            stock_quantity
        FROM public.product
        WHERE
            sku = 'PEN01'), 'visible_a_orders', (
        SELECT
            count(*)
        FROM public.sales_order
        WHERE
            order_number = 'CC-VISIBILITY'));
-- END VIS_B_READ
-- Repeat this read before A's write, before A's COMMIT and after A's COMMIT,
-- without ending B's transaction. READ COMMITTED gets a new statement snapshot.
-- BLOCK VIS_B_COMMIT
COMMIT;

-- END VIS_B_COMMIT
