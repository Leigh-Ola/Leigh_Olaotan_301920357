-- MANUAL GUIDE: use a fresh step-10 database and TWO terminals, not this entire
-- file in one execution. The Python runner executes these same labelled blocks.
-- Connect with psql -X -U mit8103_admin -d mit8103_transactions inside the container.
-- Use the README's A/B interleaving. Keep the connection open between blocks.

-- BLOCK STOCK_A_BEGIN
BEGIN ISOLATION LEVEL READ COMMITTED;
SET LOCAL ROLE mit8103_p3_app;
SELECT shop_api.place_order('CC-STOCK-A','C001',ARRAY['MRK01'],ARRAY[1],TIMESTAMPTZ '2026-11-07T08:00:00Z');
-- END STOCK_A_BEGIN
-- STOP: B reads the old committed stock, then attempts STOCK_B_ATTEMPT and waits.

-- BLOCK STOCK_A_COMMIT
COMMIT;
-- END STOCK_A_COMMIT
-- B now rejects with P3002 and must ROLLBACK.

-- BLOCK PAY_PREPARE
SET ROLE mit8103_p3_app;
SELECT shop_api.place_order('CC-PAY-FIRST','C001',ARRAY['FLD01'],ARRAY[1],TIMESTAMPTZ '2026-11-07T08:00:00Z');
RESET ROLE;
-- END PAY_PREPARE
-- BLOCK PAY_A_BEGIN
BEGIN ISOLATION LEVEL READ COMMITTED;
SET LOCAL ROLE mit8103_p3_app;
SELECT shop_api.record_payment('CC-PAY-FIRST','CC-PAY-1',500,TIMESTAMPTZ '2026-11-07T08:01:00Z');
-- END PAY_A_BEGIN
-- STOP: B tries cancellation and waits on this order lock.
-- BLOCK PAY_A_COMMIT
COMMIT;
-- END PAY_A_COMMIT

-- BLOCK CANCEL_PREPARE
SET ROLE mit8103_p3_app;
SELECT shop_api.place_order('CC-CANCEL-FIRST','C001',ARRAY['FLD01'],ARRAY[1],TIMESTAMPTZ '2026-11-07T08:00:00Z');
RESET ROLE;
-- END CANCEL_PREPARE
-- BLOCK CANCEL_A_BEGIN
BEGIN ISOLATION LEVEL READ COMMITTED;
SET LOCAL ROLE mit8103_p3_app;
SELECT shop_api.cancel_order('CC-CANCEL-FIRST',TIMESTAMPTZ '2026-11-07T08:01:00Z');
-- END CANCEL_A_BEGIN
-- STOP: B tries payment and waits on this order lock.
-- BLOCK CANCEL_A_COMMIT
COMMIT;
-- END CANCEL_A_COMMIT

-- For the next example run VIS_B_BEGIN first, then this block.
-- BLOCK VIS_A_BEGIN
BEGIN ISOLATION LEVEL READ COMMITTED;
SET LOCAL ROLE mit8103_p3_app;
SELECT shop_api.place_order('CC-VISIBILITY','C001',ARRAY['PEN01'],ARRAY[1],TIMESTAMPTZ '2026-11-07T08:00:00Z');
-- END VIS_A_BEGIN
-- STOP: B repeats VIS_B_READ and must still see its old committed stock.
-- BLOCK VIS_A_COMMIT
COMMIT;
-- END VIS_A_COMMIT
-- B repeats VIS_B_READ in the SAME transaction and now sees the committed change.
