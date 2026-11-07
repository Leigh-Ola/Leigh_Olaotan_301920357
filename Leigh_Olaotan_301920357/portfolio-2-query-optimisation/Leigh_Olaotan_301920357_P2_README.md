# Portfolio 2: Query Processing and Optimisation

Harbour Office Supplies: business queries on the small fictional P1 fixture, followed by a separate synthetic performance experiment.

## Business questions and observed answers

[Queries](Leigh_Olaotan_301920357_P2_Queries.sql), [actual output](Leigh_Olaotan_301920357_P2_QueryResults.txt) and [independent expected-result checks](Leigh_Olaotan_301920357_P2_QueryVerification.txt).

| Query | Purpose and SQL technique | Verified interpretation |
| --- | --- | --- |
| Q1 | Placed-order summary: joins, grouping and derived payment state. | Six placed orders, four paid and two unpaid. Totals use historical line prices. Cancelled orders are excluded. |
| Q2 | Paid sales by product: joins, SUM and deterministic ranking. | CAL01 leads at NGN 8,000. Seven products contribute NGN 24,500 in total. Inactive products remain in historical sales. |
| Q3 | Outstanding orders: correlated NOT EXISTS plus aggregation. | O1007 owes NGN 5,500 and O1002 NGN 1,000; NGN 6,500 altogether. Cancelled orders are not debts. |
| Q4 | Customer activity: pre-aggregated lines, LEFT JOIN, filtered aggregates and COALESCE. | All six customers appear; C006 has zero orders. Paid value totals NGN 24,500, agreeing with Q2. Pre-aggregation prevents a multi-line order multiplying payment/order counts. |
| Q5 | Reorder list: active-product filtering and a stated five-unit threshold. | ENV01=0, MRK01=1 and STP01=5. Inactive CAL01 is intentionally excluded. The threshold is a reporting choice, not a new stored business rule. |
| Q6 | Never-ordered products: correlated NOT EXISTS. | Only FLD01. This considers all historical lines, including cancelled orders; it is different from asking which products have no paid sales. |

Every returned row/value and its ordering was checked against values independently calculated from the seed records. These results apply to the 39-row P1 fixture; they are not performance measurements. The read-only REPEATABLE READ transaction gives all six statements one consistent snapshot. Neither customer display names nor current product prices are used as historical identifiers/prices.

## Run the queries

With the existing P1 database and Docker container, run from the repository root:

```sh
docker exec -i mit8103-postgres psql -X -v ON_ERROR_STOP=1 \
  -U mit8103_admin -d mit8103_portfolio \
  < Leigh_Olaotan_301920357/portfolio-2-query-optimisation/Leigh_Olaotan_301920357_P2_Queries.sql
```

On this workstation Docker is `/Users/user/.docker/bin/docker` if absent from PATH. Any PostgreSQL 17 connection can instead execute the same file with `psql -X -v ON_ERROR_STOP=1 -d DATABASE -f FILE`. See [setup](../Leigh_Olaotan_301920357_Setup.md) and the [P1 evidence](../portfolio-1-database-design/Leigh_Olaotan_301920357_P1_README.md).

## Current checkpoint and assistance

Step 7 is complete. The larger benchmark, baseline and optimisation comparison follow in steps 8-9. Codex authored and executed these case-specific queries and verified their results. Student review and personal reflection remain to be recorded; no student execution is assumed.
