# Portfolio 1: Database Design and Modelling

Harbour Office Supplies is the shared case for the five portfolio components.

## Current evidence

| Document | Contents |
| --- | --- |
| [Case study](Leigh_Olaotan_301920357_P1_CaseStudy.md) | Users, operations, scope and business rules BR01-BR09. |
| [Relational design](Leigh_Olaotan_301920357_P1_Design.md) | Five relations, all 25 attributes, keys, data types, optionality and rule enforcement. |
| [ER diagram](Leigh_Olaotan_301920357_P1_ERDiagram.md) | Mermaid diagram, relationship cardinalities and a notation guide. |
| [Executable schema](Leigh_Olaotan_301920357_P1_Schema.sql) | Atomic creation of five tables with named keys and checks. |
| [Schema output](Leigh_Olaotan_301920357_P1_SchemaOutput.txt) | Actual creation, 25-column catalogue, 31 named constraints and 11 supporting indexes. |
| [Normalisation](Leigh_Olaotan_301920357_P1_Normalisation.md) | Fictional records, functional dependencies and the progression from a repeated group to 1NF, 2NF and 3NF. |

The design and schema checkpoints are complete. Seed data and integrity tests follow in step 6. The design explicitly distinguishes row/key constraints from the transaction logic required for stock reservation, cancellation and payment. Illustrative normalisation records are not database output.

## Design review

The dictionary and diagram use the same five entities and 25 attributes. The normalisation examples preserve three order lines, with totals NGN 4,300 and NGN 1,000. The only nullable field is the conditional cancellation time. The minimum of one order line and payment/total equality remain operation rules; a foreign key alone cannot enforce them.

Codex drafted these artefacts, executed the schema in the local practice container and compared all 25 implemented columns with the design dictionary. Student understanding and personal review must be recorded when that review takes place; it is not assumed here.

## Environment

See [setup instructions](../Leigh_Olaotan_301920357_Setup.md) and [actual connection checks](../Leigh_Olaotan_301920357_EnvironmentChecks.txt).

## Schema implementation

Executed against `mit8103_portfolio` on PostgreSQL 17.11; the output records the server timestamp. The implementation has five primary keys, six unique constraints, four foreign keys, sixteen CHECK constraints and 24 NOT NULL attributes. All four foreign keys restrict referenced updates and deletes. The eleven initial indexes support primary/unique keys; no performance experiment has occurred yet.

Small validation clarifications are reflected in the dictionary: event timestamps must be finite, monetary values exclude NaN, and stored email addresses contain no whitespace. The five-entity design is unchanged. Status and cancellation checks are independent so a rejection identifies the intended rule.

From this component directory, with a fresh database selected:

```sh
psql -X -v ON_ERROR_STOP=1 -d mit8103_portfolio -f Leigh_Olaotan_301920357_P1_Schema.sql
```

Use the host, port and authentication instructions in the setup document. For the existing local container, from the repository root:

```sh
/Users/user/.docker/bin/docker exec -i mit8103-postgres \
  psql -X -v ON_ERROR_STOP=1 -U mit8103_admin -d mit8103_portfolio \
  < Leigh_Olaotan_301920357/portfolio-1-database-design/Leigh_Olaotan_301920357_P1_Schema.sql
```

The schema script deliberately fails if these tables already exist; it does not reset a populated database. Create/select a separate empty practice database for a replay. Row constraints cannot guarantee an order contains a line, reserve or restore stock, freeze historical details, or validate a payment against another table. These operations remain for Portfolio 3.
