# Portfolio 5 Distributed and Cloud Databases

Harbour Office Supplies must have correct stock and payment records. It also must have access to order history when a server fails. This portfolio proposes a database design for these requirements.

The assessment permits a discussion or a setup. This work uses the discussion option. The proposed system has not been deployed. The current system uses local PostgreSQL and one local MongoDB server.

## Documents

| Document | Content |
| --- | --- |
| [Architecture](Leigh_Olaotan_301920357_P5_Architecture.md) | Current system, proposed servers, data flow and a diagram. |
| [Discussion](Leigh_Olaotan_301920357_P5_DistributedDiscussion.md) | Replication, server failure, consistency, sharding, security, backup and cost. |
| [Technical terms](../Leigh_Olaotan_301920357_Terms.md) | Definitions for database terms used in this portfolio. |

## Main decision

Keep PostgreSQL as the system that controls stock, orders and payments. Use MongoDB for order events. Replication must operate separately in each database system. MongoDB replication does not copy PostgreSQL records.

The proposal uses a PostgreSQL primary and a synchronous standby. It also uses three MongoDB members in separate failure zones. Sharding is not necessary for the current 14-event example.

These components would add cost and maintenance work. The proposal describes a future shop service. It does not recommend this cost for the current local exercise.

## Basis of the discussion

The proposal uses the [P3 transaction results](../portfolio-3-transactions-concurrency/Leigh_Olaotan_301920357_P3_README.md) and the [P4 event model](../portfolio-4-nosql/Leigh_Olaotan_301920357_P4_Model.md). The discussion links the official PostgreSQL and MongoDB documentation near each technical claim.

The failure cases are design analysis. They are not measured test results. No cloud account, replica set, failover test or backup restore was created for P5.
