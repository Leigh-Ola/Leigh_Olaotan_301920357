# Distributed Database Discussion

## Decision for the shop

Harbour Office Supplies must have correct stock and payment records during concurrent orders. PostgreSQL will remain the authority for these records. MongoDB will store order events for history queries.

The [architecture](Leigh_Olaotan_301920357_P5_Architecture.md) proposes database copies in separate failure zones. The current exercise has only local database services. All failure cases below describe expected behaviour, not completed tests.

## MongoDB replication and failure

The proposed replica set has three voting members that store data. One member is primary. The other two members copy its operations. Two members form a majority. The extra copies let the set continue after one member fails, if the remaining members can communicate and complete an election. [Replication](https://www.mongodb.com/docs/v7.0/replication/) and [elections](https://www.mongodb.com/docs/v7.0/core/replica-set-elections/).

Suppose M-A fails while it is primary. M-B and M-C can elect a new primary if they are eligible and can communicate. Writes pause during the election. The publisher must reconnect and retry safely. Staff may see delayed event history. The proposal does not promise a fixed failover time.

If M-A becomes isolated, it cannot keep the primary role without a majority. The side with M-B and M-C can elect a primary. If only one member remains reachable, the set cannot elect a primary. The publisher must keep its undelivered events. [Election behaviour](https://www.mongodb.com/docs/v7.0/core/replica-set-elections/).

## Write confirmation and reads

The proposal uses `w: "majority"`, `j: true` and a finite `wtimeout` for event writes. In this three-member set, two data-bearing voting members must confirm the write. Journaling saves the required changes in their journals. This reduces the risk of losing a confirmed event after one server fails. [Write concern](https://www.mongodb.com/docs/v7.0/reference/write-concern/).

A timeout does not prove that the write failed. MongoDB does not undo the write because its confirmation timed out. The publisher must inspect the stable event ID before it retries. Test driver timeouts and retry limits before deployment. A write concern timeout does not limit each stage of a request. [Timeout behaviour](https://www.mongodb.com/docs/v7.0/reference/write-concern/#wtimeout).

History reads would use the primary and `readConcern: "majority"`. This avoids reading changes that lack majority confirmation. It does not guarantee the newest PostgreSQL state. A delayed publisher can leave MongoDB behind even when replication works correctly.

Secondary reads can also return older data because replication takes time. A client that must read its own event write must have a causally consistent session with suitable read and write concerns. These settings do not create a transaction across PostgreSQL and MongoDB. [Read consistency](https://www.mongodb.com/docs/v7.0/core/read-isolation-consistency-recency/).

The design prefers confirmed event data over writes without a majority. It accepts a pause during a partition. PostgreSQL remains the source for stock and payment decisions. The event history is allowed to arrive later.

## PostgreSQL availability

The proposed PostgreSQL primary sends WAL records to a standby in another zone. Use synchronous replication with the standby selected in `synchronous_standby_names`. Use `synchronous_commit = on` for order transactions. Commit confirmation then waits for the selected standby to save the WAL records to durable storage. [Synchronous replication](https://www.postgresql.org/docs/17/warm-standby.html#SYNCHRONOUS-REPLICATION).

This choice adds network delay. If the only synchronous standby is unavailable, commits can wait. The service must report the delay and determine the transaction outcome before a retry. It must not silently change to weaker confirmation.

Asynchronous replication would reduce this dependency. However, a primary failure could lose changes that had not reached the standby. For this shop, a lost order or payment record is more serious than a short pause. [Replication tradeoffs](https://www.postgresql.org/docs/17/warm-standby.html).

PostgreSQL does not provide the complete failure detection and failover controller. A managed service or a separate controller must do that work. Before standby promotion, it must prevent the old primary from accepting writes. This control is called fencing. It prevents two servers from acting as independent primaries. [PostgreSQL failover](https://www.postgresql.org/docs/17/warm-standby-failover.html).

After promotion, the service must reconnect and resolve uncertain transaction outcomes. It must restore a suitable standby before it resumes the same confirmation policy. Replication does not replace the P3 stock locks or full-payment tests.

## Sharding decision

Replication stores copies of the same data. Sharding divides a collection across servers. Each MongoDB shard is itself a replica set. A sharded system also uses query routers and configuration servers. [MongoDB sharding](https://www.mongodb.com/docs/v7.0/sharding/).

The current example contains only 14 events. It does not show a need for sharding. Add suitable indexes and measure actual load before this change. More shards would increase cost and operating work.

Future tests must compare storage size, query delay and write load with service targets. An order-number shard key could keep order-history queries together. However, increasing order numbers could concentrate new writes. Tests must also include customer queries.

A hashed key could spread writes but would change index and uniqueness choices. MongoDB 7.0 restricts unique indexes on sharded collections. The shard key must be a prefix of most unique indexes. Hashed indexes cannot be unique. Inspect the existing `unique_order_event` index before any sharding change. [Unique index restrictions](https://www.mongodb.com/docs/v7.0/core/index-unique/#sharded-clusters).

No shard key is selected here. The current data is too small to support that decision. The shop should keep the unsharded collection until measurements justify the added system.

## Security and recovery

Use private database addresses. Permit connections only from the required services. Use TLS for network traffic. Give each service its own account. Permit only the necessary operations. Keep passwords and keys outside Git.

The event publisher must have event insertion and read access for duplicate tests. It should not have unrestricted update or delete access. The current local practice accounts do not implement this production access policy. [MongoDB security guidance](https://www.mongodb.com/docs/v7.0/administration/security-checklist/).

Replication also copies an accidental deletion. It is therefore not a backup. Keep protected backups in a separate recovery location. For PostgreSQL, combine base backups with an unbroken WAL archive. This permits recovery to a selected time when the required backup and log records are available. [PostgreSQL recovery](https://www.postgresql.org/docs/17/continuous-archiving.html).

Use a supported consistent backup method for MongoDB. Keep the validator, indexes and event data. Test the restore in an isolated environment. Compare restored events with the PostgreSQL outbox and business records. [MongoDB backup methods](https://www.mongodb.com/docs/v7.0/core/backups/).

The owner must set acceptable data loss and service recovery time. No measured recovery target is claimed here. A future restore test must record the last recoverable transaction and the actual time necessary to restore service.

## Cost and acceptance tests

The proposal uses five database members, service capacity, backup storage and network traffic. Monitoring, security updates and restore tests add operating work. A managed service can reduce some administration. It does not remove application retry, data validation or restore responsibilities.

No provider or paid plan has been selected. Compare actual costs when the required capacity and recovery targets are known. These services are not necessary for the current local exercise.

Before a real deployment, complete these tests:

1. Stop one MongoDB member and record election and write behaviour.
2. Remove majority access and confirm that event writes stop safely.
3. Restore access and confirm that each event arrives once in the final history.
4. Fail the PostgreSQL primary and test fencing before promotion.
5. Test stock and payment rules after recovery.
6. Restore both databases from backups in an isolated environment.
7. Compare restored records and report any lost or delayed events.

These are proposed acceptance tests. They have not been executed for this discussion. The completed P3 and P4 results remain the evidence for the local work.
