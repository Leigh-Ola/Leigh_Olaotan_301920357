# Order-event document model

Harbour Office Supplies uses PostgreSQL for operational customer, catalogue, order, stock and payment records. Portfolio 4 adds a separate MongoDB history of fictional order events for the same case. It answers questions such as “what happened to O1001?”, “which events concern C003?” and “which payment events describe bank transfers?”.

The database is `mit8103_order_events`; its collection is `order_events`. One document represents one placement, successful payment or cancellation. The fixture reconstructs the eight P1 orders as 14 events: eight placements, four payments and two cancellations. It is a manually entered teaching fixture, not an automatically generated audit trail.

## Document boundary and fields

| Field | Stored type and purpose |
| --- | --- |
| `_id` | String event identifier, EV001–EV014 in this fixture. Identifies an event, not an order. |
| `schema_version` | BSON Int32, value 1. Makes the document contract explicit. |
| `source` | `manual_fixture`. Prevents the examples being mistaken for a live integration. |
| `event_type` | `order_placed`, `payment_recorded` or `order_cancelled`. |
| `occurred_at` | BSON Date, expressed in UTC. History sorts by date and then `_id` for deterministic ties. |
| `order_number` | Business reference to a P1 order, such as O1001. MongoDB does not enforce a SQL foreign key. |
| `customer` | Embedded customer code and name snapshot. The code references P1; the copied name makes the history readable. |
| `details` | Embedded fields specific to the event type, described below. |

Placement details contain `channel`, `currency` and an `items` array. Each item embeds SKU, product name, whole-number quantity and the price agreed at placement. Payment details contain reference, amount, currency and method. Cancellation details contain a reason code and explanatory note. A payment document does not have to use an empty item array, and a placement document does not have to use meaningless cancellation fields.

Money uses BSON Decimal128, preserving decimal values; quantities use BSON Int32. For O1001, two pen packs at NGN 900 plus one paper ream at NGN 2,500 total NGN 4,300. The placement document does not store a second order-total field. Its NGN 900 pen price is historical even though the current P1 catalogue price is NGN 1,000, consistent with BR06. Payment amount is the successful payment fact, matching BR08 in this fixture.

The [example document](Leigh_Olaotan_301920357_P4_ExampleDocument.json) illustrates EV001 using MongoDB Extended JSON: `$date`, `$numberInt` and `$numberDecimal` keep the intended types when decoded with `EJSON.parse`. A plain JSON date string is not a BSON Date. The executable definitions use `ISODate`, `NumberInt` and `NumberDecimal`. The verification tests that the decoded example equals the stored EV001 document.

## Why embed some information and reference other information?

Customer names, product names and line prices are snapshots read with an event. Embedding them makes a complete event understandable without fetching several related documents. The order number, customer code and SKU remain useful business references. A later PostgreSQL change does not update these copies automatically. The copies keep historical facts. They are not synchronised master data.

Each event has its own document. The model does not keep an increasing event array inside one order. History can grow by adding documents and can be queried across orders by customer or event type. Placement items belong together and are embedded within that bounded business operation. Production systems would still need an order-size limit: MongoDB's document size limit is not a replacement for application input limits.

MongoDB supports embedding or references according to the access pattern. Here the choice supports event-history reads and varying event details; it does not show that MongoDB is faster than a relational event table. [MongoDB data modelling](https://www.mongodb.com/docs/v7.0/core/data-model-design/).

## Fixture source record

Order numbers, customer names/codes, dates, cancellation times, line quantities/prices, payment references and amounts match the [P1 seed](../portfolio-1-database-design/Leigh_Olaotan_301920357_P1_SeedData.sql). The implementation is tested against the actual kept PostgreSQL fixture as well.

Payment methods, web channel and cancellation explanations are invented descriptive examples; P1 does not store those fields. All records are fictional. This snapshot covers the P1 orders, not the later TX-/CC- practice transactions in P3. C006 has no P1 orders and consequently no events; the unused FLD01 product has no placement item.

## Validator and indexes

The collection uses `$jsonSchema` with `validationLevel: "strict"` and `validationAction: "error"`. Required fields, BSON types, not blank names, identifier patterns, positive amounts/quantities and permitted event values are tested. `oneOf` selects the appropriate details schema. Unexpected fields are rejected at each defined object boundary. These choices show controlled document variation, not an absence of schema. Adding an event type requires an intentional schema update. [MongoDB validation](https://www.mongodb.com/docs/v7.0/core/schema-validation/), [$jsonSchema](https://www.mongodb.com/docs/v7.0/reference/operator/query/jsonschema/).

| Index | Reason |
| --- | --- |
| `_id_` (unique) | Prevents repeated event IDs. It does not itself implement safe retry handling. |
| `unique_order_event`: `{ order_number: 1, event_type: 1 }`, unique | Permits one placement, one successful payment and one cancellation event per order in this model. It does not permit an arbitrary stream of repeated payment attempts. |
| `order_history`: `{ order_number: 1, occurred_at: 1, _id: 1 }` | Equality on order number followed by chronological history with a stable tie-breaker. |

The history query's actual execution plan is recorded with its results. A separate hinted diagnostic shows index compatibility. Neither is a measured performance improvement over a baseline; 14 events are too small for that claim. Other queries may scan this tiny collection. More indexes would consume storage and add write work without an established need. No TTL index is used to expire historical events. [Compound indexes](https://www.mongodb.com/docs/v7.0/core/indexes/index-types/index-compound/), [unique indexes](https://www.mongodb.com/docs/v7.0/core/index-unique/).

## Limits and suitability

The tested validator enforces structure and field values. It does not query PostgreSQL or compare a payment with another event's item total. It does not reject payment after cancellation.

It does not test the time order between events. It does not enforce distinct SKU values in an array. Four isolated tests deliberately confirm these limits.

The fixture itself satisfies the shop rules, but accepting this fixture is not proof that each future event will do so.

The scripts add history without modifying existing events. Append-only history is a convention here: database roles preventing updates/deletes have not been installed. Schema validation does not provide immutability or customer authorisation. The fixed identifier patterns suit this small fixture; a production namespace would need a larger identifier design and a versioned migration plan.

PostgreSQL remains responsible for stock reservation and full-payment/cancellation rules. MongoDB is a suitable separate read model for flexible event details. A production publisher, retries, deduplication, comparison and operational access controls would need separate design and testing. There is no cross-database transaction or automatic synchronisation in P4, and the observed local standalone server is not a distributed deployment. These boundaries inform the later P5 discussion.

## Sources and assistance

The codelab's [MongoDB event exercise](https://github.com/arizonal2014/MIT8103_Codelab/blob/619af2bb8394ad020fc29223acaedf80f3423a61/17_Model_And_Query_MongoDB.md) informed the event-history approach. The library fixture and results were not imported. More reference: [MongoDB Extended JSON](https://www.mongodb.com/docs/v7.0/reference/mongodb-extended-json/).
