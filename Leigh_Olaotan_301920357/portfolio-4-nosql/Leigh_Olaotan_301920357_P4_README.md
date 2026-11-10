# Portfolio 4: NoSQL and Advanced Data Models

The MongoDB model and implementation are verified for Harbour Office Supplies. The existing local MongoDB Community 7.0.43 standalone server stores 14 fictional order events in `mit8103_order_events.order_events`. The work uses the same customers, products and orders as P1; PostgreSQL continues to own the operational business rules.

## Model and suitability

The [model explanation](Leigh_Olaotan_301920357_P4_Model.md) defines one document per event, embedded customer/item snapshots, business references, BSON types, validator, indexes and limitations. The [Extended JSON example](Leigh_Olaotan_301920357_P4_ExampleDocument.json) represents EV001, O1001's placement. A placement embeds its items; payment and cancellation documents have their own details. This supports readable history and varied event information without putting each event into one growing order document.

The fixture has eight placements, four payments and two cancellations, reconstructed manually from P1. Payment methods, channel and cancellation explanations are fictional more details. There is no automatic import, live synchronisation or stock/payment workflow implemented in MongoDB. This is an event-history read model, not a replacement for P3's transaction controls.

## Implementation and observed results

The [shared definitions](Leigh_Olaotan_301920357_P4_Definitions.js) contain the validator, index specifications, fixture and helper functions. The [setup script](Leigh_Olaotan_301920357_P4_MongoDB.js) creates the collection once, applies the rules and inserts the typed documents. The [setup output](Leigh_Olaotan_301920357_P4_SetupOutput.txt) records the actual environment, acknowledged IDs, installed rules/indexes and stored example.

[Executable queries](Leigh_Olaotan_301920357_P4_Queries.js) and [actual query results](Leigh_Olaotan_301920357_P4_QueryResults.txt):

| Query | Business question | Verified result |
| --- | --- | --- |
| Q1 | How many events of each type? | 8 placements, 4 payments, 2 cancellations; 14 total. |
| Q2 | What happened to O1001? | EV001 placement at 08:00 UTC, then EV002 payment at 08:10 UTC on 1 November 2026. |
| Q3 | Which events concern C003? | EV004, EV005, EV013, EV014 in chronological order. |
| Q4 | Which payments describe bank transfers? | EV002: NGN 4,300; EV009: NGN 4,200; total NGN 8,500. Methods are illustrative metadata. |
| Q5 | Which placement has a PEN01 item priced below NGN 1,000? | EV001 only, with the historical NGN 900 price. `$elemMatch` applies both conditions to the same array item. |
| Q6 | What is the exact total of payment events? | Four Decimal128 payments sum to NGN 24,500, agreeing with P1/P2. |
| Q7 | Which orders' latest fixture event is still placement? | O1002 and O1007. This is a result for the complete teaching fixture, not a guarantee of live order status. |

All seven queries have executable expected-result tests. The unhinted Q2 plan used `order_history`, with an IXSCAN and FETCH: two keys and two documents examined for two results. A separately labelled hinted diagnostic returned the same counts. No before/after performance improvement is claimed for this 14-document sample.

## Validation and its limits

[Validation tests](Leigh_Olaotan_301920357_P4_ValidationTests.js) and [actual validation output](Leigh_Olaotan_301920357_P4_ValidationResults.txt) record:

- 18 invalid inserts and one invalid update rejected with MongoDB code 121.
- Duplicate event ID and duplicate order/event type rejected with code 11000; the tests test the specific index key pattern, not merely any error.
- Three accepted structural boundaries: NGN 0.01 payment, the stated maximum payment value and one item with quantity 1 and price NGN 0.01.
- Four explicitly confirmed limitations: no SQL foreign-key lookup, no cross-event full-payment total test, no paid/cancelled exclusion, and no distinct-SKU array rule.

Tests copy the **installed** validator/options and indexes into a uniquely named temporary collection and test the copied configuration. Each rejection leaves all 14 copied fixture documents unchanged. Valid-boundary and limitation probes exist only in that temporary collection, which is removed afterwards. The kept event collection is compared before and after and remains unchanged. These are structural database tests; they do not claim business-workflow enforcement or production authorisation.

The [independent verification](Leigh_Olaotan_301920357_P4_Verification.txt) records a replay in an isolated database. BSON values, the validator and indexes match. The P1 business records and decoded example also match.

Setup rejects an existing collection and a wrong database name. The record includes hashes of the tested scripts. All eight orders, 13 embedded items, four payments and two cancellations were compared.

The temporary replay database was removed; the primary 14-event database remains.

## Reproduce from a new database

Run from the Git repository root with the existing MongoDB service running and `mongosh` on PATH. Use an unused database name beginning with `mit8103_order_events_`. The name below is an example; do not reuse it after a successful or partial setup.

```sh
mongosh --norc --quiet 'mongodb://127.0.0.1:27017/mit8103_order_events_new1?directConnection=true' \
  --file Leigh_Olaotan_301920357/portfolio-4-nosql/Leigh_Olaotan_301920357_P4_MongoDB.js
mongosh --norc --quiet 'mongodb://127.0.0.1:27017/mit8103_order_events_new1?directConnection=true' \
  --file Leigh_Olaotan_301920357/portfolio-4-nosql/Leigh_Olaotan_301920357_P4_Queries.js
mongosh --norc --quiet 'mongodb://127.0.0.1:27017/mit8103_order_events_new1?directConnection=true' \
  --file Leigh_Olaotan_301920357/portfolio-4-nosql/Leigh_Olaotan_301920357_P4_ValidationTests.js
```

Expected completion messages report 14 stored documents, seven verified queries, and 21 rejections/three valid boundaries/four limitations. The script definitions and output use UTC; all money is NGN. The scripts deliberately use the selected URI database rather than silently writing into mongosh's default `test` database.

To inspect the already-created `mit8103_order_events` database, use that name in the URI with the **Queries** or **ValidationTests** script. Both scripts can run again. Queries only read data. The tests remove their own temporary collection. Do not rerun setup against an existing collection: it refuses even an empty existing collection and never resets it.

Setup has multiple operations and `insertMany` is not a multi-document transaction on this standalone server. An interrupted load can leave a partial new collection. Inspect the failure and choose a new practice database; the script does not silently retry or delete records. Query assertions intentionally require the exact fixture.

See [local setup](../Leigh_Olaotan_301920357_Setup.md) for service details. No new MongoDB installation, replica set, sharded cluster or cloud deployment was created. The original P1–P3 database records and captured evidence were kept.

## Sources and assistance

The [model document](Leigh_Olaotan_301920357_P4_Model.md) links the MongoDB documentation and the codelab reference used. Script execution follows the official [mongosh script guidance](https://www.mongodb.com/docs/mongodb-shell/write-scripts/).
