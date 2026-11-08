// Test the installed rules on an isolated temporary collection in this DB.
// The retained order_events fixture is never updated or deleted by this script.
(async () => {
  await load(
    "Leigh_Olaotan_301920357/portfolio-4-nosql/Leigh_Olaotan_301920357_P4_Definitions.js",
  );
  const S = ShopEvents;
  const events = await S.context();
  const original = await events.find().sort({ _id: 1 }).toArray();
  S.equal(original, S.documents, "Run tests against the unmodified fixture.");
  const info = (await db.getCollectionInfos({ name: S.collectionName }))[0];
  S.equal(
    info.options,
    S.collectionOptions,
    "Installed validator/options differ from the documented rules.",
  );
  const installedIndexes = await events.getIndexes();
  const scratchName =
    "order_events_validation_" + require("crypto").randomUUID().replaceAll("-", "");
  const scratch = db.getCollection(scratchName);
  let created = false;
  let rejected = 0;
  const outcomes = [];
  function probe(base, number) {
    const document = S.clone(original[base]);
    document._id = "EV" + (900 + number);
    document.order_number = "O" + (9000 + number);
    return document;
  }
  try {
    S.check(
      (await db.getCollectionInfos({ name: scratchName })).length === 0,
      "Temporary collection already exists.",
    );
    await db.createCollection(scratchName, info.options);
    created = true;
    for (const index of installedIndexes.filter((entry) => entry.name !== "_id_")) {
      const options = { name: index.name };
      if (index.unique) options.unique = true;
      await scratch.createIndex(index.key, options);
    }
    S.equal(
      (await scratch.getIndexes()).map(({ key, name, unique }) => ({
        key,
        name,
        unique,
      })),
      installedIndexes.map(({ key, name, unique }) => ({ key, name, unique })),
      "Temporary index definitions differ from the installed indexes.",
    );
    await scratch.insertMany(original);
    async function reject(label, operation, expectedCode, expectedKey) {
      let caught;
      try {
        await operation();
      } catch (error) {
        caught = error;
      }
      S.check(
        caught && caught.code === expectedCode,
        label +
          ": expected MongoDB error " +
          expectedCode +
          ", got " +
          (caught ? caught.code + ": " + caught.message : "success"),
      );
      if (expectedKey)
        S.equal(caught.keyPattern, expectedKey, label + ": wrong unique index.");
      S.equal(
        await scratch.find().sort({ _id: 1 }).toArray(),
        original,
        label + ": rejected operation changed stored data.",
      );
      outcomes.push({
        test: label,
        outcome: "PASS",
        actual_code: caught.code,
        message: caught.message,
      });
      rejected++;
    }
    const invalid = [
      [
        "Missing order number",
        0,
        (d) => {
          delete d.order_number;
        },
      ],
      [
        "String instead of BSON date",
        0,
        (d) => {
          d.occurred_at = "2026-11-01T08:00:00Z";
        },
      ],
      [
        "Unknown top-level field",
        0,
        (d) => {
          d.unexpected = true;
        },
      ],
      [
        "Unknown event type",
        0,
        (d) => {
          d.event_type = "order_shipped";
        },
      ],
      [
        "Blank customer name",
        0,
        (d) => {
          d.customer.full_name = "   ";
        },
      ],
      [
        "Missing payment reference",
        1,
        (d) => {
          delete d.details.payment_reference;
        },
      ],
      [
        "String payment amount",
        1,
        (d) => {
          d.details.amount = "4300.00";
        },
      ],
      [
        "Zero payment amount",
        1,
        (d) => {
          d.details.amount = NumberDecimal("0");
        },
      ],
      [
        "Non-finite payment amount",
        1,
        (d) => {
          d.details.amount = NumberDecimal("NaN");
        },
      ],
      [
        "Negative quantity",
        0,
        (d) => {
          d.details.items[0].quantity = NumberInt(-1);
        },
      ],
      [
        "Fractional quantity",
        0,
        (d) => {
          d.details.items[0].quantity = 1.5;
        },
      ],
      [
        "Empty item array",
        0,
        (d) => {
          d.details.items = [];
        },
      ],
      [
        "Unknown nested item field",
        0,
        (d) => {
          d.details.items[0].stock = 100;
        },
      ],
      [
        "Wrong currency",
        1,
        (d) => {
          d.details.currency = "USD";
        },
      ],
      [
        "Mismatched event details",
        6,
        (d) => {
          d.details = S.clone(original[1].details);
        },
      ],
      [
        "Unknown cancellation reason",
        6,
        (d) => {
          d.details.reason_code = "unspecified";
        },
      ],
      [
        "Malformed customer code",
        0,
        (d) => {
          d.customer.customer_code = "missing";
        },
      ],
      [
        "Missing schema version",
        0,
        (d) => {
          delete d.schema_version;
        },
      ],
    ];
    for (const [number, [label, base, mutate]] of invalid.entries()) {
      const document = probe(base, number + 1);
      mutate(document);
      await reject(label, () => scratch.insertOne(document), 121);
    }
    const duplicateId = probe(0, 30);
    duplicateId._id = "EV001";
    await reject("Duplicate event ID", () => scratch.insertOne(duplicateId), 11000, {
      _id: 1,
    });
    const duplicateStage = probe(0, 31);
    duplicateStage.order_number = "O1001";
    await reject(
      "Duplicate order/event combination",
      () => scratch.insertOne(duplicateStage),
      11000,
      { order_number: 1, event_type: 1 },
    );
    await reject(
      "Invalid update is rejected too",
      () =>
        scratch.updateOne(
          { _id: "EV001" },
          { $set: { "details.items.0.quantity": NumberInt(0) } },
        ),
      121,
    );
    S.section(
      "Rejection checks; each left all 14 scratch documents unchanged",
      outcomes,
    );

    const smallPayment = probe(1, 40);
    smallPayment.details.amount = NumberDecimal("0.01");
    const maximumPayment = probe(1, 41);
    maximumPayment.details.amount = NumberDecimal("999999999999.99");
    const oneItem = probe(0, 42);
    oneItem.details.items = [
      {
        ...oneItem.details.items[0],
        quantity: NumberInt(1),
        unit_price: NumberDecimal("0.01"),
      },
    ];
    for (const document of [smallPayment, maximumPayment, oneItem]) {
      await scratch.insertOne(document);
      S.equal(
        await scratch.findOne({ _id: document._id }),
        document,
        "Valid boundary did not retain its BSON values.",
      );
    }
    S.section(
      "Three accepted structural boundaries (not proof of valid order workflow)",
      [smallPayment, maximumPayment, oneItem],
    );

    // Deliberately show where structural validation stops. These are admitted
    // only to the temporary collection and are removed with it below.
    const orphan = probe(1, 80);
    orphan.customer = {
      customer_code: "C999",
      full_name: "Fictional unknown customer",
    };
    const wrongTotal = probe(1, 81);
    wrongTotal.order_number = "O1002";
    wrongTotal.customer = S.clone(original[2].customer);
    wrongTotal.details.amount = NumberDecimal("1.00");
    const paidCancelled = probe(1, 82);
    paidCancelled.order_number = "O1004";
    const repeatedSku = probe(0, 83);
    repeatedSku.details.items = [
      repeatedSku.details.items[0],
      { ...repeatedSku.details.items[0], quantity: NumberInt(3) },
    ];
    const limitations = [
      ["No SQL foreign-key lookup: unknown order/customer accepted", orphan],
      ["No cross-event full-payment total check: NGN 1 for O1002 accepted", wrongTotal],
      [
        "No cross-event paid/cancelled exclusion: payment for O1004 accepted",
        paidCancelled,
      ],
      ["No distinct-SKU rule within an item array: repeated SKU accepted", repeatedSku],
    ];
    for (const [label, document] of limitations) {
      await scratch.insertOne(document);
      S.equal(await scratch.findOne({ _id: document._id }), document, label);
    }
    S.section(
      "Four confirmed limitations; not successful business-rule enforcement",
      limitations.map(([test, document]) => ({
        test,
        temporary_id: document._id,
        outcome: "LIMITATION CONFIRMED",
      })),
    );
    S.check(rejected === 21, "Unexpected rejection-test count.");
  } finally {
    if (created) {
      S.check(
        await scratch.drop(),
        "Could not remove our temporary validation collection.",
      );
      print("Removed only temporary collection " + scratchName);
    }
  }
  S.equal(
    await events.find().sort({ _id: 1 }).toArray(),
    original,
    "Retained events changed during validation checks.",
  );
  print(
    "PASS: 21 rejections, 3 valid structural boundaries, 4 documented limitations; retained 14-event fixture unchanged.",
  );
})();
