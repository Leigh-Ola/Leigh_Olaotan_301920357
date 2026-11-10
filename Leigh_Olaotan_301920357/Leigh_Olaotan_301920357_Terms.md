# Technical Terms

These definitions apply to this database portfolio. Code names, commands and captured output keep their original spelling. The descriptions use the same term for the same database concept.

| Term | Meaning in this portfolio |
| --- | --- |
| Atomic transaction | A transaction that saves all its changes or none of them. |
| Attribute | A named item of data in a relation. A SQL column stores an attribute. |
| Baseline | The measurement made before the candidate index was added. |
| Benchmark | A controlled database performance test. |
| BSON | The format MongoDB uses to store documents and their data types. |
| Candidate key | One or more attributes that uniquely identify a row, with no unnecessary attribute. |
| Cardinality | The permitted number of related records. |
| Collection | A group of MongoDB documents. |
| Commit | The operation that saves a transaction's changes. |
| Concurrency | Operations from different sessions that occur during the same time interval. |
| Constraint | A database rule that limits permitted values or relationships. |
| Decimal128 | A MongoDB decimal data type. The event model uses it for money. |
| Denormalisation | The deliberate storage of repeated data to support a data access pattern. |
| Event | A record of an order placement, successful payment or cancellation. |
| Execution plan | The database operations selected to answer a query. |
| Failover | A change from a failed primary server to another server. |
| Fencing | A control that prevents an old primary from accepting writes after failover. |
| Fixture | A fixed set of fictional records for repeatable tests. |
| Foreign key | A constraint that links a child row to an existing parent key. |
| Functional dependency | A rule in which one attribute set determines another attribute set. |
| Hash | A calculated value used to detect a change in file content. |
| Index | A database structure that can reduce the work necessary to find or order data. |
| Isolation level | A rule for the data that one transaction can see while other transactions run. |
| Journal | A MongoDB record of changes used for recovery. |
| Majority | More than half the voting members. The proposed three-member replica set must have two votes. |
| Median | The middle value after the measurements are put in order. |
| NGN | Nigerian naira, the currency used for all prices and payments. |
| Normalisation | The use of data dependencies to reduce repeated facts and update problems. |
| Outbox | A proposed PostgreSQL table that stores events until a publisher delivers them. |
| Primary key | The selected key that identifies each row. It cannot be null. |
| Primary server | The server that accepts writes for its replication group. |
| Query | A request for data from a database. |
| Read concern | The MongoDB setting that controls which versions of data a read can return. |
| Replica set | A group of MongoDB servers that keep copies of the same data. |
| Replication | The process that copies database changes to other servers. |
| Rollback | The operation that removes a transaction's changes. |
| Row lock | A database control that coordinates competing changes to a row. |
| Schema | The structure and rules for database records. |
| Secondary | A MongoDB member that copies data from the replica set. |
| Shard | A part of a divided MongoDB data set, stored by a replica set. |
| Sharding | The division of data across shards. |
| SKU | Stock keeping unit. The shop uses this product code as a unique business reference. |
| Snapshot | Data as seen at a particular point in time. |
| SQLSTATE | A PostgreSQL code that identifies an error class or a defined application error. |
| Standby | A PostgreSQL server that receives changes and can take the primary role after promotion. |
| Synchronous replication | Replication in which commit confirmation waits for a specified standby response. |
| TLS | Transport Layer Security. It protects data during network transfer. |
| UTC | Coordinated Universal Time. The scripts use this time reference. |
| Validator | MongoDB rules that reject documents with invalid structure or values. |
| WAL | Write-ahead log. PostgreSQL uses these change records for recovery and replication. |
| Write concern | The MongoDB setting that specifies the confirmation necessary for a write. |

Technical verbs include `commit`, `rollback`, `query`, `index`, `replicate`, `execute`, `validate`, `insert`, `update` and `delete`. They refer to database operations. They do not change the names or behaviour of the submitted commands.
