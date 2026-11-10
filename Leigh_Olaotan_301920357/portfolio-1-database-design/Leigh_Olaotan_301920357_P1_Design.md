# Harbour Office Supplies: relational design

Five tables and their row and key constraints are implemented in PostgreSQL 17.11. The fictional data and constraint tests are verified. Workflow transactions are implemented and tested separately in [Portfolio 3](../portfolio-3-transactions-concurrency/Leigh_Olaotan_301920357_P3_README.md). The P1 database contains the schema and seed data without the P3 workflow functions.

This design implements the rules in [the case study](Leigh_Olaotan_301920357_P1_CaseStudy.md). The five relations are `customer`, `product`, `sales_order`, `order_item` and `payment`. Order headers and lines use different tables. This design supports several products in one order. The payment table has no row for an unpaid order.

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
| customer_code | VARCHAR(20) | Yes | UK | Not blank customer-facing identifier. |
| full_name | VARCHAR(120) | Yes | - | Not blank name; not assumed unique. |
| email | VARCHAR(254) | Yes | UK | Not blank, trimmed, lower-case stored address with no whitespace; uniqueness follows this stated normalisation policy. Full email deliverability checking is outside scope. |

### product

| Attribute | PostgreSQL type | Required | Key/default | Meaning and intended validation |
| --- | --- | --- | --- | --- |
| product_id | BIGINT | Yes | Identity PK | Stable internal product identifier. |
| sku | VARCHAR(30) | Yes | UK | Not blank catalogue identifier. |
| product_name | VARCHAR(160) | Yes | - | Not blank display name; not assumed unique. |
| unit_price | NUMERIC(12,2) | Yes | - | Positive finite current catalogue price in NGN. |
| stock_quantity | INTEGER | Yes | Default 0 | Available units; must be at least zero. |
| is_active | BOOLEAN | Yes | Default true | Whether a new order may include the product. |

### sales_order

| Attribute | PostgreSQL type | Required | Key/default | Meaning and intended validation |
| --- | --- | --- | --- | --- |
| order_id | BIGINT | Yes | Identity PK | Stable internal order identifier. |
| order_number | VARCHAR(30) | Yes | UK | Not blank customer-facing order reference. |
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
| unit_price_at_order | NUMERIC(12,2) | Yes | - | Positive finite historical unit price captured at placement, kept after catalogue changes. |

### payment

| Attribute | PostgreSQL type | Required | Key/default | Meaning and intended validation |
| --- | --- | --- | --- | --- |
| payment_id | BIGINT | Yes | Identity PK | Stable internal payment identifier. |
| order_id | BIGINT | Yes | FK to sales_order.order_id; UK | At most one successful payment per order. |
| payment_reference | VARCHAR(40) | Yes | UK | Not blank unique fictional payment reference. |
| paid_at | TIMESTAMPTZ | Yes | - | Finite recorded payment time. The payment operation must compare this time with ordered_at. |
| amount | NUMERIC(14,2) | Yes | - | Positive finite amount in NGN. The payment operation must compare it with the line total. |

Only `sales_order.cancelled_at` can be null. Primary keys remain fixed. Foreign keys use RESTRICT for parent updates and deletes. A child foreign key cannot make an order contain a line.

## Relationships and cardinality

| Parent -> child | Parent participation | Child participation | Enforcement boundary |
| --- | --- | --- | --- |
| customer -> sales_order | Zero or many orders | Exactly one customer | Required FK on sales_order.customer_id. |
| sales_order -> order_item | One or many lines in a completed placement | Exactly one order | FK gives the parent link; successful placement workflow gives the minimum-one-line rule. |
| product -> order_item | Zero or many historical order lines | Exactly one product | Required FK; composite PK prevents duplicate product lines per order. |
| sales_order -> payment | Zero or one payment | Exactly one order | Required unique payment.order_id plus FK. Eligibility and amount/time tests require the order workflow. |

The [ER diagram](Leigh_Olaotan_301920357_P1_ERDiagram.md) expresses these business cardinalities. The one-to-many order-line relationship is an intended completed-order invariant, not a claim that a basic FK enforces it.

## Mapping business rules to intended controls

| Rule | Row/key constraints | More operation control |
| --- | --- | --- |
| BR01 | Customer PK; unique required code/email; not blank text; normalised-email CHECK. | Normalise supplied email before insertion; identity changes need explicit handling. |
| BR02 | Product PK; unique not blank SKU; positive price; stock >= 0; required active flag. | Coordinate product availability and stock during placement; maintain catalogue through defined operations. |
| BR03 | Order PK; unique not blank order number; required customer FK/time. | Keep original customer/time once placed. |
| BR04 | Required line FKs; composite PK; positive quantity and historical price. | Require at least one line and capture the catalogue price at placement. |
| BR05 | Zero or positive stock protects against an invalid resulting row. | One transaction combines stock reservation, order header and lines; use guarded updates or row locking and test affected rows. Roll back the full operation if any product cannot be reserved. |
| BR06 | Positive line values and stable referenced identifiers. | Freeze placed line values through the defined workflow. Derive total with SUM(quantity * unit_price_at_order). |
| BR07 | Allowed status values; conditional cancelled_at nullability and time order. | Lock the order; confirm no payment; restore quantities once; change status in the same transaction. |
| BR08 | Payment PK; unique order/reference; positive amount; required FK/time. | Lock the same order used by cancellation; test placed status, amount equals line total and paid_at >= ordered_at before recording payment. |
| BR09 | Restrict deletion of referenced parents. | Derive payment state; keep history and limit updates/deletes through controlled operations. |

The row/key controls are implemented here; the more operation controls are implemented through the restricted-role workflows in the separate P3 database. Row tests do not enforce sums across child rows or all state transitions. An administrator can use other valid SQL to bypass the workflow. The P3 document explains this access limit. There is no claim of complete production security.

## Design decisions

- Surrogate identity keys keep internal relationships stable; unique business identifiers remain candidate keys. `order_item` uses its meaningful two-column key rather than an unnecessary line ID.
- The current product price and historical order-line price describe different times. Historical price is deliberately kept; an order is not repriced when the catalogue changes.
- The order total and paid/unpaid state are derived. The payment amount is kept as the amount actually recorded for that settlement and is tested against the fixed order total.
- Available stock is stored because order placement must update a shared quantity. With one stockroom, a separate warehouse/inventory table would add no independent fact within this scope.
- NGN is a case-wide assumption, so a repeated currency column is unnecessary here. Exact decimal types store money. A constraint rejects PostgreSQL's special NaN value. NaN would pass a simple greater-than-zero test. Integer quantities prevent fractional units. The payment type has a maximum value. The placement and payment operations must reject totals above that value.
- Finite timestamps represent events; UTC values can be displayed in Africa/Lagos. `cancelled_at` is conditional information, not a second independent status system.

See [normalisation](Leigh_Olaotan_301920357_P1_Normalisation.md) for the dependencies and decomposition supporting this design.

## References

- PostgreSQL 17, [data types](https://www.postgresql.org/docs/17/datatype.html): selected integer, decimal and timestamp types.
- PostgreSQL 17, [constraints](https://www.postgresql.org/docs/17/ddl-constraints.html): primary/foreign/unique keys, required values and limits of row tests.
- PostgreSQL 17, [numeric types](https://www.postgresql.org/docs/17/datatype-numeric.html): exact decimals and special-value comparison semantics.
- The supplied Miva MIT 8103 assessment, pages 1-4, defines the design evidence required. Codex assisted me with design, implementation of the schema i came up with, and catalogue verification. Actual local execution is recorded separately. The AI-use declaration records the student's review and verification.
