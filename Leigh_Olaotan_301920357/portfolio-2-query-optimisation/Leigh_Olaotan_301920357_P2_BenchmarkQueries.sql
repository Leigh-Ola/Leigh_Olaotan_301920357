-- Same SQL and parameters in both phases. Business key lookup is included.
-- QUERY selective_history
SELECT o.order_number,o.ordered_at,o.order_status
FROM public.sales_order o
WHERE o.customer_id=(SELECT customer_id FROM public.customer WHERE customer_code='BC00042')
  AND o.ordered_at >= TIMESTAMPTZ '2024-04-01T00:00:00Z'
  AND o.ordered_at < TIMESTAMPTZ '2024-07-01T00:00:00Z'
ORDER BY o.ordered_at DESC,o.order_id DESC
LIMIT 10;
-- END selective_history

-- Broad workload: the customer/date index need not help this 90%-matching scan.
-- QUERY broad_status
SELECT count(*) AS placed_orders FROM public.sales_order WHERE order_status='placed';
-- END broad_status
