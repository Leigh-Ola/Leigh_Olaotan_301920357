# Harbour Office Supplies: case study

Harbour Office Supplies is a fictional Nigerian online stationery retailer with one
stockroom. The database records customers, products, orders, order lines and successful
payment records. All example personal and commercial records are fictional. The currency
is Nigerian naira (NGN).

## Users and operations

Customers place orders and receive an order reference. Sales staff register customers,
maintain catalogue prices, place orders and record full payments. Stock staff check
available quantities and process permitted cancellations. The owner reviews sales,
unpaid orders and stock levels. These are business roles; an authentication application
is outside the current scope.

The principal operations are customer registration, product maintenance, placing a
multi-product order, recording its payment, cancelling an unpaid order, checking stock
and reporting sales. MongoDB can represent order events for this same business; it is
not an unrelated second case study.

## Business rules

| Rule | Required behaviour                                                                                                                                                                                                                                                                             |
| ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| BR01 | Each customer has a unique customer code and unique normalised email. Customer names and identifiers cannot be blank.                                                                                                                                                                          |
| BR02 | Each product has a unique SKU, a nonblank name, a positive current unit price and a nonnegative whole-number quantity available for sale. A product may be deactivated without removing its history.                                                                                           |
| BR03 | Each order has a unique order number and belongs to exactly one existing customer. Customer identity and order time are retained after placement.                                                                                                                                              |
| BR04 | A successfully placed order contains at least one line. Each line references an existing product, has a positive whole-number quantity and a positive unit price fixed at order placement. The same product appears at most once in an order.                                                  |
| BR05 | Placing an order checks product activity and sufficient stock, reduces available stock and saves all order records in one transaction. A failure leaves neither a partial order nor a partial stock reduction. Competing orders cannot reduce stock below zero.                                |
| BR06 | Line quantities and agreed unit prices remain unchanged after placement. Later catalogue-price changes do not change historical order values. The order total is calculated from its lines rather than maintained as a second stored total.                                                    |
| BR07 | An order is either placed or cancelled. Only a placed order with no recorded payment may be cancelled. Cancellation records its time, restores its stock exactly once and retains its lines. Its time cannot precede placement.                                                                |
| BR08 | An order has zero or one successful full payment. Each payment has a unique reference, a positive amount equal to the order total, and a payment time on or after placement. A cancelled order cannot receive a payment. Payment recording and cancellation must coordinate on the same order. |
| BR09 | Paid/unpaid is derived from payment existence rather than stored as a second order-status flag. Customer, product, order and payment identifiers retain their meaning; referenced records and completed history are not routinely deleted.                                                     |

## Scope and assumptions

There is one stockroom and one currency. Initial available stock is part of the
controlled fictional dataset; an auditable purchasing/restocking system is outside this
portfolio. Prices exclude tax, delivery charges and discounts. A historical line price
may differ from today's catalogue price because the catalogue can change over time.
Orders use catalogue prices at placement.

This model records successful full payments only. Failed payment attempts, partial
payments, refunds, online payment gateways, shipping, customer login and multiple
warehouses are outside scope. A payment entry is a fictional business record, not a
financial transaction with a provider. Placed order lines are immutable; cancellation
preserves them rather than editing them.

The design supports relational modelling, SQL sales/availability reports, atomic order
placement, concurrent stock access, MongoDB order-event documents and a case-specific
distributed-database discussion. Source SQL implementation and execution results are
separate portfolio evidence; this case description does not claim those exercises have
run.

## Sources and assistance

The case scope and business rules are developed for this portfolio. The supplied Miva
MIT 8103 assessment defines the portfolio deliverables. The external
[MIT8103 codelab](https://github.com/arizonal2014/MIT8103_Codelab/tree/619af2bb8394ad020fc29223acaedf80f3423a61)
informed the organisation of the work. Its library schema, sample data and results are
not used as this shop's implementation. Codex assisted with drafting and consistency
review; this is not a claim that the student has independently verified implementation
results.
