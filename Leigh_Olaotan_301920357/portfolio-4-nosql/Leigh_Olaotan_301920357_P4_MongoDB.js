// Run with mongosh from repository root, once in a fresh practice database.
// Never drops, resets, upserts or silently reuses an existing event collection.
(async () => {
  await load(
    "Leigh_Olaotan_301920357/portfolio-4-nosql/Leigh_Olaotan_301920357_P4_Definitions.js",
  );
  const S = ShopEvents;
  const events = await S.context();
  const existing = await db.getCollectionInfos({ name: S.collectionName });
  S.check(
    existing.length === 0,
    "Refusing existing order_events collection; choose a new practice database.",
  );
  await db.createCollection(S.collectionName, S.collectionOptions);
  for (const { key, ...options } of S.indexes) {
    await events.createIndex(key, options);
  }
  // insertMany on a standalone server is not a multi-document transaction.
  // If an unexpected error interrupts this load, inspect it and use a fresh DB.
  const inserted = await events.insertMany(S.documents, { ordered: true });
  S.check(inserted.acknowledged, "Insertion was not acknowledged.");
  S.equal(
    Object.values(inserted.insertedIds),
    S.documents.map((event) => event._id),
    "Unexpected inserted IDs.",
  );
  S.equal(
    await events.find().sort({ _id: 1 }).toArray(),
    S.documents,
    "Stored BSON documents differ from the fixture.",
  );
  S.section("Acknowledged insert", inserted);
  S.section(
    "Installed validation rules",
    (await db.getCollectionInfos({ name: S.collectionName }))[0].options,
  );
  S.section("Installed indexes", await events.getIndexes());
  S.section("Stored example: EV001", await events.findOne({ _id: "EV001" }));
  print(
    "PASS: 14 documents stored with their intended BSON types; no SQL writes or automatic synchronisation.",
  );
})();
