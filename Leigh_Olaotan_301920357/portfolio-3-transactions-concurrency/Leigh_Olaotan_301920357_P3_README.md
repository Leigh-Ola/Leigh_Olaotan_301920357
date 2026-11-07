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

Steps 10-11 are complete. The single-session results above establish commit/rollback and workflow checks; the independent-session evidence below establishes the stated concurrency and isolation results.

PostgreSQL 17: [transaction isolation](https://www.postgresql.org/docs/17/transaction-iso.html), [explicit locks](https://www.postgresql.org/docs/17/explicit-locking.html), and [safe SECURITY DEFINER functions](https://www.postgresql.org/docs/17/sql-createfunction.html#SQL-CREATEFUNCTION-SECURITY). The [complete library example](https://github.com/arizonal2014/Harrison_Perete_202600001/tree/4d924b3d1b736881dd20b8e8247a1dde890df7e7/portfolio-3-transactions-concurrency) informed labelled commit/rollback and A/B evidence. Its library operations/data/output were not imported. Codex authored, executed and verified this shop implementation; student review and individual reflection remain pending.

## Isolation and concurrency results

Step 11 is complete. [Session A](Leigh_Olaotan_301920357_P3_SessionA.sql), [Session B](Leigh_Olaotan_301920357_P3_SessionB.sql), the [automated runner](Leigh_Olaotan_301920357_P3_Concurrency.py) and [actual transcript](Leigh_Olaotan_301920357_P3_ConcurrencyResults.txt) preserve the exact commands, responses, SQLSTATEs and timing. A and B are persistent independent connections; a third administrative connection observes lock waits and final invariants.

| Scenario | Actual sequence and result |
| --- | --- |
| Last unit of MRK01 | A reserves its one available unit but does not commit. B still reads stock=1 and sees no A order, then waits on A's product lock. The observer confirms B is blocked by A's actual backend PID. After A commits, B rechecks stock=0, raises P3002 and rolls back. Exactly one new order/line reserves one unit; B leaves no partial order. |
| Payment wins | A records the full payment on CC-PAY-FIRST while holding its order lock. B's cancellation waits. After A commits, B sees the payment and rejects with P3005. The order stays placed/paid and its stock remains reserved. |
| Cancellation wins | A cancels CC-CANCEL-FIRST and restores its unit while holding its order lock. B's payment waits. After A commits, B sees cancelled status and rejects with P3004. No payment exists, and stock was restored once. |
| READ COMMITTED visibility | B reads PEN01 stock=18. A reserves a pen without committing; B still reads 18 and sees no new order. A commits; B's next statement in the same transaction reads 17 and sees the order. B's transaction ID is unchanged across all three reads. This shows absence of dirty reads and a permitted nonrepeatable read. |

The first capture used A PID 31855 and B PID 31862, with observer PID 31876; replay PIDs will differ. Each of the three waits was observed as `wait_event_type=Lock`, `wait_event=transactionid`, with A in `pg_blocking_pids(B)`. The runner waits for this condition before committing A; it does not infer blocking from a fixed delay. Session timeouts and cleanup bound failures.

READ COMMITTED supplies statement snapshots; the product-row lock and post-lock stock check prevent overselling. The shared order lock coordinates payment/cancellation. Isolation level alone does not enforce these business rules, and the experiment does not claim SERIALIZABLE behaviour or protection for arbitrary administrator SQL.

The final separate transaction database contains 6 customers, 8 products, 14 orders, 20 lines and 6 payments (54 rows). There are no empty orders or invalid payments. All eight available stock balances equal the stated opening quantities minus units on placed orders. MRK01=0, PEN01=17, PAP01=9, NTB01=12 and FLD01=29. Both worker transactions are closed before their clients exit.

## Reproduce step 11

First complete step 10 in a new isolated database. The runner refuses existing CC- exercise records or unexpected starting stock. From repository root:

```sh
python3 Leigh_Olaotan_301920357/portfolio-3-transactions-concurrency/Leigh_Olaotan_301920357_P3_Concurrency.py \
  --output temp/logs/p3-new-concurrency.txt
```

Optional flags: `--database NEW_DATABASE`, `--docker /Users/user/.docker/bin/docker`, `--container NAME`, `--user NAME`. It refuses to overwrite the output file. The runner reads the committed A/B blocks directly, ensuring the automation and manual instructions exercise the same SQL. It preserves actual errors and asserts their SQLSTATEs.

For manual execution, open two psql connections and follow this order. Do not execute either complete session file at once.

| Scenario | Interleaving |
| --- | --- |
| Stock | A `STOCK_A_BEGIN`; B `STOCK_B_BEGIN`, then `STOCK_B_ATTEMPT`; inspect blocking; A `STOCK_A_COMMIT`; B receives P3002, then `B_ROLLBACK`. |
| Payment first | A `PAY_PREPARE`, `PAY_A_BEGIN`; B `PAY_B_BEGIN`, `PAY_B_ATTEMPT`; inspect blocking; A `PAY_A_COMMIT`; B receives P3005, then `B_ROLLBACK`. |
| Cancellation first | A `CANCEL_PREPARE`, `CANCEL_A_BEGIN`; B `CANCEL_B_BEGIN`, `CANCEL_B_ATTEMPT`; inspect blocking; A `CANCEL_A_COMMIT`; B receives P3004, then `B_ROLLBACK`. |
| Visibility | B `VIS_B_BEGIN`, `VIS_B_READ`; A `VIS_A_BEGIN`; B `VIS_B_READ`; A `VIS_A_COMMIT`; B `VIS_B_READ`, `VIS_B_COMMIT`. |

Use `SELECT pg_backend_pid();` in each worker. In a third administrative connection, inspect the actual B PID before releasing A:

```sql
SELECT pid, application_name, wait_event_type, wait_event, pg_blocking_pids(pid)
FROM pg_stat_activity
WHERE pid = <B_BACKEND_PID>;
```

Replace the bracketed placeholder with the observed integer; it is explanatory notation, not executable SQL. Expected errors in manual psql must be followed by ROLLBACK. Keep A open until B is observably blocked. Do not reuse a failed/incomplete exercise database as though it had the documented initial state.

## Independent replay

[Verification record](Leigh_Olaotan_301920357_P3_Verification.txt) records a fresh database replay with customer/product/order/payment identities starting at 1001/2001/3001/4001. Workflow installation, all 25 rejection checks and all four concurrency/visibility scenarios passed. Every final business field and relationship matched the first run despite different generated IDs. A freshly loaded P1 seed also matched the untouched original P1 business data. The verification database was removed afterwards; the main P1, benchmark and transaction databases were retained. This is a P2/P3 checkpoint check, not completion of the later whole-portfolio submission review.
