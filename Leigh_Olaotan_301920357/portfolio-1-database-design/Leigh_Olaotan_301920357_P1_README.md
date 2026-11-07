# Portfolio 1: Database Design and Modelling

Harbour Office Supplies is the shared case for the five portfolio components.

## Current evidence

| Document                                                                                                                                 | Contents                                                                                                  |
| ---------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| [Case study](Leigh_Olaotan_301920357_P1_CaseStudy.md)                                                                                    | Users, operations, scope and business rules BR01-BR09.                                                    |
| [Relational design](Leigh_Olaotan_301920357_P1_Design.md)                                                                                | Five relations, all 25 attributes, keys, data types, optionality and rule enforcement.                    |
| [ER diagram](Leigh_Olaotan_301920357_P1_ERDiagram.md)                                                                                    | Mermaid diagram, relationship cardinalities and a notation guide.                                         |
| [Executable schema](Leigh_Olaotan_301920357_P1_Schema.sql)                                                                               | Atomic creation of five tables with named keys and checks.                                                |
| [Schema output](Leigh_Olaotan_301920357_P1_SchemaOutput.txt)                                                                             | Actual creation, 25-column catalogue, 31 named constraints and 11 supporting indexes.                     |
| [Seed script](Leigh_Olaotan_301920357_P1_SeedData.sql) and [seed output](Leigh_Olaotan_301920357_P1_SeedOutput.txt)                      | 39 fictional rows and checked order/payment/stock reconciliation.                                         |
| [Integrity tests](Leigh_Olaotan_301920357_P1_ConstraintTests.sql) and [actual results](Leigh_Olaotan_301920357_P1_ConstraintResults.txt) | Exact rejection diagnostics, valid boundaries, unchanged-row check and known workflow gaps.               |
| [Replay verification](Leigh_Olaotan_301920357_P1_Verification.txt)                                                                       | Fresh database, different identity values, equivalent records and safe rerun failures.                    |
| [Normalisation](Leigh_Olaotan_301920357_P1_Normalisation.md)                                                                             | Fictional records, functional dependencies and the progression from a repeated group to 1NF, 2NF and 3NF. |

Steps 4-6 are implemented and verified: design, schema, fictional data and row/key
integrity tests. The design explicitly distinguishes row/key constraints from the
transaction logic required for stock reservation, cancellation and payment. Illustrative
normalisation records are not database output.

## Design review

The dictionary and diagram use the same five entities and 25 attributes. The
normalisation examples preserve three order lines, with totals NGN 4,300 and NGN 1,000.
The only nullable field is the conditional cancellation time. The minimum of one order
line and payment/total equality remain operation rules; a foreign key alone cannot
enforce them.

Codex drafted these artefacts, executed the SQL and tests in the local practice
container, compared all 25 implemented columns with the design dictionary and performed
an independent database replay. Student understanding and personal review must be
recorded when that review takes place; it is not assumed here.

## Environment

See [setup instructions](../Leigh_Olaotan_301920357_Setup.md) and
[actual connection checks](../Leigh_Olaotan_301920357_EnvironmentChecks.txt).

## Schema implementation

Executed against `mit8103_portfolio` on PostgreSQL 17.11; the output records the server
timestamp. The implementation has five primary keys, six unique constraints, four
foreign keys, sixteen CHECK constraints and 24 NOT NULL attributes. All four foreign
keys restrict referenced updates and deletes. The eleven initial indexes support
primary/unique keys; no performance experiment has occurred yet.

Small validation clarifications are reflected in the dictionary: event timestamps must
be finite, monetary values exclude NaN, and stored email addresses contain no
whitespace. The five-entity design is unchanged. Status and cancellation checks are
independent so a rejection identifies the intended rule.

From this component directory, with a fresh database selected:

```sh
psql -X -v ON_ERROR_STOP=1 -d mit8103_portfolio -f Leigh_Olaotan_301920357_P1_Schema.sql
```

Use the host, port and authentication instructions in the setup document. For the
existing local container, from the repository root:

```sh
/Users/user/.docker/bin/docker exec -i mit8103-postgres \
  psql -X -v ON_ERROR_STOP=1 -U mit8103_admin -d mit8103_portfolio \
  < Leigh_Olaotan_301920357/portfolio-1-database-design/Leigh_Olaotan_301920357_P1_Schema.sql
```

The schema script deliberately fails if these tables already exist; it does not reset a
populated database. Create/select a separate empty practice database for a replay. Row
constraints cannot guarantee an order contains a line, reserve or restore stock, freeze
historical details, or validate a payment against another table. These operations are
covered by the later P3 workflows linked below.

## Fictional dataset

The seed contains 6 customers, 8 products, 8 orders, 13 order lines and 4 payments. The
stored identities are generated; scripts resolve relationships through customer codes,
SKUs and order numbers. All personal details are fictional and email addresses use
`example.com`.

| Fixture feature               | Example and purpose                                                                                                   |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Paid orders                   | O1001, O1003, O1005 and O1006; payment amounts equal their derived line totals.                                       |
| Placed but unpaid orders      | O1002 and O1007; support missing-payment queries.                                                                     |
| Cancelled orders              | O1004 and O1008; retained lines, valid cancellation times and no payments.                                            |
| Customer without orders       | C006; useful for an outer join or NOT EXISTS query.                                                                   |
| Product without order lines   | FLD01; distinguish catalogue entries from sales activity.                                                             |
| Zero and last-unit stock      | ENV01 has 0 units; MRK01 has 1 unit for a later competing-order experiment.                                           |
| Inactive product with history | CAL01 appears in O1006; the fixture assumes deactivation happened afterwards. No activation-history table is claimed. |
| Historical price              | O1001 retains PEN01 at NGN 900 while the current catalogue price is NGN 1,000.                                        |

The seed is a consistent snapshot. Opening quantities are PEN01=23, PAP01=12, NTB01=17,
STP01=6, ENV01=2, MRK01=2, CAL01=4 and FLD01=30. Subtracting quantities on placed orders
gives the stored available stock; cancelled orders contribute zero net reservation.
These opening quantities are fixture assumptions checked by the seed script, not an
executed stock ledger. The seed also verifies that every order has lines and each
payment has valid status, timing and amount before committing. Those checks validate
this load only.

## Integrity results and interpretation

The saved run on PostgreSQL 17.11 produced:

| Category                            | Observed result                                                                         |
| ----------------------------------- | --------------------------------------------------------------------------------------- |
| Invalid operations                  | 78 correctly rejected, with SQLSTATE and exact table/constraint or column checked.      |
| Valid row-level boundaries/defaults | 8 accepted with returned values checked, then rolled back.                              |
| Fixture preservation                | Every column of all 39 rows matched the pre-test snapshot.                              |
| Known workflow boundaries           | 6 gaps confirmed; these are documented limitations, not successful business operations. |
| Declared-constraint coverage        | All 31 named constraints and all 24 required columns exercised.                         |

For example, a negative stock value fails with `23514` and
`ck_product_stock_nonnegative`; a second payment for an order fails with `23505` and
`uq_payment_order`. Missing parents and referenced-parent changes produce `23503`.
Required-field tests expect `23502` plus the exact column. This avoids counting an
unrelated error as evidence that the intended rule works.

Coverage also includes composite-key duplicates, whitespace-only names/references,
unnormalised email, zero/negative/NaN monetary values, zero/negative line quantity,
invalid status, cancellation chronology and infinite event times. Accepted row-level
checks cover generated IDs, default stock/status/time, the smallest positive stored
price, non-unique display names and cancellation at the placement timestamp. They
validate stored-value boundaries; they do not demonstrate the complete order workflow.

The temporary test helpers use PL/pgSQL exception subtransactions to undo each probe. An
unexpected acceptance, wrong diagnostic or changed fixture aborts the script. The final
transaction is rolled back; test tables/functions do not become application objects.
PostgreSQL identity sequences are not rolled back, so the tests can leave gaps. IDs are
identifiers, not a promise of consecutive numbering, and no sequence was reset in the
primary database.

### Rules still requiring Portfolio 3

The six probes show that direct SQL can create a header without lines, edit a placed
line price, record a wrong payment total, record an early payment, pay a cancelled
order, or add an inactive product to a line. Each probe is rolled back. Stock
reservation/restoration, paid-order cancellation prevention, immutable history and
concurrent placement/payment/cancellation also require the planned transaction controls.
These P1 results cover the base schema; the later P3 section below links the implemented
and tested restricted workflows.

## Reproduction and verification

On a fresh database, run the scripts in this order from this component directory, with
connection/authentication configured as described in setup:

```sh
psql -X -v ON_ERROR_STOP=1 -d mit8103_portfolio -f Leigh_Olaotan_301920357_P1_Schema.sql
psql -X -v ON_ERROR_STOP=1 -d mit8103_portfolio -f Leigh_Olaotan_301920357_P1_SeedData.sql
psql -X -v ON_ERROR_STOP=1 -d mit8103_portfolio -f Leigh_Olaotan_301920357_P1_ConstraintTests.sql
```

The existing `mit8103_portfolio` database already contains this schema and fixture. Do
not rerun creation/loading there. The tests alone can be rerun while the fixture is
unchanged. With the current Docker setup, this command runs them from the repository
root:

```sh
/Users/user/.docker/bin/docker exec -i mit8103-postgres \
  psql -X -v ON_ERROR_STOP=1 -U mit8103_admin -d mit8103_portfolio \
  < Leigh_Olaotan_301920357/portfolio-1-database-design/Leigh_Olaotan_301920357_P1_ConstraintTests.sql
```

A new database named `mit8103_p1_replay_20261104` was used for independent verification
and removed afterwards. The saved schema was executed there, then the
customer/product/order/payment identities were started at 1001/2001/3001/4001 before
loading. The seed and all tests passed. Every business field and relationship matched
the primary fixture despite different generated IDs. A separate post-session comparison
confirmed unchanged rows. Repeating schema creation and seed loading both failed with
the expected messages and psql exit code 3, leaving all records unchanged. The
[verification record](Leigh_Olaotan_301920357_P1_Verification.txt) contains actual
outcomes and SHA-256 hashes of the tested scripts.

The schema/seed/result text files are actual local psql output; the verification record
is produced by automated replay checks. Expected rejection messages are part of
successful tests, not hidden execution failures. No screenshot is substituted for the
executable evidence. This establishes P1 reproducibility on the existing PostgreSQL
server; it does not complete the later whole-portfolio verification stage.

## Sources and assistance

- PostgreSQL 17: [constraints](https://www.postgresql.org/docs/17/ddl-constraints.html),
  [numeric types](https://www.postgresql.org/docs/17/datatype-numeric.html),
  [PL/pgSQL error trapping and diagnostics](https://www.postgresql.org/docs/17/plpgsql-control-structures.html#PLPGSQL-ERROR-TRAPPING),
  and [sequence behaviour](https://www.postgresql.org/docs/17/functions-sequence.html).
- The student-group
  [portfolio generator reference at the reviewed revision](https://github.com/arizonal2014/MIT8103_Portfolio_Generator/tree/7b738abea6d261cc787f09a8465dc2db097f1003)
  informed the use of precise rejection diagnostics and before/after state checks. The
  shop schema, fixture and tests were authored for this case; the generator was not
  executed or imported.
- Codex assisted with implementation, test design, local execution, documentation and
  verification. These statements describe assistant-performed work. Student review,
  personal understanding and the final reflection remain to be recorded by the student.

## Later workflow implementation

The P1 outputs and base database above preserve the original row/key checkpoint. The six
workflow gaps identified here are now addressed for the restricted practice role in the
separate
[P3 implementation and evidence](../portfolio-3-transactions-concurrency/Leigh_Olaotan_301920357_P3_README.md).
P3 includes atomic placement, payment/cancellation coordination and denied direct
history edits; administrator bypass limits are explicit. Earlier P1 gap probes are
historical evidence, not claims about the later restricted interface.
