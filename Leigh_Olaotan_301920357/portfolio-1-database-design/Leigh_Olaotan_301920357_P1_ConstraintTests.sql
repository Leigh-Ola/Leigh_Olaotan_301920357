-- Harbour Office Supplies: targeted integrity tests for the step-6 fixture.
-- Run after P1_Schema.sql and P1_SeedData.sql, using psql and ON_ERROR_STOP.
-- A wrong error, unexpectedly accepted input, or changed fixture aborts the run.
-- All test writes are rolled back. Identity sequences can still acquire gaps.
-- WORKFLOW_BOUNDARY results expose missing later controls; they are NOT valid
-- business operations and are deliberately separate from acceptance tests.
\set ON_ERROR_STOP on
\pset pager off
SET TIME ZONE 'UTC';
SELECT current_database() AS database, current_timestamp AS executed_at, version();
BEGIN;
LOCK TABLE public.customer, public.product, public.sales_order, public.order_item,
           public.payment IN SHARE ROW EXCLUSIVE MODE;

CREATE TEMP TABLE test_result (
    test_no INTEGER GENERATED ALWAYS AS IDENTITY,
    category TEXT NOT NULL,
    test_name TEXT NOT NULL UNIQUE,
    outcome TEXT NOT NULL,
    sqlstate TEXT,
    table_name TEXT,
    constraint_name TEXT,
    column_name TEXT,
    detail TEXT
) ON COMMIT DROP;

CREATE FUNCTION pg_temp.portfolio_state() RETURNS JSONB LANGUAGE SQL AS $$
    SELECT jsonb_build_object(
        'customer', (SELECT jsonb_agg(to_jsonb(c) ORDER BY customer_id) FROM public.customer c),
        'product', (SELECT jsonb_agg(to_jsonb(p) ORDER BY product_id) FROM public.product p),
        'sales_order', (SELECT jsonb_agg(to_jsonb(o) ORDER BY order_id) FROM public.sales_order o),
        'order_item', (SELECT jsonb_agg(to_jsonb(i) ORDER BY order_id, product_id) FROM public.order_item i),
        'payment', (SELECT jsonb_agg(to_jsonb(p) ORDER BY payment_id) FROM public.payment p)
    );
$$;
CREATE TEMP TABLE baseline ON COMMIT DROP AS SELECT pg_temp.portfolio_state() AS rows;
DO $$ BEGIN
    IF (SELECT count(*) FROM public.customer) <> 6
       OR (SELECT count(*) FROM public.product) <> 8
       OR (SELECT count(*) FROM public.sales_order) <> 8
       OR (SELECT count(*) FROM public.order_item) <> 13
       OR (SELECT count(*) FROM public.payment) <> 4 THEN
        RAISE EXCEPTION 'Tests require the unchanged 39-row step-6 seed fixture';
    END IF;
END $$;

CREATE FUNCTION pg_temp.expect_rejection(
    label TEXT, statement TEXT, expected_state TEXT,
    expected_table TEXT, expected_constraint TEXT DEFAULT NULL,
    expected_column TEXT DEFAULT NULL
) RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE actual_state TEXT; actual_table TEXT; actual_constraint TEXT;
        actual_column TEXT; actual_message TEXT;
BEGIN
    BEGIN
        EXECUTE statement;
        RAISE EXCEPTION USING ERRCODE = 'PZ001',
            MESSAGE = 'Unexpected acceptance: ' || label;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS actual_state = RETURNED_SQLSTATE,
            actual_table = TABLE_NAME, actual_constraint = CONSTRAINT_NAME,
            actual_column = COLUMN_NAME, actual_message = MESSAGE_TEXT;
        IF actual_state = 'PZ001' THEN RAISE; END IF;
        IF actual_state IS DISTINCT FROM expected_state
           OR actual_table IS DISTINCT FROM expected_table
           OR (expected_constraint IS NOT NULL AND actual_constraint IS DISTINCT FROM expected_constraint)
           OR (expected_column IS NOT NULL AND actual_column IS DISTINCT FROM expected_column) THEN
            RAISE EXCEPTION 'Wrong rejection for %: state %, table %, constraint %, column %, message %',
                label, actual_state, actual_table, actual_constraint, actual_column, actual_message;
        END IF;
    END; -- The exception subtransaction rolls back the attempted operation.
    INSERT INTO test_result (category, test_name, outcome, sqlstate, table_name,
                             constraint_name, column_name, detail)
    VALUES ('REJECTION', label, 'PASS', actual_state, actual_table,
            nullif(actual_constraint,''), nullif(actual_column,''), actual_message);
END $$;

CREATE FUNCTION pg_temp.expect_acceptance(label TEXT, statement TEXT,
    test_category TEXT DEFAULT 'VALID_BOUNDARY') RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE valid_result BOOLEAN;
BEGIN
    IF test_category NOT IN ('VALID_BOUNDARY', 'WORKFLOW_BOUNDARY') THEN
        RAISE EXCEPTION 'Unknown acceptance-test category';
    END IF;
    BEGIN
        -- Each statement returns one boolean proving its intended stored result.
        EXECUTE statement INTO STRICT valid_result;
        IF valid_result IS DISTINCT FROM true THEN
            RAISE EXCEPTION 'Wrong accepted result: %', label;
        END IF;
        RAISE EXCEPTION USING ERRCODE = 'PZ002', MESSAGE = 'Rollback successful probe';
    EXCEPTION WHEN SQLSTATE 'PZ002' THEN NULL;
    END;
    INSERT INTO test_result (category, test_name, outcome, detail)
    VALUES (test_category, label,
            CASE WHEN test_category = 'WORKFLOW_BOUNDARY' THEN 'GAP CONFIRMED' ELSE 'PASS' END,
            'Statement accepted; returned value verified; probe changes rolled back');
END $$;

-- Every required column is tested with an explicit NULL. OVERRIDING permits
-- supplying identity columns so the rejection must be NOT NULL, not identity policy.
DO $required$
DECLARE a RECORD; column_list TEXT; values_list TEXT; tested INTEGER := 0;
BEGIN
    FOR a IN
        SELECT table_name, column_name FROM information_schema.columns
        WHERE table_schema = 'public' AND is_nullable = 'NO'
          AND table_name IN ('customer','product','sales_order','order_item','payment')
        ORDER BY table_name, ordinal_position
    LOOP
        SELECT string_agg(quote_ident(column_name), ', ' ORDER BY ordinal_position),
               string_agg(CASE WHEN column_name = a.column_name THEN 'NULL'
                              ELSE quote_ident(column_name) END, ', ' ORDER BY ordinal_position)
        INTO column_list, values_list FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = a.table_name;
        PERFORM pg_temp.expect_rejection('Required ' || a.table_name || '.' || a.column_name,
            format('INSERT INTO public.%I (%s) OVERRIDING SYSTEM VALUE SELECT %s FROM public.%I LIMIT 1',
                   a.table_name, column_list, values_list, a.table_name),
            '23502', a.table_name, NULL, a.column_name);
        tested := tested + 1;
    END LOOP;
    IF tested <> 24 THEN RAISE EXCEPTION 'Expected 24 required-column tests, got %', tested; END IF;
END $required$;

DO $cases$
BEGIN
    -- Candidate keys and all five primary keys. Other fields remain valid.
    PERFORM pg_temp.expect_rejection('Duplicate customer primary key',
        $sql$INSERT INTO public.customer OVERRIDING SYSTEM VALUE SELECT customer_id,'T-CUST','Test Person','test.pk@example.com' FROM public.customer WHERE customer_code='C001'$sql$,
        '23505', 'customer', 'pk_customer');
    PERFORM pg_temp.expect_rejection('Duplicate product primary key',
        $sql$INSERT INTO public.product OVERRIDING SYSTEM VALUE SELECT product_id,'T-SKU','Test Product',1,0,true FROM public.product WHERE sku='PEN01'$sql$,
        '23505', 'product', 'pk_product');
    PERFORM pg_temp.expect_rejection('Duplicate order primary key',
        $sql$INSERT INTO public.sales_order OVERRIDING SYSTEM VALUE SELECT order_id,'T-ORDER',customer_id,ordered_at,'placed',NULL FROM public.sales_order WHERE order_number='O1001'$sql$,
        '23505', 'sales_order', 'pk_sales_order');
    PERFORM pg_temp.expect_rejection('Duplicate composite order line',
        $sql$INSERT INTO public.order_item VALUES ((SELECT order_id FROM public.sales_order WHERE order_number='O1001'),(SELECT product_id FROM public.product WHERE sku='PEN01'),1,900)$sql$,
        '23505', 'order_item', 'pk_order_item');
    PERFORM pg_temp.expect_rejection('Duplicate payment primary key',
        $sql$INSERT INTO public.payment OVERRIDING SYSTEM VALUE SELECT payment_id,(SELECT order_id FROM public.sales_order WHERE order_number='O1002'),'T-PAY','2026-11-04T12:00:00Z',1000 FROM public.payment WHERE payment_reference='PAY5001'$sql$,
        '23505', 'payment', 'pk_payment');
    PERFORM pg_temp.expect_rejection('Duplicate customer code',
        $sql$UPDATE public.customer SET customer_code='C001' WHERE customer_code='C002'$sql$,
        '23505', 'customer', 'uq_customer_code');
    PERFORM pg_temp.expect_rejection('Duplicate customer email',
        $sql$UPDATE public.customer SET email='ada.ojo@example.com' WHERE customer_code='C002'$sql$,
        '23505', 'customer', 'uq_customer_email');
    PERFORM pg_temp.expect_rejection('Duplicate product SKU',
        $sql$UPDATE public.product SET sku='PEN01' WHERE sku='PAP01'$sql$,
        '23505', 'product', 'uq_product_sku');
    PERFORM pg_temp.expect_rejection('Duplicate order number',
        $sql$UPDATE public.sales_order SET order_number='O1001' WHERE order_number='O1002'$sql$,
        '23505', 'sales_order', 'uq_sales_order_number');
    PERFORM pg_temp.expect_rejection('Second payment for one order',
        $sql$UPDATE public.payment SET order_id=(SELECT order_id FROM public.sales_order WHERE order_number='O1001') WHERE payment_reference='PAY5003'$sql$,
        '23505', 'payment', 'uq_payment_order');
    PERFORM pg_temp.expect_rejection('Duplicate payment reference',
        $sql$UPDATE public.payment SET payment_reference='PAY5001' WHERE payment_reference='PAY5003'$sql$,
        '23505', 'payment', 'uq_payment_reference');

    -- Missing parents and referenced-parent deletion/update restrictions.
    PERFORM pg_temp.expect_rejection('Missing parent sales_order.customer_id',
        $sql$UPDATE public.sales_order SET customer_id=-1 WHERE order_number='O1002'$sql$,
        '23503', 'sales_order', 'fk_sales_order_customer');
    PERFORM pg_temp.expect_rejection('Missing parent order_item.order_id',
        $sql$UPDATE public.order_item SET order_id=-1 WHERE order_id=(SELECT order_id FROM public.sales_order WHERE order_number='O1002')$sql$,
        '23503', 'order_item', 'fk_order_item_order');
    PERFORM pg_temp.expect_rejection('Missing parent order_item.product_id',
        $sql$UPDATE public.order_item SET product_id=-1 WHERE order_id=(SELECT order_id FROM public.sales_order WHERE order_number='O1002')$sql$,
        '23503', 'order_item', 'fk_order_item_product');
    PERFORM pg_temp.expect_rejection('Missing parent payment.order_id',
        $sql$UPDATE public.payment SET order_id=-1 WHERE payment_reference='PAY5001'$sql$,
        '23503', 'payment', 'fk_payment_order');
    PERFORM pg_temp.expect_rejection('Restrict deletion of referenced customer',
        $sql$DELETE FROM public.customer WHERE customer_code='C001'$sql$,
        '23503', 'sales_order', 'fk_sales_order_customer');
    PERFORM pg_temp.expect_rejection('Restrict deletion of referenced product',
        $sql$DELETE FROM public.product WHERE sku='PEN01'$sql$,
        '23503', 'order_item', 'fk_order_item_product');
    PERFORM pg_temp.expect_rejection('Restrict deletion of referenced sales_order',
        $sql$DELETE FROM public.sales_order WHERE order_number='O1002'$sql$,
        '23503', 'order_item', 'fk_order_item_order');
    PERFORM pg_temp.expect_rejection('Restrict deletion of paid order',
        $sql$DELETE FROM public.order_item WHERE order_id=(SELECT order_id FROM public.sales_order WHERE order_number='O1001'); DELETE FROM public.sales_order WHERE order_number='O1001'$sql$,
        '23503', 'payment', 'fk_payment_order');
    PERFORM pg_temp.expect_rejection('Restrict key update of referenced customer',
        $sql$UPDATE public.customer SET customer_id=DEFAULT WHERE customer_code='C001'$sql$,
        '23503', 'sales_order', 'fk_sales_order_customer');
    PERFORM pg_temp.expect_rejection('Restrict key update of referenced product',
        $sql$UPDATE public.product SET product_id=DEFAULT WHERE sku='PEN01'$sql$,
        '23503', 'order_item', 'fk_order_item_product');
    PERFORM pg_temp.expect_rejection('Restrict key update of referenced sales_order',
        $sql$UPDATE public.sales_order SET order_id=DEFAULT WHERE order_number='O1002'$sql$,
        '23503', 'order_item', 'fk_order_item_order');
    PERFORM pg_temp.expect_rejection('Restrict key update of paid order',
        $sql$DELETE FROM public.order_item WHERE order_id=(SELECT order_id FROM public.sales_order WHERE order_number='O1001'); UPDATE public.sales_order SET order_id=DEFAULT WHERE order_number='O1001'$sql$,
        '23503', 'payment', 'fk_payment_order');

    -- Nonblank fields and the stated email storage policy.
    PERFORM pg_temp.expect_rejection('Whitespace-only customer.customer_code',
        $sql$UPDATE public.customer SET customer_code=E' \t ' WHERE customer_code='C001'$sql$,
        '23514', 'customer', 'ck_customer_code_nonblank');
    PERFORM pg_temp.expect_rejection('Whitespace-only customer.full_name',
        $sql$UPDATE public.customer SET full_name=E' \t ' WHERE customer_code='C001'$sql$,
        '23514', 'customer', 'ck_customer_name_nonblank');
    PERFORM pg_temp.expect_rejection('Whitespace-only customer.email',
        $sql$UPDATE public.customer SET email=E' \t ' WHERE customer_code='C001'$sql$,
        '23514', 'customer', 'ck_customer_email_normalised');
    PERFORM pg_temp.expect_rejection('Whitespace-only product.sku',
        $sql$UPDATE public.product SET sku=E' \t ' WHERE sku='PEN01'$sql$,
        '23514', 'product', 'ck_product_sku_nonblank');
    PERFORM pg_temp.expect_rejection('Whitespace-only product.product_name',
        $sql$UPDATE public.product SET product_name=E' \t ' WHERE sku='PEN01'$sql$,
        '23514', 'product', 'ck_product_name_nonblank');
    PERFORM pg_temp.expect_rejection('Whitespace-only sales_order.order_number',
        $sql$UPDATE public.sales_order SET order_number=E' \t ' WHERE order_number='O1001'$sql$,
        '23514', 'sales_order', 'ck_sales_order_number_nonblank');
    PERFORM pg_temp.expect_rejection('Whitespace-only payment.payment_reference',
        $sql$UPDATE public.payment SET payment_reference=E' \t ' WHERE payment_reference='PAY5001'$sql$,
        '23514', 'payment', 'ck_payment_reference_nonblank');
    PERFORM pg_temp.expect_rejection('Uppercase email',
        $sql$UPDATE public.customer SET email='ADA.OJO@example.com' WHERE customer_code='C001'$sql$,
        '23514', 'customer', 'ck_customer_email_normalised');
    PERFORM pg_temp.expect_rejection('Padded email',
        $sql$UPDATE public.customer SET email=' ada.ojo@example.com ' WHERE customer_code='C001'$sql$,
        '23514', 'customer', 'ck_customer_email_normalised');
    PERFORM pg_temp.expect_rejection('Internal whitespace email',
        $sql$UPDATE public.customer SET email='ada ojo@example.com' WHERE customer_code='C001'$sql$,
        '23514', 'customer', 'ck_customer_email_normalised');

    -- Monetary lower boundaries and NaN; quantity and stock boundaries.
    PERFORM pg_temp.expect_rejection('Zero product.unit_price',
        $sql$UPDATE public.product SET unit_price=0 WHERE sku='PEN01'$sql$,
        '23514', 'product', 'ck_product_price_positive');
    PERFORM pg_temp.expect_rejection('Negative product.unit_price',
        $sql$UPDATE public.product SET unit_price=-0.01 WHERE sku='PEN01'$sql$,
        '23514', 'product', 'ck_product_price_positive');
    PERFORM pg_temp.expect_rejection('NaN product.unit_price',
        $sql$UPDATE public.product SET unit_price='NaN'::numeric WHERE sku='PEN01'$sql$,
        '23514', 'product', 'ck_product_price_positive');
    PERFORM pg_temp.expect_rejection('Zero order_item.unit_price_at_order',
        $sql$UPDATE public.order_item SET unit_price_at_order=0 WHERE order_id=(SELECT order_id FROM public.sales_order WHERE order_number='O1002')$sql$,
        '23514', 'order_item', 'ck_order_item_price_positive');
    PERFORM pg_temp.expect_rejection('Negative order_item.unit_price_at_order',
        $sql$UPDATE public.order_item SET unit_price_at_order=-0.01 WHERE order_id=(SELECT order_id FROM public.sales_order WHERE order_number='O1002')$sql$,
        '23514', 'order_item', 'ck_order_item_price_positive');
    PERFORM pg_temp.expect_rejection('NaN order_item.unit_price_at_order',
        $sql$UPDATE public.order_item SET unit_price_at_order='NaN'::numeric WHERE order_id=(SELECT order_id FROM public.sales_order WHERE order_number='O1002')$sql$,
        '23514', 'order_item', 'ck_order_item_price_positive');
    PERFORM pg_temp.expect_rejection('Zero payment.amount',
        $sql$UPDATE public.payment SET amount=0 WHERE payment_reference='PAY5001'$sql$,
        '23514', 'payment', 'ck_payment_amount_positive');
    PERFORM pg_temp.expect_rejection('Negative payment.amount',
        $sql$UPDATE public.payment SET amount=-0.01 WHERE payment_reference='PAY5001'$sql$,
        '23514', 'payment', 'ck_payment_amount_positive');
    PERFORM pg_temp.expect_rejection('NaN payment.amount',
        $sql$UPDATE public.payment SET amount='NaN'::numeric WHERE payment_reference='PAY5001'$sql$,
        '23514', 'payment', 'ck_payment_amount_positive');
    PERFORM pg_temp.expect_rejection('Line quantity 0',
        $sql$UPDATE public.order_item SET quantity=0 WHERE order_id=(SELECT order_id FROM public.sales_order WHERE order_number='O1002')$sql$,
        '23514', 'order_item', 'ck_order_item_quantity_positive');
    PERFORM pg_temp.expect_rejection('Line quantity -1',
        $sql$UPDATE public.order_item SET quantity=-1 WHERE order_id=(SELECT order_id FROM public.sales_order WHERE order_number='O1002')$sql$,
        '23514', 'order_item', 'ck_order_item_quantity_positive');
    PERFORM pg_temp.expect_rejection('Negative available stock',
        $sql$UPDATE public.product SET stock_quantity=-1 WHERE sku='PEN01'$sql$,
        '23514', 'product', 'ck_product_stock_nonnegative');

    -- Status and cancellation chronology. No cross-table workflow claim.
    PERFORM pg_temp.expect_rejection('Unrecognised order status',
        $sql$UPDATE public.sales_order SET order_status='shipped' WHERE order_number='O1002'$sql$,
        '23514', 'sales_order', 'ck_sales_order_status');
    PERFORM pg_temp.expect_rejection('Placed order with cancellation time',
        $sql$UPDATE public.sales_order SET cancelled_at=ordered_at WHERE order_number='O1002'$sql$,
        '23514', 'sales_order', 'ck_sales_order_cancellation');
    PERFORM pg_temp.expect_rejection('Cancelled order without time',
        $sql$UPDATE public.sales_order SET order_status='cancelled',cancelled_at=NULL WHERE order_number='O1002'$sql$,
        '23514', 'sales_order', 'ck_sales_order_cancellation');
    PERFORM pg_temp.expect_rejection('Cancellation before placement',
        $sql$UPDATE public.sales_order SET order_status='cancelled',cancelled_at=ordered_at-interval '1 second' WHERE order_number='O1002'$sql$,
        '23514', 'sales_order', 'ck_sales_order_cancellation');
    PERFORM pg_temp.expect_rejection('Infinite cancellation time',
        $sql$UPDATE public.sales_order SET order_status='cancelled',cancelled_at='infinity' WHERE order_number='O1002'$sql$,
        '23514', 'sales_order', 'ck_sales_order_cancellation');
    PERFORM pg_temp.expect_rejection('Order time infinity',
        $sql$UPDATE public.sales_order SET ordered_at='infinity' WHERE order_number='O1002'$sql$,
        '23514', 'sales_order', 'ck_sales_order_time_finite');
    PERFORM pg_temp.expect_rejection('Payment time infinity',
        $sql$UPDATE public.payment SET paid_at='infinity' WHERE payment_reference='PAY5001'$sql$,
        '23514', 'payment', 'ck_payment_time_finite');
    PERFORM pg_temp.expect_rejection('Order time -infinity',
        $sql$UPDATE public.sales_order SET ordered_at='-infinity' WHERE order_number='O1002'$sql$,
        '23514', 'sales_order', 'ck_sales_order_time_finite');
    PERFORM pg_temp.expect_rejection('Payment time -infinity',
        $sql$UPDATE public.payment SET paid_at='-infinity' WHERE payment_reference='PAY5001'$sql$,
        '23514', 'payment', 'ck_payment_time_finite');

    -- Valid boundaries, generated identifiers, defaults and non-unique names.
    PERFORM pg_temp.expect_acceptance('Customer identity generated',
        $sql$INSERT INTO public.customer(customer_code,full_name,email) VALUES ('T-CUST','Test Person','test.accept@example.com') RETURNING customer_id>0$sql$, 'VALID_BOUNDARY');
    PERFORM pg_temp.expect_acceptance('Product defaults: zero stock and active',
        $sql$INSERT INTO public.product(sku,product_name,unit_price) VALUES ('T-PROD','Test Product',0.01) RETURNING product_id>0 AND unit_price=0.01 AND stock_quantity=0 AND is_active$sql$, 'VALID_BOUNDARY');
    PERFORM pg_temp.expect_acceptance('Order identity and default timestamp/status',
        $sql$INSERT INTO public.sales_order(order_number,customer_id) VALUES ('T-ORDER',(SELECT customer_id FROM public.customer WHERE customer_code='C006')) RETURNING order_id>0 AND order_status='placed' AND cancelled_at IS NULL AND ordered_at=CURRENT_TIMESTAMP$sql$, 'VALID_BOUNDARY');
    PERFORM pg_temp.expect_acceptance('Duplicate personal names allowed',
        $sql$UPDATE public.customer SET full_name='Ada Ojo' WHERE customer_code='C002' RETURNING full_name='Ada Ojo'$sql$, 'VALID_BOUNDARY');
    PERFORM pg_temp.expect_acceptance('Duplicate product names allowed',
        $sql$UPDATE public.product SET product_name='Pen pack' WHERE sku='FLD01' RETURNING product_name='Pen pack'$sql$, 'VALID_BOUNDARY');
    PERFORM pg_temp.expect_acceptance('One line unit and smallest positive stored price',
        $sql$UPDATE public.order_item SET quantity=1,unit_price_at_order=0.01 WHERE order_id=(SELECT order_id FROM public.sales_order WHERE order_number='O1002') RETURNING quantity=1 AND unit_price_at_order=0.01$sql$, 'VALID_BOUNDARY');
    PERFORM pg_temp.expect_acceptance('Cancellation exactly at placement time',
        $sql$UPDATE public.sales_order SET cancelled_at=ordered_at WHERE order_number='O1004' RETURNING cancelled_at=ordered_at$sql$, 'VALID_BOUNDARY');
    PERFORM pg_temp.expect_acceptance('Generated payment identity for full unpaid order',
        $sql$INSERT INTO public.payment(order_id,payment_reference,paid_at,amount) VALUES ((SELECT order_id FROM public.sales_order WHERE order_number='O1002'),'T-PAY','2026-11-04T12:00:00Z',1000) RETURNING payment_id>0 AND amount=1000$sql$, 'VALID_BOUNDARY');

    -- Known workflow gaps, accepted by row constraints and then rolled back.
    PERFORM pg_temp.expect_acceptance('Order header can exist without lines',
        $sql$INSERT INTO public.sales_order(order_number,customer_id) VALUES ('T-EMPTY',(SELECT customer_id FROM public.customer WHERE customer_code='C006')) RETURNING NOT EXISTS (SELECT 1 FROM public.order_item i WHERE i.order_id=sales_order.order_id)$sql$, 'WORKFLOW_BOUNDARY');
    PERFORM pg_temp.expect_acceptance('Placed historical line price can be edited',
        $sql$UPDATE public.order_item SET unit_price_at_order=1100 WHERE order_id=(SELECT order_id FROM public.sales_order WHERE order_number='O1002') RETURNING unit_price_at_order=1100$sql$, 'WORKFLOW_BOUNDARY');
    PERFORM pg_temp.expect_acceptance('Payment can differ from order total',
        $sql$INSERT INTO public.payment(order_id,payment_reference,paid_at,amount) VALUES ((SELECT order_id FROM public.sales_order WHERE order_number='O1002'),'T-WRONG-TOTAL','2026-11-04T12:00:00Z',0.01) RETURNING amount=0.01$sql$, 'WORKFLOW_BOUNDARY');
    PERFORM pg_temp.expect_acceptance('Payment can precede placement',
        $sql$INSERT INTO public.payment(order_id,payment_reference,paid_at,amount) VALUES ((SELECT order_id FROM public.sales_order WHERE order_number='O1002'),'T-EARLY-PAY','2026-10-01T12:00:00Z',1000) RETURNING paid_at < (SELECT ordered_at FROM public.sales_order WHERE order_id=payment.order_id)$sql$, 'WORKFLOW_BOUNDARY');
    PERFORM pg_temp.expect_acceptance('Cancelled order can receive payment',
        $sql$INSERT INTO public.payment(order_id,payment_reference,paid_at,amount) VALUES ((SELECT order_id FROM public.sales_order WHERE order_number='O1004'),'T-CANCELLED-PAY','2026-11-04T12:00:00Z',5000) RETURNING order_id=(SELECT order_id FROM public.sales_order WHERE order_number='O1004')$sql$, 'WORKFLOW_BOUNDARY');
    PERFORM pg_temp.expect_acceptance('Inactive product can be inserted as an order line',
        $sql$INSERT INTO public.order_item VALUES ((SELECT order_id FROM public.sales_order WHERE order_number='O1002'),(SELECT product_id FROM public.product WHERE sku='CAL01'),1,8000) RETURNING product_id=(SELECT product_id FROM public.product WHERE sku='CAL01')$sql$, 'WORKFLOW_BOUNDARY');
END $cases$;

-- Coverage confirms no declared named constraint was missed by the rejection
-- suite. Full row equality is stronger than comparing only the row counts.
DO $verify$
DECLARE missing TEXT;
BEGIN
    SELECT string_agg(c.conname, ', ' ORDER BY c.conname) INTO missing
    FROM pg_constraint c JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public'
      AND t.relname IN ('customer','product','sales_order','order_item','payment')
      AND NOT EXISTS (SELECT 1 FROM test_result r WHERE r.category = 'REJECTION'
                      AND r.constraint_name = c.conname AND r.table_name = t.relname);
    IF missing IS NOT NULL THEN RAISE EXCEPTION 'Untested constraints: %', missing; END IF;
    IF (SELECT count(DISTINCT constraint_name) FROM test_result WHERE constraint_name IS NOT NULL) <> 31 THEN
        RAISE EXCEPTION 'Expected 31 named constraints covered';
    END IF;
    IF pg_temp.portfolio_state() IS DISTINCT FROM (SELECT rows FROM baseline) THEN
        RAISE EXCEPTION 'Test probes changed the original fixture rows';
    END IF;
    INSERT INTO test_result (category, test_name, outcome, detail) VALUES
        ('STATE_CHECK','All 39 rows equal the pre-test snapshot','PASS',
         'All columns of all five tables compared; identity sequence positions excluded');
END $verify$;

\echo 'Observed results: SQLSTATE and exact table/constraint/column verified for each rejection.'
SELECT test_no, category, test_name, outcome, sqlstate,
       table_name, constraint_name, column_name FROM test_result ORDER BY test_no;
\echo 'Diagnostic messages returned by PostgreSQL (not fabricated expected output).'
SELECT test_no, detail FROM test_result WHERE category = 'REJECTION' ORDER BY test_no;
\echo 'Coverage and outcomes. Workflow gaps are explicitly separate from successful integrity checks.'
SELECT category, outcome, count(*) AS tests FROM test_result
GROUP BY category, outcome ORDER BY category;
SELECT count(DISTINCT constraint_name) AS named_constraints_tested,
       count(*) FILTER (WHERE sqlstate = '23502') AS required_columns_tested
FROM test_result;
ROLLBACK;
\echo 'Test transaction rolled back. Seed rows retained; sequence gaps are normal and are not reset.'
