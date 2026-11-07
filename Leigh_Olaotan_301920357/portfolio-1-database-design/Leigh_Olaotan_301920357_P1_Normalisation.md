# Harbour Office Supplies: normalisation

These are fictional explanatory records, not database execution results. The same two
orders and three order lines are used throughout. Dates are shortened for readability;
implementation uses timestamps. All amounts are NGN.

## Assumptions and dependencies

Each order number identifies one order, each customer code one customer, and each SKU
one product. A product appears at most once in an order, so `(order_number, sku)`
identifies a line. Names are not identifiers. The catalogue price can change; the
historical price on an order line cannot.

Relevant functional dependencies are:

```text
order_number -> customer_code, ordered_at, order_status, cancelled_at
customer_code -> full_name, email
sku -> product_name, current_unit_price, stock_quantity, is_active
(order_number, sku) -> quantity, unit_price_at_order
payment_reference -> order_number, paid_at, amount
order_number -> payment_reference, paid_at, amount  [within successful payments only]
```

The last dependency follows from the scope of at most one successful payment per order;
it does not require every order to have a payment.

## Starting record with a repeated list

| Order | Date       | Customer | Name/email                   | Items                                                                                           |
| ----- | ---------- | -------- | ---------------------------- | ----------------------------------------------------------------------------------------------- |
| O1001 | 2026-11-01 | C001     | Ada Ojo; ada.ojo@example.com | PEN01: Pen pack, quantity 2, agreed price 900; PAP01: Paper ream, quantity 1, agreed price 2500 |
| O1002 | 2026-11-02 | C002     | Ben Eze; ben.eze@example.com | PEN01: Pen pack, quantity 1, agreed price 1000                                                  |

O1001 includes a repeated group of items in one cell. Searching or updating one line
inside that list is awkward. At the time of this illustrative catalogue snapshot,
PEN01's current price is 1000, PAP01's is 2500, and available quantities are 20 and 10
respectively.

## First normal form: one line per row

Split the item list into individual rows with atomic values. The following two displays
are column groups of the same initial 1NF relation, shown separately for readability.

| order_number | sku   | ordered_at | customer_code | full_name | email               |
| ------------ | ----- | ---------- | ------------- | --------- | ------------------- |
| O1001        | PEN01 | 2026-11-01 | C001          | Ada Ojo   | ada.ojo@example.com |
| O1001        | PAP01 | 2026-11-01 | C001          | Ada Ojo   | ada.ojo@example.com |
| O1002        | PEN01 | 2026-11-02 | C002          | Ben Eze   | ben.eze@example.com |

| order_number | sku   | product_name | current_unit_price | stock_quantity | quantity | unit_price_at_order |
| ------------ | ----- | ------------ | -----------------: | -------------: | -------: | ------------------: |
| O1001        | PEN01 | Pen pack     |               1000 |             20 |        2 |                 900 |
| O1001        | PAP01 | Paper ream   |               2500 |             10 |        1 |                2500 |
| O1002        | PEN01 | Pen pack     |               1000 |             20 |        1 |                1000 |

Key: `(order_number, sku)`. Orders are placed and products active in these examples;
`order_status`, `cancelled_at` and `is_active` are omitted from displayed rows only.
Repeating customer and catalogue facts creates update anomalies. For example, PEN01's
name must be corrected in every line where it appears.

## Second normal form: remove partial dependencies

A non-key attribute must depend on the whole candidate key, not only one part. Order
date and customer details depend on `order_number` alone. Product name, current price
and stock depend on `sku` alone. Quantity and the agreed historical price belong to the
particular order-product pair.

Move order and product facts out of the line relation.

### Order details (key: order_number)

| order_number | ordered_at | customer_code | full_name | email               |
| ------------ | ---------- | ------------- | --------- | ------------------- |
| O1001        | 2026-11-01 | C001          | Ada Ojo   | ada.ojo@example.com |
| O1002        | 2026-11-02 | C002          | Ben Eze   | ben.eze@example.com |

### Product (key: sku)

| sku   | product_name | current_unit_price | stock_quantity |
| ----- | ------------ | -----------------: | -------------: |
| PEN01 | Pen pack     |               1000 |             20 |
| PAP01 | Paper ream   |               2500 |             10 |

### Order line (key: order_number + sku)

| order_number | sku   | quantity | unit_price_at_order |
| ------------ | ----- | -------: | ------------------: |
| O1001        | PEN01 |        2 |                 900 |
| O1001        | PAP01 |        1 |                2500 |
| O1002        | PEN01 |        1 |                1000 |

The shared order date and catalogue details no longer repeat on each line.
`unit_price_at_order` stays with the line: PEN01 has different historical prices in the
two orders, so SKU alone does not determine it.

## Third normal form: remove transitive dependencies

The order relation still contains `order_number -> customer_code -> full_name, email`.
Customer contact details describe the customer, not a particular order. Move them to
`customer`, retaining the customer reference in the order.

The implementation design uses generated IDs while keeping the natural identifiers
unique. The illustrative ID values below explain the links; future seed scripts must
resolve actual generated IDs rather than assume these values.

### customer

| customer_id (PK) | customer_code (UK) | full_name | email (UK)          |
| ---------------: | ------------------ | --------- | ------------------- |
|                1 | C001               | Ada Ojo   | ada.ojo@example.com |
|                2 | C002               | Ben Eze   | ben.eze@example.com |

### product

| product_id (PK) | sku (UK) | product_name | unit_price | stock_quantity | is_active |
| --------------: | -------- | ------------ | ---------: | -------------: | --------- |
|              10 | PEN01    | Pen pack     |       1000 |             20 | true      |
|              11 | PAP01    | Paper ream   |       2500 |             10 | true      |

### sales_order

| order_id (PK) | order_number (UK) | customer_id (FK) | ordered_at | order_status | cancelled_at |
| ------------: | ----------------- | ---------------: | ---------- | ------------ | ------------ |
|           100 | O1001             |                1 | 2026-11-01 | placed       | NULL         |
|           101 | O1002             |                2 | 2026-11-02 | placed       | NULL         |

### order_item

Key: `(order_id, product_id)`; both components are foreign keys.

| order_id | product_id | quantity | unit_price_at_order |
| -------: | ---------: | -------: | ------------------: |
|      100 |         10 |        2 |                 900 |
|      100 |         11 |        1 |                2500 |
|      101 |         10 |        1 |                1000 |

Customer details are stored once per customer, current product facts once per product,
and each historical price once per line. Joins on the keys reconstruct the order
information. Introducing generated IDs is a key-design choice; the dependency-based
separation is what removes the anomalies.

## Payment as a separate optional fact

The payment record is independently keyed rather than repeated on each order line. O1001
has one successful full payment; O1002 has none. A natural payment relation contains
`(payment_reference, order_number, paid_at, amount)`. Both `payment_reference` and
`order_number` are candidate keys under the one-payment rule, and each determines its
non-key facts. There is no partial or non-key transitive dependency to remove under
these stated assumptions.

The final payment relation introduces `payment_id` and replaces the natural order
reference with `order_id`, preserving uniqueness on both the order reference and payment
reference:

| payment_id (PK) | order_id (FK, UK) | payment_reference (UK) | paid_at                    | amount |
| --------------: | ----------------: | ---------------------- | -------------------------- | -----: |
|             500 |               100 | PAY5001                | 2026-11-01 after placement |   4300 |

The displayed time is explanatory wording, not an executable timestamp. O1001's amount
is `(2 * 900) + (1 * 2500) = 4300`; O1002's unpaid total is `1 * 1000 = 1000`. No row
with empty payment values is needed for the unpaid order. The stored payment amount is
the settlement fact, verified against the immutable line total by the payment operation.

## Final consistency and remaining rules

The five final relations match the [ER diagram](Leigh_Olaotan_301920357_P1_ERDiagram.md)
and [data dictionary](Leigh_Olaotan_301920357_P1_Design.md). The final displays include
every proposed attribute, using abbreviated dates only.

Under the stated dependencies, customer, product and sales_order facts depend on their
candidate keys; each order_item fact depends on the complete composite key; and payment
facts depend on its candidate keys. Normalisation does not by itself enforce stock
conservation, at least one line, valid state transitions, payment/total equality, or
race-free operations. Those belong to constraints and transaction/workflow design
described separately.

## Sources and assistance

The supplied assessment requires a normalisation explanation. The
[codelab normalisation example](https://github.com/arizonal2014/MIT8103_Codelab/blob/619af2bb8394ad020fc29223acaedf80f3423a61/Library_Normalisation_Example.md)
informed the progression from a repeated list to dependency-based tables; the shop
records and decomposition here are independently drafted for this case. Codex assisted
with drafting and checking arithmetic and consistency. The sample records are not
evidence of student database execution.
