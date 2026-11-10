# Harbour Office Supplies: case study

Harbour Office Supplies is a fictional Nigerian online stationery retailer with one stockroom. The database records customers, products, orders, order lines and successful payment records. All example personal and commercial records are fictional. The currency is Nigerian naira (NGN).

## Users and operations

Customers place orders and receive an order reference. Sales staff register customers, maintain catalogue prices, place orders and record full payments. Stock staff test available quantities and process permitted cancellations. The owner reviews sales, unpaid orders and stock levels. These are business roles; an authentication application is outside the current scope.

The database supports customer registration and product maintenance. It also supports orders with several products, full payments and unpaid-order cancellations. Staff can inspect stock and sales reports. MongoDB can represent order events for this same business; it is not an unrelated second case study.

## Business rules

| Rule | Required behaviour |
| --- | --- |
| BR01 | Each customer has a unique customer code and unique normalised email. Customer names and identifiers cannot be blank. |
| BR02 | Each product has a unique SKU and a name that is not blank. Its current unit price is positive. Available stock contains zero or more whole units. A product may be deactivated without removing its history. |
| BR03 | Each order has a unique order number and belongs to exactly one existing customer. Customer identity and order time are kept after placement. |
| BR04 | A successfully placed order contains at least one line. Each line refers to an existing product. Its quantity is a positive full number. Its unit price is positive and fixed at order placement. The same product appears at most once in an order. |
| BR05 | Order placement first tests product activity and available stock. It then reduces stock and saves all order records in one transaction. A failure leaves neither a partial order nor a partial stock reduction. Competing orders cannot reduce stock below zero. |
| BR06 | Line quantities and agreed unit prices remain unchanged after placement. Later catalogue-price changes do not change historical order values. The order total is calculated from its lines rather than maintained as a second stored total. |
| BR07 | An order is either placed or cancelled. Only a placed order with no recorded payment may be cancelled. Cancellation records its time, restores its stock exactly once and keeps its lines. Its time cannot precede placement. |
| BR08 | An order has zero or one successful full payment. Each payment has a unique reference. Its positive amount equals the order total. Its payment time is on or after placement. A cancelled order cannot receive a payment. Payment recording and cancellation must coordinate on the same order. |
| BR09 | Paid/unpaid is derived from payment existence rather than stored as a second order-status flag. Customer, product, order and payment identifiers keep their meaning; referenced records and completed history are not routinely deleted. |

## Scope and assumptions

There is one stockroom and one currency. Initial available stock is part of the controlled fictional dataset; an auditable purchasing/restocking system is outside this portfolio. Prices exclude tax, delivery charges and discounts. A historical line price may differ from today's catalogue price because the catalogue can change over time. Orders use catalogue prices at placement.

This model records successful full payments only. Failed payment attempts, partial payments, refunds, online payment gateways, shipping, customer login and multiple warehouses are outside scope. A payment entry is a fictional business record, not a financial transaction with a provider. Placed order lines are immutable; cancellation keeps them rather than editing them.

This case supports all five portfolio activities. These activities cover relational design, SQL reports, transactions, MongoDB events and distributed databases. Source SQL implementation and execution results are separate portfolio evidence; this case description does not claim those exercises have run.

## Sources and assistance

The case scope and business rules are developed for this portfolio. The supplied Miva MIT 8103 assessment defines the portfolio deliverables. The external [MIT8103 codelab](https://github.com/arizonal2014/MIT8103_Codelab/tree/619af2bb8394ad020fc29223acaedf80f3423a61) informed the organisation of the work. Its library schema, sample data and results are not used as this shop's implementation. Codex assisted with drafting and review for consistency, and i independently verified the results.
