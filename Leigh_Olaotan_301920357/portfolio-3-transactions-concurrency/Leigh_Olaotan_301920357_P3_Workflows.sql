-- Controlled order operations, installed after the P1 schema/seed in a separate
-- practice database. Run as the local administrator. No tables/data are reset.
\set ON_ERROR_STOP on
\pset pager off
BEGIN;
DO $$ BEGIN
 IF current_database() IN ('mit8103_portfolio','mit8103_benchmark') THEN
  RAISE EXCEPTION 'Use a separate transaction practice database';
 END IF;
 -- These cluster roles are local NOLOGIN roles used solely for this portfolio.
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='mit8103_p3_owner') THEN
  CREATE ROLE mit8103_p3_owner NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='mit8103_p3_app') THEN
  CREATE ROLE mit8103_p3_app NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
 END IF;
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname IN ('mit8103_p3_owner','mit8103_p3_app')
  AND (rolcanlogin OR rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls))
 OR EXISTS(SELECT 1 FROM pg_auth_members WHERE member IN
  (SELECT oid FROM pg_roles WHERE rolname IN ('mit8103_p3_owner','mit8103_p3_app'))) THEN
  RAISE EXCEPTION 'Existing portfolio roles have unexpected elevated privileges/membership';
 END IF;
END $$;
CREATE SCHEMA shop_api AUTHORIZATION mit8103_p3_owner;
REVOKE ALL ON SCHEMA shop_api FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO mit8103_p3_owner,mit8103_p3_app;
GRANT SELECT,INSERT,UPDATE ON public.customer,public.product,public.sales_order,public.order_item,public.payment TO mit8103_p3_owner;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO mit8103_p3_owner;
REVOKE ALL ON public.customer,public.product,public.sales_order,public.order_item,public.payment FROM PUBLIC,mit8103_p3_app;
GRANT SELECT ON public.customer,public.product,public.sales_order,public.order_item,public.payment TO mit8103_p3_app;
GRANT USAGE ON SCHEMA shop_api TO mit8103_p3_app;

CREATE FUNCTION shop_api.place_order(p_number text,p_customer_code text,
 p_skus text[],p_quantities integer[],p_time timestamptz DEFAULT clock_timestamp())
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE v_customer bigint; v_order bigint; r record; v_total numeric:=0;
BEGIN
 IF p_number IS NULL OR p_number !~ '[^[:space:]]' OR p_time IS NULL OR NOT isfinite(p_time)
 OR coalesce(array_ndims(p_skus),0)<>1 OR coalesce(array_ndims(p_quantities),0)<>1
 OR cardinality(p_skus)=0 OR cardinality(p_skus)<>cardinality(p_quantities)
 OR EXISTS(SELECT 1 FROM unnest(p_skus,p_quantities) x(sku,qty) WHERE sku IS NULL OR qty IS NULL OR qty<=0)
 OR (SELECT count(DISTINCT sku) FROM unnest(p_skus) sku)<>cardinality(p_skus) THEN
  RAISE EXCEPTION USING ERRCODE='P3001',MESSAGE='Invalid order input: require nonempty distinct products and positive quantities';
 END IF;
 SELECT customer_id INTO v_customer FROM public.customer WHERE customer_code=p_customer_code;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P3003',MESSAGE='Customer not found'; END IF;
 IF (SELECT count(*) FROM public.product WHERE sku=ANY(p_skus))<>cardinality(p_skus) THEN
  RAISE EXCEPTION USING ERRCODE='P3003',MESSAGE='Product not found';
 END IF;
 INSERT INTO public.sales_order(order_number,customer_id,ordered_at)
 VALUES(p_number,v_customer,p_time) RETURNING order_id INTO v_order;
 -- All products are locked in stable primary-key order. Values are rechecked
 -- after a conflicting writer commits; the current row price becomes history.
 FOR r IN SELECT p.product_id,p.sku,p.unit_price,p.stock_quantity,p.is_active,x.qty
  FROM public.product p JOIN unnest(p_skus,p_quantities) x(sku,qty) USING(sku)
  ORDER BY p.product_id FOR UPDATE OF p
 LOOP
  IF NOT r.is_active OR r.stock_quantity<r.qty THEN
   RAISE EXCEPTION USING ERRCODE='P3002',MESSAGE='Product inactive or insufficient stock: '||r.sku;
  END IF;
  v_total:=v_total+r.qty*r.unit_price;
  IF v_total>999999999999.99 THEN
   RAISE EXCEPTION USING ERRCODE='P3001',MESSAGE='Order total exceeds payment amount capacity';
  END IF;
  UPDATE public.product SET stock_quantity=stock_quantity-r.qty WHERE product_id=r.product_id;
  INSERT INTO public.order_item(order_id,product_id,quantity,unit_price_at_order)
  VALUES(v_order,r.product_id,r.qty,r.unit_price);
 END LOOP;
 RETURN v_order;
END $$;

CREATE FUNCTION shop_api.record_payment(p_number text,p_reference text,p_amount numeric,
 p_time timestamptz DEFAULT clock_timestamp()) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE o public.sales_order%ROWTYPE; v_total numeric; v_id bigint;
BEGIN
 IF p_time IS NULL OR NOT isfinite(p_time) OR p_amount IS NULL
 OR NOT(p_amount>0 AND p_amount<=999999999999.99)
 OR p_reference IS NULL OR p_reference !~ '[^[:space:]]' THEN
  RAISE EXCEPTION USING ERRCODE='P3001',MESSAGE='Invalid payment input';
 END IF;
 SELECT * INTO o FROM public.sales_order WHERE order_number=p_number FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P3003',MESSAGE='Order not found'; END IF;
 IF o.order_status<>'placed' OR p_time<o.ordered_at
 OR EXISTS(SELECT 1 FROM public.payment WHERE order_id=o.order_id) THEN
  RAISE EXCEPTION USING ERRCODE='P3004',MESSAGE='Order is not eligible for this payment';
 END IF;
 SELECT sum(quantity*unit_price_at_order) INTO v_total FROM public.order_item WHERE order_id=o.order_id;
 IF v_total IS NULL OR p_amount<>v_total THEN
  RAISE EXCEPTION USING ERRCODE='P3004',MESSAGE='Payment must equal the nonempty order total';
 END IF;
 INSERT INTO public.payment(order_id,payment_reference,paid_at,amount)
 VALUES(o.order_id,p_reference,p_time,p_amount) RETURNING payment_id INTO v_id;
 RETURN v_id;
END $$;

CREATE FUNCTION shop_api.cancel_order(p_number text,p_time timestamptz DEFAULT clock_timestamp())
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE o public.sales_order%ROWTYPE; r record;
BEGIN
 IF p_time IS NULL OR NOT isfinite(p_time) THEN
  RAISE EXCEPTION USING ERRCODE='P3001',MESSAGE='Invalid cancellation time';
 END IF;
 -- Same order lock as payment: check eligibility only after obtaining it.
 SELECT * INTO o FROM public.sales_order WHERE order_number=p_number FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P3003',MESSAGE='Order not found'; END IF;
 IF o.order_status='cancelled' THEN RETURN false; END IF;
 IF p_time<o.ordered_at OR EXISTS(SELECT 1 FROM public.payment WHERE order_id=o.order_id) THEN
  RAISE EXCEPTION USING ERRCODE='P3005',MESSAGE='Cannot cancel a paid order or cancel before placement';
 END IF;
 FOR r IN SELECT p.product_id,i.quantity FROM public.product p
  JOIN public.order_item i USING(product_id) WHERE i.order_id=o.order_id
  ORDER BY p.product_id FOR UPDATE OF p
 LOOP
  UPDATE public.product SET stock_quantity=stock_quantity+r.quantity WHERE product_id=r.product_id;
 END LOOP;
 UPDATE public.sales_order SET order_status='cancelled',cancelled_at=p_time WHERE order_id=o.order_id;
 RETURN true;
END $$;
ALTER FUNCTION shop_api.place_order(text,text,text[],integer[],timestamptz) OWNER TO mit8103_p3_owner;
ALTER FUNCTION shop_api.record_payment(text,text,numeric,timestamptz) OWNER TO mit8103_p3_owner;
ALTER FUNCTION shop_api.cancel_order(text,timestamptz) OWNER TO mit8103_p3_owner;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA shop_api FROM PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA shop_api TO mit8103_p3_app;
COMMIT;
SELECT n.nspname,p.proname,r.rolname AS owner,p.prosecdef AS security_definer,p.proconfig
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace JOIN pg_roles r ON r.oid=p.proowner
WHERE n.nspname='shop_api' ORDER BY p.proname;
SELECT has_table_privilege('mit8103_p3_app','public.order_item','UPDATE') AS app_can_edit_lines,
 has_table_privilege('mit8103_p3_app','public.product','UPDATE') AS app_can_edit_stock,
 has_function_privilege('mit8103_p3_app','shop_api.place_order(text,text,text[],integer[],timestamptz)','EXECUTE') AS app_can_place_order;
