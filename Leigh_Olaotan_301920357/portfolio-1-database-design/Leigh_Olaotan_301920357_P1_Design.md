# Harbour Office Supplies: relational design

Status: the five tables and row/key constraints are implemented in PostgreSQL 17.11. Workflow transactions are deferred to Portfolio 3; seed and rejection tests follow in step 6.

This design implements the rules in [the case study](Leigh_Olaotan_301920357_P1_CaseStudy.md). The five relations are `customer`, `product`, `sales_order`, `order_item` and `payment`. Separating order headers from lines supports several products per order; separating payment allows an unpaid order without an empty payment row.

## Relational schema

```text
customer(customer_id PK, customer_code UK, full_name, email UK)
product(product_id PK, sku UK, product_name, unit_price, stock_quantity, is_active)
sales_order(order_id PK, order_number UK, customer_id FK, ordered_at,
            order_status, cancelled_at)
order_item(order_id PK/FK, product_id PK/FK, quantity, unit_price_at_order)
payment(payment_id PK, order_id FK/UK, payment_reference UK, paid_at, amount)
```

`order_item` has the composite primary key `(order_id, product_id)`. `PK` identifies a row; `FK` references an existing parent; `UK` is a candidate key enforced by uniqueness and required values. Required unique fields in the dictionary are also NOT NULL.

## Data dictionary

### customer

| Attribute | PostgreSQL type | Required | Key/default | Meaning and intended validation |
| --- | --- | --- | --- | --- |
| customer_id | BIGINT | Yes | Identity PK | Stable internal customer identifier. |
| customer_code | VARCHAR(20) | Yes | UK | Nonblank customer-facing identifier. |
| full_name | VARCHAR(120) | Yes | - | Nonblank name; not assumed unique. |
| email | VARCHAR(254) | Yes | UK | Nonblank, trimmed, lower-case stored address with no whitespace; uniqueness follows this stated normalisation policy. Full email deliverability checking is outside scope. |

### product

| Attribute | PostgreSQL type | Required | Key/default | Meaning and intended validation |
| --- | --- | --- | --- | --- |
| product_id | BIGINT | Yes | Identity PK | Stable internal product identifier. |
| sku | VARCHAR(30) | Yes | UK | Nonblank catalogue identifier. |
| product_name | VARCHAR(160) | Yes | - | Nonblank display name; not assumed unique. |
| unit_price | NUMERIC(12,2) | Yes | - | Positive finite current catalogue price in NGN. |
| stock_quantity | INTEGER | Yes | Default 0 | Available units; must be at least zero. |
| is_active | BOOLEAN | Yes | Default true | Whether a new order may include the product. |

### sales_order

| Attribute | PostgreSQL type | Required | Key/default | Meaning and intended validation |
| --- | --- | --- | --- | --- |
| order_id | BIGINT | Yes | Identity PK | Stable internal order identifier. |
| order_number | VARCHAR(30) | Yes | UK | Nonblank customer-facing order reference. |
| customer_id | BIGINT | Yes | FK to customer.customer_id | Exactly one customer owns the order. |
| ordered_at | TIMESTAMPTZ | Yes | Default CURRENT_TIMESTAMP | Finite placement timestamp. |
| order_status | VARCHAR(10) | Yes | Default placed | Restricted to placed or cancelled. |
| cancelled_at | TIMESTAMPTZ | No | Default NULL | NULL for placed orders; finite and required for cancelled orders, and not before ordered_at. |

### order_item

| Attribute | PostgreSQL type | Required | Key/default | Meaning and intended validation |
| --- | --- | --- | --- | --- |
| order_id | BIGINT | Yes | Composite PK; FK to sales_order.order_id | Parent order. |
| product_id | BIGINT | Yes | Composite PK; FK to product.product_id | Product ordered; at most one line per product in an order. |
| quantity | INTEGER | Yes | - | Units ordered; greater than zero. |
| unit_price_at_order | NUMERIC(12,2) | Yes | - | Positive finite historical unit price captured at placement, retained after catalogue changes. |

### payment

| Attribute | PostgreSQL type | Required | Key/default | Meaning and intended validation |
| --- | --- | --- | --- | --- |
| payment_id | BIGINT | Yes | Identity PK | Stable internal payment identifier. |
| order_id | BIGINT | Yes | FK to sales_order.order_id; UK | At most one successful payment per order. |
| payment_reference | VARCHAR(40) | Yes | UK | Nonblank unique fictional payment reference. |
| paid_at | TIMESTAMPTZ | Yes | - | Finite recorded payment time. Cross-table comparison with ordered_at needs workflow enforcement. |
| amount | NUMERIC(14,2) | Yes | - | Positive finite recorded amount in NGN; equality to the line total needs workflow enforcement. |

The only nullable attribute is `sales_order.cancelled_at`. Primary keys are stable; foreign-key updates and deletion use RESTRICT to protect referenced history. Child foreign keys alone do not ensure an order has any lines.

## Relationships and cardinality

| Parent -> child | Parent participation | Child participation | Enforcement boundary |
| --- | --- | --- | --- |
| customer -> sales_order | Zero or many orders | Exactly one customer | Required FK on sales_order.customer_id. |
| sales_order -> order_item | One or many lines in a completed placement | Exactly one order | FK supplies the parent link; successful placement workflow supplies the minimum-one-line rule. |
| product -> order_item | Zero or many historical order lines | Exactly one product | Required FK; composite PK prevents duplicate product lines per order. |
| sales_order -> payment | Zero or one payment | Exactly one order | Required unique payment.order_id plus FK. Eligibility and amount/time checks require the order workflow. |

The [ER diagram](Leigh_Olaotan_301920357_P1_ERDiagram.md) expresses these business cardinalities. The one-to-many order-line relationship is an intended completed-order invariant, not a claim that a basic FK enforces it.

## Mapping business rules to intended controls

| Rule | Row/key constraints | Additional operation control |
| --- | --- | --- |
| BR01 | Customer PK; unique required code/email; nonblank text; normalised-email CHECK. | Normalise supplied email before insertion; identity changes need explicit handling. |
| BR02 | Product PK; unique nonblank SKU; positive price; stock >= 0; required active flag. | Coordinate product availability and stock during placement; maintain catalogue through defined operations. |
| BR03 | Order PK; unique nonblank order number; required customer FK/time. | Retain original customer/time once placed. |
| BR04 | Required line FKs; composite PK; positive quantity and historical price. | Require at least one line and capture the catalogue price at placement. |
| BR05 | Nonnegative stock protects against an invalid resulting row. | One transaction combines stock reservation, order header and lines; use guarded updates or row locking and check affected rows. Roll back the whole operation if any product cannot be reserved. |
| BR06 | Positive line values and stable referenced identifiers. | Freeze placed line values through the defined workflow. Derive total with SUM(quantity * unit_price_at_order). |
| BR07 | Allowed status values; conditional cancelled_at nullability and chronology. | Lock the order; confirm no payment; restore quantities once; change status in the same transaction. |
| BR08 | Payment PK; unique order/reference; positive amount; required FK/time. | Lock the same order used by cancellation; verify placed status, amount equals line total and paid_at >= ordered_at before recording payment. |
| BR09 | Restrict deletion of referenced parents. | Derive payment state; retain history and limit updates/deletes through controlled operations. |

The row/key controls are implemented; the additional operation controls remain a specification. Row checks do not enforce sums across child rows or all state transitions. A direct administrator can bypass a workflow by issuing other legal SQL; the later implementation must demonstrate its intended operations and describe access-control limitations. There is no claim of complete production security.

## Design decisions

- Surrogate identity keys keep internal relationships stable; unique business identifiers remain candidate keys. `order_item` uses its meaningful two-column key rather than an unnecessary line ID.
- The current product price and historical order-line price describe different times. Historical price is deliberately retained; an order is not repriced when the catalogue changes.
- The order total and paid/unpaid state are derived. The payment amount is retained as the amount actually recorded for that settlement and is checked against the fixed order total.
- Available stock is stored because order placement must update a shared quantity. With one stockroom, a separate warehouse/inventory table would add no independent fact within this scope.
- NGN is a case-wide assumption, so a repeated currency column is unnecessary here. Exact decimal types represent amounts; explicit checks exclude PostgreSQL's special NaN value, which would otherwise pass a simple greater-than-zero check; integer quantities exclude fractional units. Payment capacity is finite, so the placement/payment workflow must reject an order total beyond the chosen amount type's range.
- Finite timestamps represent events; UTC values can be displayed in Africa/Lagos. `cancelled_at` is conditional information, not a second independent status system.

See [normalisation](Leigh_Olaotan_301920357_P1_Normalisation.md) for the dependencies and decomposition supporting this design.

## References

- PostgreSQL 17, [data types](https://www.postgresql.org/docs/17/datatype.html): selected integer, decimal and timestamp types.
- PostgreSQL 17, [constraints](https://www.postgresql.org/docs/17/ddl-constraints.html): primary/foreign/unique keys, required values and limits of row checks.
- PostgreSQL 17, [numeric types](https://www.postgresql.org/docs/17/datatype-numeric.html): exact decimals and special-value comparison semantics.
- The supplied Miva MIT 8103 assessment, pages 1-4, defines the design evidence required. Codex assisted with design, schema implementation and catalogue verification. Actual local execution is recorded separately; personal student review is still pending.
