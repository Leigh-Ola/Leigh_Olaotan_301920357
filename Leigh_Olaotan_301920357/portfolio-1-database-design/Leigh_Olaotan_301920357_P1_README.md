# Portfolio 1: Database Design and Modelling

Harbour Office Supplies is the shared case for the five portfolio components.

## Current evidence

| Document | Contents |
| --- | --- |
| [Case study](Leigh_Olaotan_301920357_P1_CaseStudy.md) | Users, operations, scope and business rules BR01-BR09. |
| [Relational design](Leigh_Olaotan_301920357_P1_Design.md) | Five relations, all 25 attributes, keys, data types, optionality and rule enforcement. |
| [ER diagram](Leigh_Olaotan_301920357_P1_ERDiagram.md) | Mermaid diagram, relationship cardinalities and a notation guide. |
| [Normalisation](Leigh_Olaotan_301920357_P1_Normalisation.md) | Fictional records, functional dependencies and the progression from a repeated group to 1NF, 2NF and 3NF. |

The design checkpoint is complete. SQL table creation, seed data and integrity tests have not yet been performed. The design explicitly distinguishes row/key constraints from the transaction logic required for stock reservation, cancellation and payment. Illustrative normalisation records are not database output.

## Design review

The dictionary and diagram use the same five entities and 25 attributes. The normalisation examples preserve three order lines, with totals NGN 4,300 and NGN 1,000. The only nullable field is the conditional cancellation time. The minimum of one order line and payment/total equality remain operation rules; a foreign key alone cannot enforce them.

Codex drafted and cross-checked these artefacts. Student understanding and personal review must be recorded when that review takes place; it is not assumed here.

## Environment

See [setup instructions](../Leigh_Olaotan_301920357_Setup.md) and [actual connection checks](../Leigh_Olaotan_301920357_EnvironmentChecks.txt).
