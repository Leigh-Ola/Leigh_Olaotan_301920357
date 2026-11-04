# Harbour Office Supplies: ER diagram

This logical diagram matches the [data dictionary](Leigh_Olaotan_301920357_P1_Design.md). It describes the business design; the SQL tables are not yet implemented.

[Open the rendered SVG diagram](Leigh_Olaotan_301920357_P1_ERDiagram.svg). It was exported from the Mermaid source below using Mermaid 11.17.2 and visually checked locally.

```mermaid
erDiagram
    direction TB
    customer ||..o{ sales_order : places
    sales_order ||--|{ order_item : contains
    product ||--o{ order_item : appears_on
    sales_order ||..o| payment : receives

    customer {
        bigint customer_id PK
        varchar customer_code UK
        varchar full_name
        varchar email UK
    }
    product {
        bigint product_id PK
        varchar sku UK
        varchar product_name
        numeric unit_price
        integer stock_quantity
        boolean is_active
    }
    sales_order {
        bigint order_id PK
        varchar order_number UK
        bigint customer_id FK
        timestamptz ordered_at
        varchar order_status
        timestamptz cancelled_at "Optional; required when cancelled"
    }
    order_item {
        bigint order_id PK, FK
        bigint product_id PK, FK
        integer quantity
        numeric unit_price_at_order
    }
    payment {
        bigint payment_id PK
        bigint order_id FK, UK
        varchar payment_reference UK
        timestamptz paid_at
        numeric amount
    }
```

`PK` marks a primary-key field, `FK` a foreign key and `UK` a unique candidate key. Both marked fields in `order_item` form one composite primary key; they are not individually unique. Exact lengths, decimal precision and defaults are in the data dictionary.

- Solid lines identify relationships where the parent key forms part of the child primary key (`order_item`). Dashed lines indicate that the child has its own primary key.
- `||` means exactly one, `o|` zero or one, `o{` zero or many, and `|{` one or many.
- A customer may have no orders or several orders. Each order belongs to one customer.
- A successfully placed order contains at least one line. Each line belongs to one order and references one product. A product can appear on many different orders, but only once within one order.
- An order may be unpaid or have one successful full payment. A payment cannot exist without an order.

All attributes are required except `sales_order.cancelled_at`, whose value is conditional on status. The order-lines minimum, stock updates, immutable historical prices, cancellation eligibility and payment amount/time rules require operation logic as described in the design. A foreign key by itself does not enforce those rules.

Example: an order for two pen packs and one paper ream has one `sales_order` row and two `order_item` rows. Both lines reference existing products. Recording the full payment adds one `payment` row; it does not add a paid flag to the order.

Diagram notation: [Mermaid ER syntax](https://mermaid.js.org/syntax/entityRelationshipDiagram.html).
