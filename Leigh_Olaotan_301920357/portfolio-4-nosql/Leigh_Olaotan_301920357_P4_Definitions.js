// Shared mongosh definitions. Loading this file does not write to a database.
// Fixtures reconstruct P1 sample history; they are not a live SQL integration.
globalThis.ShopEvents = (() => {
  const collectionName = "order_events";
  const text = { bsonType: "string", pattern: "\\S" };
  const money = {
    bsonType: "decimal",
    minimum: NumberDecimal("0"),
    exclusiveMinimum: true,
    maximum: NumberDecimal("999999999999.99"),
  };
  const object = (properties) => ({
    bsonType: "object",
    required: Object.keys(properties),
    additionalProperties: false,
    properties,
  });
  const itemSchema = object({
    sku: { bsonType: "string", pattern: "^[A-Z]{3}[0-9]{2}$" },
    product_name: text,
    quantity: { bsonType: "int", minimum: 1, maximum: 2147483647 },
    unit_price: money,
  });
  const detailSchemas = {
    order_placed: object({
      channel: { enum: ["web"] },
      currency: { enum: ["NGN"] },
      items: { bsonType: "array", minItems: 1, items: itemSchema },
    }),
    payment_recorded: object({
      payment_reference: { bsonType: "string", pattern: "^PAY[0-9]{4}$" },
      amount: money,
      currency: { enum: ["NGN"] },
      method: { enum: ["bank_transfer", "card"] },
    }),
    order_cancelled: object({
      reason_code: { enum: ["customer_request", "duplicate_order"] },
      note: text,
    }),
  };
  const schema = object({
    _id: { bsonType: "string", pattern: "^EV[0-9]{3}$" },
    schema_version: { bsonType: "int", enum: [1] },
    source: { enum: ["manual_fixture"] },
    event_type: { enum: Object.keys(detailSchemas) },
    occurred_at: { bsonType: "date" },
    order_number: { bsonType: "string", pattern: "^O[0-9]{4}$" },
    customer: object({
      customer_code: { bsonType: "string", pattern: "^C[0-9]{3}$" },
      full_name: text,
    }),
    details: { bsonType: "object" },
  });
  schema.oneOf = Object.entries(detailSchemas).map(([type, details]) => ({
    properties: { event_type: { enum: [type] }, details },
  }));
  const collectionOptions = {
    validator: { $jsonSchema: schema },
    validationLevel: "strict",
    validationAction: "error",
  };
  const indexes = [
    {
      key: { order_number: 1, event_type: 1 },
      name: "unique_order_event",
      unique: true,
    },
    {
      key: { order_number: 1, occurred_at: 1, _id: 1 },
      name: "order_history",
    },
  ];
  const customers = {
    C001: "Ada Ojo",
    C002: "Ben Eze",
    C003: "Chika Nwosu",
    C004: "Dami Bello",
    C005: "Efe Okoro",
  };
  const products = {
    PEN01: "Pen pack",
    PAP01: "Paper ream",
    NTB01: "Notebook",
    STP01: "Stapler",
    ENV01: "Envelope pack",
    MRK01: "Marker",
    CAL01: "Calculator",
  };
  function event(id, type, order, customer, time, details) {
    return {
      _id: id,
      schema_version: NumberInt(1),
      source: "manual_fixture",
      event_type: type,
      occurred_at: ISODate(time),
      order_number: order,
      customer: { customer_code: customer, full_name: customers[customer] },
      details,
    };
  }
  function placed(id, order, customer, time, lines) {
    return event(id, "order_placed", order, customer, time, {
      channel: "web",
      currency: "NGN",
      items: lines.map(([sku, quantity, price]) => ({
        sku,
        product_name: products[sku],
        quantity: NumberInt(quantity),
        unit_price: NumberDecimal(price),
      })),
    });
  }
  function paid(id, order, customer, time, reference, amount, method) {
    return event(id, "payment_recorded", order, customer, time, {
      payment_reference: reference,
      amount: NumberDecimal(amount),
      currency: "NGN",
      method,
    });
  }
  function cancelled(id, order, customer, time, reason, note) {
    return event(id, "order_cancelled", order, customer, time, {
      reason_code: reason,
      note,
    });
  }
  // Dates, references, prices and quantities match the P1 fixture. Methods,
  // channel and cancellation explanations are invented descriptive examples.
  const documents = [
    placed("EV001", "O1001", "C001", "2026-11-01T08:00:00Z", [
      ["PEN01", 2, "900.00"],
      ["PAP01", 1, "2500.00"],
    ]),
    paid(
      "EV002",
      "O1001",
      "C001",
      "2026-11-01T08:10:00Z",
      "PAY5001",
      "4300.00",
      "bank_transfer",
    ),
    placed("EV003", "O1002", "C002", "2026-11-02T09:00:00Z", [["PEN01", 1, "1000.00"]]),
    placed("EV004", "O1003", "C003", "2026-11-02T10:00:00Z", [
      ["NTB01", 3, "1500.00"],
      ["STP01", 1, "3500.00"],
    ]),
    paid(
      "EV005",
      "O1003",
      "C003",
      "2026-11-02T10:05:00Z",
      "PAY5003",
      "8000.00",
      "card",
    ),
    placed("EV006", "O1004", "C001", "2026-11-02T11:00:00Z", [["PAP01", 2, "2500.00"]]),
    cancelled(
      "EV007",
      "O1004",
      "C001",
      "2026-11-03T08:00:00Z",
      "customer_request",
      "Fictional customer changed the requested stationery.",
    ),
    placed("EV008", "O1005", "C004", "2026-11-03T09:00:00Z", [
      ["ENV01", 2, "1200.00"],
      ["MRK01", 1, "1800.00"],
    ]),
    paid(
      "EV009",
      "O1005",
      "C004",
      "2026-11-03T09:05:00Z",
      "PAY5005",
      "4200.00",
      "bank_transfer",
    ),
    placed("EV010", "O1006", "C005", "2026-11-03T10:00:00Z", [["CAL01", 1, "8000.00"]]),
    paid(
      "EV011",
      "O1006",
      "C005",
      "2026-11-03T10:05:00Z",
      "PAY5006",
      "8000.00",
      "card",
    ),
    placed("EV012", "O1007", "C002", "2026-11-04T08:00:00Z", [
      ["PAP01", 1, "2500.00"],
      ["NTB01", 2, "1500.00"],
    ]),
    placed("EV013", "O1008", "C003", "2026-11-04T09:00:00Z", [
      ["PEN01", 1, "1000.00"],
      ["STP01", 1, "3500.00"],
    ]),
    cancelled(
      "EV014",
      "O1008",
      "C003",
      "2026-11-04T10:00:00Z",
      "duplicate_order",
      "Fictional duplicate order cancelled before payment.",
    ),
  ];
  function check(condition, message) {
    if (!condition) throw new Error(message);
  }
  function canonical(value) {
    function ordered(item) {
      if (Array.isArray(item)) return item.map(ordered);
      if (item !== null && typeof item === "object") {
        return Object.fromEntries(
          Object.keys(item)
            .sort()
            .map((key) => [key, ordered(item[key])]),
        );
      }
      return item;
    }
    return JSON.stringify(ordered(EJSON.serialize(value, { relaxed: false })));
  }
  function equal(actual, expected, message) {
    check(canonical(actual) === canonical(expected), message);
  }
  function clone(value) {
    return EJSON.parse(EJSON.stringify(value, { relaxed: false }), { relaxed: false });
  }
  function section(label, value) {
    print("\n" + label);
    print(EJSON.stringify(value, null, 2, { relaxed: true }));
  }
  async function context() {
    check(
      /^mit8103_order_events(?:_[a-z0-9_]+)?$/.test(db.getName()),
      "Select a mit8103_order_events practice database explicitly in the connection URI.",
    );
    const hello = await db.adminCommand({ hello: 1 });
    check(
      hello.msg !== "isdbgrid",
      "This local exercise is not a sharded-cluster setup.",
    );
    section("Execution environment", {
      executed_at: new Date(),
      database: db.getName(),
      server_version: await db.version(),
      topology: hello.setName ? "replica set " + hello.setName : "standalone",
    });
    return db.getCollection(collectionName);
  }
  return {
    collectionName,
    collectionOptions,
    indexes,
    documents,
    check,
    canonical,
    equal,
    clone,
    section,
    context,
  };
})();
