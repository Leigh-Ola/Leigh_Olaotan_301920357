// Read-only queries with independently stated expected business results.
(async () => {
  await load(
    "Leigh_Olaotan_301920357/portfolio-4-nosql/Leigh_Olaotan_301920357_P4_Definitions.js",
  );
  const S = ShopEvents;
  const events = await S.context();
  S.check((await events.countDocuments()) === 14, "Expected the 14-event fixture.");

  const counts = await events
    .aggregate([
      { $group: { _id: "$event_type", count: { $sum: 1 } } },
      { $sort: { _id: 1 } },
    ])
    .toArray();
  S.equal(
    counts,
    [
      { _id: "order_cancelled", count: 2 },
      { _id: "order_placed", count: 8 },
      { _id: "payment_recorded", count: 4 },
    ],
    "Incorrect event counts.",
  );
  S.section("Q1: event counts (14 total)", counts);

  const historyFilter = { order_number: "O1001" };
  const historyProjection = { _id: 1, event_type: 1, occurred_at: 1, details: 1 };
  const historySort = { occurred_at: 1, _id: 1 };
  const history = await events
    .find(historyFilter, historyProjection)
    .sort(historySort)
    .toArray();
  S.equal(
    history.map((event) => [
      event._id,
      event.event_type,
      event.occurred_at.toISOString(),
    ]),
    [
      ["EV001", "order_placed", "2026-11-01T08:00:00.000Z"],
      ["EV002", "payment_recorded", "2026-11-01T08:10:00.000Z"],
    ],
    "Incorrect O1001 chronology.",
  );
  S.section("Q2: complete ordered O1001 event history", history);

  const customer = await events
    .find(
      { "customer.customer_code": "C003" },
      {
        _id: 1,
        order_number: 1,
        event_type: 1,
      },
    )
    .sort({ occurred_at: 1, _id: 1 })
    .toArray();
  S.equal(
    customer.map((event) => event._id),
    ["EV004", "EV005", "EV013", "EV014"],
    "Incorrect customer history.",
  );
  S.section("Q3: nested customer-code lookup for C003", customer);

  const transfers = await events
    .find(
      {
        event_type: "payment_recorded",
        "details.method": "bank_transfer",
      },
      { _id: 1, order_number: 1, details: 1 },
    )
    .sort({ _id: 1 })
    .toArray();
  S.equal(
    transfers.map((event) => [event._id, event.details.amount.toString()]),
    [
      ["EV002", "4300.00"],
      ["EV009", "4200.00"],
    ],
    "Incorrect transfer payments.",
  );
  S.section("Q4: nested payment method (two payments totalling NGN 8,500)", transfers);

  const historicalPrice = await events
    .find(
      {
        event_type: "order_placed",
        "details.items": {
          $elemMatch: { sku: "PEN01", unit_price: { $lt: NumberDecimal("1000.00") } },
        },
      },
      { _id: 1, order_number: 1, "details.items": 1 },
    )
    .sort({ _id: 1 })
    .toArray();
  S.equal(
    historicalPrice.map((event) => event._id),
    ["EV001"],
    "Incorrect historical pen-price result.",
  );
  S.section(
    "Q5: same array element has PEN01 and a price below NGN 1,000",
    historicalPrice,
  );

  const payments = await events
    .aggregate([
      { $match: { event_type: "payment_recorded" } },
      {
        $group: {
          _id: "$details.currency",
          payments: { $sum: 1 },
          amount: { $sum: "$details.amount" },
        },
      },
      { $sort: { _id: 1 } },
    ])
    .toArray();
  S.equal(
    payments.map((row) => [row._id, row.payments, row.amount.toString()]),
    [["NGN", 4, "24500.00"]],
    "Incorrect decimal payment total.",
  );
  S.section("Q6: exact Decimal128 payment total (matches P1/P2)", payments);

  const status = await events
    .aggregate([
      { $sort: { occurred_at: 1, _id: 1 } },
      { $group: { _id: "$order_number", latest_event: { $last: "$event_type" } } },
      { $match: { latest_event: "order_placed" } },
      { $sort: { _id: 1 } },
    ])
    .toArray();
  S.equal(
    status.map((row) => row._id),
    ["O1002", "O1007"],
    "Incorrect fixture orders awaiting payment.",
  );
  S.section(
    "Q7: latest fixture event remains placement (not authoritative live order status)",
    status,
  );

  const explain = await events
    .find(historyFilter, historyProjection)
    .sort(historySort)
    .explain("executionStats");
  S.check(explain.executionStats.nReturned === 2, "Unexpected explain result count.");
  S.section("Unhinted Q2 execution plan; tiny fixture, no performance-speedup claim", {
    winningPlan: explain.queryPlanner.winningPlan,
    nReturned: explain.executionStats.nReturned,
    totalKeysExamined: explain.executionStats.totalKeysExamined,
    totalDocsExamined: explain.executionStats.totalDocsExamined,
  });
  const supported = await events
    .find(historyFilter, historyProjection)
    .sort(historySort)
    .hint("order_history")
    .explain("executionStats");
  S.check(supported.executionStats.nReturned === 2, "History-index diagnostic failed.");
  S.section("Hinted diagnostic: index can satisfy the history access pattern", {
    winningPlan: supported.queryPlanner.winningPlan,
    nReturned: supported.executionStats.nReturned,
    totalKeysExamined: supported.executionStats.totalKeysExamined,
    totalDocsExamined: supported.executionStats.totalDocsExamined,
  });
  print("PASS: all seven query expectations and both plan result counts checked.");
})();
