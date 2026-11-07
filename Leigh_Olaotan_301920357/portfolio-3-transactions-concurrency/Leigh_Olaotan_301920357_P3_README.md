# Portfolio 3: Transactions and Concurrency

Harbour Office Supplies: atomic order placement, full payment, cancellation and competing access to the same stock/order. These exercises use `mit8103_transactions`, a separate database seeded from P1. The original P1 fixture and benchmark database remain unchanged.

## Implemented workflow controls

[Workflow SQL](Leigh_Olaotan_301920357_P3_Workflows.sql) and [installation/privilege output](Leigh_Olaotan_301920357_P3_WorkflowOutput.txt).

| Operation | Controls and relationship to case rules |
| --- | --- |
| `shop_api.place_order(number, customer_code, skus[], quantities[], time)` | Requires an existing customer, at least one distinct existing SKU and positive whole quantities. Locks product rows in ascending product_id order, checks activity/stock after obtaining locks, captures current prices, reserves stock and inserts header/lines in the caller's transaction. Rejects totals beyond the payment field's capacity. BR03–BR06. |
| `shop_api.record_payment(number, reference, amount, time)` | Locks the order, requires placed/unpaid status, a finite valid time and exact full line total, then inserts one payment. Unique order/reference constraints remain a second protection. BR08. |
| `shop_api.cancel_order(number, time)` | Locks the same order used by payment, rejects a paid order or early time, locks products in ascending ID order, restores quantities and records cancellation together. A repeat returns false with no changes. Lines remain as history. BR07–BR09. |

Functions are SECURITY DEFINER owned by a dedicated non-login, non-superuser role, with a fixed `pg_catalog,pg_temp` search path and fully qualified application tables. PUBLIC cannot execute them. `mit8103_p3_app` can read the five tables and execute these operations, but cannot directly insert/update/delete/truncate their records or edit historical lines, customer/time, payments or stock. This closes P1's six demonstrated workflow gaps for callers constrained to that role. Names/IDs, row checks and uniqueness continue to use the P1 schema.

The scripts connect as the local administrator and use SET ROLE to demonstrate effective application privileges; the two roles have NOLOGIN. This is a local role/operation exercise, not a deployed login or customer-identity authorisation system. A true administrator, object owner, or other role with direct write privileges can bypass the operation boundary. The database does not claim universal immutability through triggers. Customer/catalogue maintenance and permissioned login provisioning are outside these exercises. Direct administrator changes during the controlled experiments are excluded.

Functions do not commit internally. The caller owns BEGIN/COMMIT/ROLLBACK. Product locks use a consistent order; payment and cancellation coordinate on the same order row. Callers must handle database errors and retry whole transactions where appropriate; deadlock/serialization retry handling is not a deployed application feature here. The intended demonstration isolation level is READ COMMITTED.

## Observed transaction results

[Executable demonstrations](Leigh_Olaotan_301920357_P3_Transactions.sql) and [actual output](Leigh_Olaotan_301920357_P3_TransactionResults.txt).

1. TX-COMMIT reserves two PEN01 and one PAP01. COMMIT saves its two lines and NGN 4,500 total; pen stock changes 20→18 and paper 10→9.
2. A second transaction first creates TX-ROLLBACK, then attempts TX-FAIL with PEN01 and out-of-stock ENV01. The second function reaches the envelope after a pen deduction and raises P3002. ROLLBACK undoes the earlier successful operation as well. A full JSON comparison of all columns in all five tables matches the pre-transaction snapshot; neither attempted order remains. TX-COMMIT is retained.
3. TX-PAY records the exact NGN 4,500 settlement for TX-COMMIT and commits.
4. TX-CANCEL reserves two notebooks (12→10), then cancellation restores them (10→12). A repeated cancellation returns false and preserves the original cancellation timestamp and line.
5. A rolled-back catalogue-price probe shows O1001's pen price stays NGN 900 and TX-COMMIT's stays NGN 1,000 despite changing the current catalogue price to NGN 9,999.
6. Twenty-five rejection checks verify custom business SQLSTATEs, permission denial 42501 and the specific duplicate-reference constraint. They cover empty/duplicate/invalid lines, missing/inactive/out-of-stock products, payment total/time/status, paid-order cancellation, and prohibited direct history/stock writes. Every probe is undone; all business rows match their before-test snapshot.

The visible insufficient-stock ERROR is deliberate and its exact SQLSTATE is checked after ROLLBACK. Other unexpected errors stop the script. Rejected inserts may consume identity values; sequence gaps are expected and are not reset. Snapshot equality concerns business rows, not sequence counters.

## Reproduce step 10

From repository root with Docker running, create a new isolated database. These commands are the initial setup; do not rerun the installation or transaction demonstrations in the already-used database. The exercise refuses its own TX-/CC- records instead of resetting them.

```sh
docker exec mit8103-postgres createdb -U mit8103_admin mit8103_transactions
docker exec -i mit8103-postgres psql -X -v ON_ERROR_STOP=1 -U mit8103_admin -d mit8103_transactions \
  < Leigh_Olaotan_301920357/portfolio-1-database-design/Leigh_Olaotan_301920357_P1_Schema.sql
docker exec -i mit8103-postgres psql -X -v ON_ERROR_STOP=1 -U mit8103_admin -d mit8103_transactions \
  < Leigh_Olaotan_301920357/portfolio-1-database-design/Leigh_Olaotan_301920357_P1_SeedData.sql
docker exec -i mit8103-postgres psql -X -v ON_ERROR_STOP=1 -U mit8103_admin -d mit8103_transactions \
  < Leigh_Olaotan_301920357/portfolio-3-transactions-concurrency/Leigh_Olaotan_301920357_P3_Workflows.sql
docker exec -i mit8103-postgres psql -X -v ON_ERROR_STOP=1 -U mit8103_admin -d mit8103_transactions \
  < Leigh_Olaotan_301920357/portfolio-3-transactions-concurrency/Leigh_Olaotan_301920357_P3_Transactions.sql
```

Use `/Users/user/.docker/bin/docker` if Docker is absent from PATH, or standard psql against another PostgreSQL 17 server. The installation creates two cluster-scoped NOLOGIN roles if absent and checks they have no elevated attributes or memberships before reuse in a fresh database. Creating roles/objects requires an administrator. Credentials are not included. See [environment setup](../Leigh_Olaotan_301920357_Setup.md).

## Current checkpoint and sources

Step 10 is complete. Step 11 will record independent-session visibility, blocking and invariant checks; no concurrency outcome is asserted by the single-session results above.

PostgreSQL 17: [transaction isolation](https://www.postgresql.org/docs/17/transaction-iso.html), [explicit locks](https://www.postgresql.org/docs/17/explicit-locking.html), and [safe SECURITY DEFINER functions](https://www.postgresql.org/docs/17/sql-createfunction.html#SQL-CREATEFUNCTION-SECURITY). The [complete library example](https://github.com/arizonal2014/Harrison_Perete_202600001/tree/4d924b3d1b736881dd20b8e8247a1dde890df7e7/portfolio-3-transactions-concurrency) informed labelled commit/rollback and A/B evidence. Its library operations/data/output were not imported. Codex authored, executed and verified this shop implementation; student review and individual reflection remain pending.
