-- Run once after P1 schema/seed and P3_Workflows.sql in the transaction database.
-- Real COMMIT/ROLLBACK demonstrations plus rollback-only enforcement checks.
\set ON_ERROR_STOP on
\pset pager off
SET TIME ZONE 'UTC';
SELECT current_database(),current_timestamp,version();
DO $$ BEGIN
 IF current_database() IN ('mit8103_portfolio','mit8103_benchmark')
 OR EXISTS(SELECT 1 FROM public.sales_order WHERE order_number LIKE 'TX-%' OR order_number LIKE 'CC-%') THEN
  RAISE EXCEPTION 'Use a fresh, separately seeded transaction database';
 END IF;
END $$;
CREATE FUNCTION pg_temp.row_snapshot() RETURNS jsonb LANGUAGE SQL AS $$
 SELECT jsonb_build_object(
 'customer',(SELECT jsonb_agg(to_jsonb(t) ORDER BY customer_id) FROM public.customer t),
 'product',(SELECT jsonb_agg(to_jsonb(t) ORDER BY product_id) FROM public.product t),
 'orders',(SELECT jsonb_agg(to_jsonb(t) ORDER BY order_id) FROM public.sales_order t),
 'lines',(SELECT jsonb_agg(to_jsonb(t) ORDER BY order_id,product_id) FROM public.order_item t),
 'payments',(SELECT jsonb_agg(to_jsonb(t) ORDER BY payment_id) FROM public.payment t));
$$;
\echo 'Starting available stock'
SELECT sku,stock_quantity FROM public.product WHERE sku IN ('PEN01','PAP01','NTB01') ORDER BY sku;

\echo '1. COMMIT: two-line order and both stock deductions persist together.'
BEGIN ISOLATION LEVEL READ COMMITTED;
SET LOCAL ROLE mit8103_p3_app;
SELECT current_user AS operation_role;
SELECT shop_api.place_order('TX-COMMIT','C006',ARRAY['PEN01','PAP01'],ARRAY[2,1],TIMESTAMPTZ '2026-11-07T08:00:00Z');
COMMIT;
DO $$ BEGIN
 IF (SELECT stock_quantity FROM public.product WHERE sku='PEN01')<>18
 OR (SELECT stock_quantity FROM public.product WHERE sku='PAP01')<>9
 OR (SELECT count(*) FROM public.order_item WHERE order_id=(SELECT order_id FROM public.sales_order WHERE order_number='TX-COMMIT'))<>2
 THEN RAISE EXCEPTION 'Committed order/stock check failed'; END IF;
END $$;
SELECT o.order_number,count(*) AS lines,sum(i.quantity*i.unit_price_at_order) AS total
FROM public.sales_order o JOIN public.order_item i USING(order_id) WHERE o.order_number='TX-COMMIT' GROUP BY o.order_number;
CREATE TEMP TABLE saved_state AS SELECT pg_temp.row_snapshot() AS rows;

\echo '2. ROLLBACK: an earlier successful order plus part of a second order must both disappear.'
BEGIN ISOLATION LEVEL READ COMMITTED;
SET LOCAL ROLE mit8103_p3_app;
SELECT shop_api.place_order('TX-ROLLBACK','C006',ARRAY['PEN01'],ARRAY[1],TIMESTAMPTZ '2026-11-07T08:01:00Z');
-- PEN01 is processed before ENV01. The second operation fails after its header,
-- first line and pen deduction; the containing transaction is then rolled back.
\set ON_ERROR_STOP off
SELECT shop_api.place_order('TX-FAIL','C006',ARRAY['PEN01','ENV01'],ARRAY[1,1],TIMESTAMPTZ '2026-11-07T08:02:00Z');
\set failed_sqlstate :SQLSTATE
\set ON_ERROR_STOP on
ROLLBACK;
SELECT :'failed_sqlstate'='P3002' AS expected_failure \gset
\if :expected_failure
\echo 'PASS: observed expected insufficient-stock SQLSTATE' :failed_sqlstate
\else
\echo 'FAIL: unexpected failure state' :failed_sqlstate
\quit 1
\endif
DO $$ BEGIN
 IF pg_temp.row_snapshot() IS DISTINCT FROM (SELECT rows FROM saved_state) THEN
  RAISE EXCEPTION 'Rollback did not restore all five tables';
 END IF;
END $$;
SELECT count(*) AS failed_transaction_orders FROM public.sales_order WHERE order_number IN ('TX-ROLLBACK','TX-FAIL');
SELECT sku,stock_quantity FROM public.product WHERE sku IN ('PEN01','PAP01','ENV01') ORDER BY sku;

\echo '3. COMMIT a full payment for the successful order.'
BEGIN;
SET LOCAL ROLE mit8103_p3_app;
SELECT shop_api.record_payment('TX-COMMIT','TX-PAY',4500,TIMESTAMPTZ '2026-11-07T08:03:00Z');
COMMIT;
SELECT o.order_number,p.payment_reference,p.amount FROM public.payment p JOIN public.sales_order o USING(order_id)
WHERE o.order_number='TX-COMMIT';

\echo '4. Cancel an unpaid order and restore its two notebook units exactly once.'
BEGIN;
SET LOCAL ROLE mit8103_p3_app;
SELECT shop_api.place_order('TX-CANCEL','C006',ARRAY['NTB01'],ARRAY[2],TIMESTAMPTZ '2026-11-07T08:04:00Z');
COMMIT;
SELECT sku,stock_quantity FROM public.product WHERE sku='NTB01';
BEGIN;
SET LOCAL ROLE mit8103_p3_app;
SELECT shop_api.cancel_order('TX-CANCEL',TIMESTAMPTZ '2026-11-07T08:05:00Z') AS first_cancellation \gset
COMMIT;
BEGIN;
SET LOCAL ROLE mit8103_p3_app;
SELECT shop_api.cancel_order('TX-CANCEL',TIMESTAMPTZ '2026-11-07T08:06:00Z') AS repeated_cancellation \gset
COMMIT;
SELECT :'first_cancellation'::boolean AS first_cancellation,:'repeated_cancellation'::boolean AS repeated_cancellation;
DO $$ BEGIN
 IF (SELECT stock_quantity FROM public.product WHERE sku='NTB01')<>12
 OR NOT EXISTS(SELECT 1 FROM public.sales_order WHERE order_number='TX-CANCEL'
  AND order_status='cancelled' AND cancelled_at=TIMESTAMPTZ '2026-11-07T08:05:00Z')
 OR (SELECT count(*) FROM public.order_item WHERE order_id=(SELECT order_id FROM public.sales_order WHERE order_number='TX-CANCEL'))<>1 THEN
  RAISE EXCEPTION 'Cancellation/retry changed stock or history incorrectly';
 END IF;
END $$;
SELECT sku,stock_quantity FROM public.product WHERE sku='NTB01';

\echo '5. A catalogue price change does not reprice existing lines (probe rolled back).'
BEGIN;
UPDATE public.product SET unit_price=9999 WHERE sku='PEN01';
SELECT o.order_number,i.unit_price_at_order FROM public.order_item i JOIN public.sales_order o USING(order_id)
JOIN public.product p USING(product_id) WHERE p.sku='PEN01' AND o.order_number IN ('O1001','TX-COMMIT') ORDER BY o.order_number;
DO $$ BEGIN
 IF (SELECT i.unit_price_at_order FROM public.order_item i JOIN public.sales_order o USING(order_id)
 JOIN public.product p USING(product_id) WHERE o.order_number='TX-COMMIT' AND p.sku='PEN01')<>1000 THEN
  RAISE EXCEPTION 'Historical price changed with catalogue price';
 END IF;
END $$;
ROLLBACK;

\echo '6. Workflow/permission rejections under the restricted practice role.'
BEGIN;
LOCK TABLE public.customer,public.product,public.sales_order,public.order_item,public.payment IN SHARE ROW EXCLUSIVE MODE;
UPDATE saved_state SET rows=pg_temp.row_snapshot();
CREATE TEMP TABLE checks(test_name text PRIMARY KEY,sqlstate text,constraint_name text,message text);
GRANT SELECT,INSERT ON checks TO mit8103_p3_app;
CREATE FUNCTION pg_temp.reject(label text,statement text,expected text,expected_constraint text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE code text; con text; msg text;
BEGIN
 BEGIN
  EXECUTE statement;
  RAISE EXCEPTION USING ERRCODE='PZ001',MESSAGE='Unexpected acceptance: '||label;
 EXCEPTION WHEN OTHERS THEN
  GET STACKED DIAGNOSTICS code=RETURNED_SQLSTATE,con=CONSTRAINT_NAME,msg=MESSAGE_TEXT;
  IF code='PZ001' OR code<>expected OR (expected_constraint IS NOT NULL AND con<>expected_constraint) THEN
   RAISE EXCEPTION 'Unexpected result for %: %, %, %',label,code,con,msg;
  END IF;
 END;
 INSERT INTO checks VALUES(label,code,nullif(con,''),msg);
END $$;
SET LOCAL ROLE mit8103_p3_app;
DO $tests$ BEGIN
 PERFORM pg_temp.reject('Empty order',$q$SELECT shop_api.place_order('T1','C001',ARRAY[]::text[],ARRAY[]::int[])$q$,'P3001');
 PERFORM pg_temp.reject('Duplicate product',$q$SELECT shop_api.place_order('T1','C001',ARRAY['PEN01','PEN01'],ARRAY[1,1])$q$,'P3001');
 PERFORM pg_temp.reject('Zero quantity',$q$SELECT shop_api.place_order('T1','C001',ARRAY['PEN01'],ARRAY[0])$q$,'P3001');
 PERFORM pg_temp.reject('Null quantity',$q$SELECT shop_api.place_order('T1','C001',ARRAY['PEN01'],ARRAY[NULL]::int[])$q$,'P3001');
 PERFORM pg_temp.reject('Missing customer',$q$SELECT shop_api.place_order('T1','MISSING',ARRAY['PEN01'],ARRAY[1])$q$,'P3003');
 PERFORM pg_temp.reject('Missing product',$q$SELECT shop_api.place_order('T1','C001',ARRAY['MISSING'],ARRAY[1])$q$,'P3003');
 PERFORM pg_temp.reject('Inactive product',$q$SELECT shop_api.place_order('T1','C001',ARRAY['CAL01'],ARRAY[1])$q$,'P3002');
 PERFORM pg_temp.reject('Insufficient stock',$q$SELECT shop_api.place_order('T1','C001',ARRAY['ENV01'],ARRAY[1])$q$,'P3002');
 PERFORM pg_temp.reject('Wrong payment total',$q$SELECT shop_api.record_payment('O1002','T-PAY',0.01,'2026-11-07T09:00:00Z')$q$,'P3004');
 PERFORM pg_temp.reject('Early payment',$q$SELECT shop_api.record_payment('O1002','T-PAY',1000,'2026-01-01T09:00:00Z')$q$,'P3004');
 PERFORM pg_temp.reject('Cancelled order payment',$q$SELECT shop_api.record_payment('O1004','T-PAY',5000,'2026-11-07T09:00:00Z')$q$,'P3004');
 PERFORM pg_temp.reject('Second payment',$q$SELECT shop_api.record_payment('TX-COMMIT','T-PAY',4500,'2026-11-07T09:00:00Z')$q$,'P3004');
 PERFORM pg_temp.reject('NaN payment',$q$SELECT shop_api.record_payment('O1002','T-PAY','NaN'::numeric)$q$,'P3001');
 PERFORM pg_temp.reject('Infinite payment time',$q$SELECT shop_api.record_payment('O1002','T-PAY',1000,'infinity')$q$,'P3001');
 PERFORM pg_temp.reject('Duplicate payment reference',$q$SELECT shop_api.record_payment('O1002','PAY5001',1000,'2026-11-07T09:00:00Z')$q$,'23505','uq_payment_reference');
 PERFORM pg_temp.reject('Missing order',$q$SELECT shop_api.cancel_order('MISSING')$q$,'P3003');
 PERFORM pg_temp.reject('Cancel paid order',$q$SELECT shop_api.cancel_order('TX-COMMIT','2026-11-07T09:00:00Z')$q$,'P3005');
 PERFORM pg_temp.reject('Early cancellation',$q$SELECT shop_api.cancel_order('O1002','2026-01-01T09:00:00Z')$q$,'P3005');
 PERFORM pg_temp.reject('Direct empty header',$q$INSERT INTO public.sales_order(order_number,customer_id) SELECT 'T1',customer_id FROM public.customer WHERE customer_code='C001'$q$,'42501');
 PERFORM pg_temp.reject('Edit historical line',$q$UPDATE public.order_item SET unit_price_at_order=1$q$,'42501');
 PERFORM pg_temp.reject('Edit stock directly',$q$UPDATE public.product SET stock_quantity=999$q$,'42501');
 PERFORM pg_temp.reject('Edit original customer/time',$q$UPDATE public.sales_order SET ordered_at=clock_timestamp()$q$,'42501');
 PERFORM pg_temp.reject('Delete payment history',$q$DELETE FROM public.payment$q$,'42501');
 PERFORM pg_temp.reject('Insert payment directly',$q$INSERT INTO public.payment(order_id,payment_reference,paid_at,amount) SELECT order_id,'T1',clock_timestamp(),1 FROM public.sales_order WHERE order_number='O1002'$q$,'42501');
 PERFORM pg_temp.reject('Truncate historical lines',$q$TRUNCATE public.order_item$q$,'42501');
END $tests$;
RESET ROLE;
DO $$ BEGIN
 IF (SELECT count(*) FROM checks)<>25 THEN RAISE EXCEPTION 'Missing rejection cases'; END IF;
 IF pg_temp.row_snapshot() IS DISTINCT FROM (SELECT rows FROM saved_state) THEN RAISE EXCEPTION 'Rejection suite changed rows'; END IF;
END $$;
SELECT * FROM checks ORDER BY test_name;
SELECT count(*) AS passed_rejections FROM checks;
ROLLBACK;
\echo 'PASS: all rejection probes left every business row unchanged.'
\echo 'Final committed exercise state; P1 and benchmark databases are separate and unchanged.'
SELECT o.order_number,o.order_status,p.payment_reference,p.amount FROM public.sales_order o
LEFT JOIN public.payment p USING(order_id) WHERE o.order_number LIKE 'TX-%' ORDER BY o.order_number;
SELECT sku,stock_quantity FROM public.product ORDER BY sku;
