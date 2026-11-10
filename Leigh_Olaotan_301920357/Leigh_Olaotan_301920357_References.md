# References and Resource Use

The component documents link technical sources near the relevant explanation. This list identifies the main resources and their use. P5 sources were accessed on 8 November 2026.

## Assessment

- Miva Open University. [MIT 8103 Advanced Database Systems CA](https://lms-assets.miva.university/course-materials/mit-8103-advanced-database-systems-ca-september-cohort-2026.pdf). Academic session 2026/2027. Pages 3 to 7 define the portfolio, evidence and AI-use requirements.

## PostgreSQL 17

- [Constraints](https://www.postgresql.org/docs/17/ddl-constraints.html). Keys, required values and row constraints for P1.
- [Using EXPLAIN](https://www.postgresql.org/docs/17/using-explain.html). Query plans and measurements for P2.
- [Multicolumn indexes](https://www.postgresql.org/docs/17/indexes-multicolumn.html). The customer-history index for P2.
- [Transaction isolation](https://www.postgresql.org/docs/17/transaction-iso.html). READ COMMITTED behaviour for P3.
- [Explicit locking](https://www.postgresql.org/docs/17/explicit-locking.html). Row locks for stock and order operations.
- [Standby servers](https://www.postgresql.org/docs/17/warm-standby.html). Streaming and synchronous replication for P5.
- [Failover](https://www.postgresql.org/docs/17/warm-standby-failover.html). Promotion and controls for an old primary.
- [Continuous archiving and recovery](https://www.postgresql.org/docs/17/continuous-archiving.html). Base backups and WAL recovery.

## MongoDB 7.0

- [Data model design](https://www.mongodb.com/docs/v7.0/core/data-model-design/). Embedded data and references for P4.
- [Schema validation](https://www.mongodb.com/docs/v7.0/core/schema-validation/). Document rules for P4.
- [Extended JSON](https://www.mongodb.com/docs/v7.0/reference/mongodb-extended-json/). Typed example data.
- [Replication](https://www.mongodb.com/docs/v7.0/replication/). Replica set members and copied data for P5.
- [Replica set elections](https://www.mongodb.com/docs/v7.0/core/replica-set-elections/). Primary failure and majority access.
- [Write concern](https://www.mongodb.com/docs/v7.0/reference/write-concern/). Write confirmation and timeout limits.
- [Read consistency](https://www.mongodb.com/docs/v7.0/core/read-isolation-consistency-recency/). Read concerns and delayed data.
- [Sharding](https://www.mongodb.com/docs/v7.0/sharding/). Data division and system cost.
- [Unique indexes](https://www.mongodb.com/docs/v7.0/core/index-unique/). Uniqueness and sharding restrictions.
- [Security guidance](https://www.mongodb.com/docs/v7.0/administration/security-checklist/). Accounts, TLS and restricted access.
- [Backup methods](https://www.mongodb.com/docs/v7.0/core/backups/). Consistent backups and restore choices.

## Student group resources

- arizonal2014. [MIT8103 Codelab](https://github.com/arizonal2014/MIT8103_Codelab/tree/619af2bb8394ad020fc29223acaedf80f3423a61). Inspected revision `619af2b`. Used for work order, normalisation examples and evidence layout.
- arizonal2014. [MIT8103 Portfolio Generator](https://github.com/arizonal2014/MIT8103_Portfolio_Generator/tree/7b738abea6d261cc787f09a8465dc2db097f1003). Inspected revision `7b738ab`. Used for ideas about rejection diagnostics and data comparisons.
- arizonal2014. [Complete library example](https://github.com/arizonal2014/Harrison_Perete_202600001/tree/4d924b3d1b736881dd20b8e8247a1dde890df7e7). Inspected revision `4d924b3`. Used to compare benchmark and session evidence layout.

These repositories are learning references. Their library records, screenshots and measurements are not the shop's evidence. The generator and its Codespace were not started. The shop scripts and data were prepared for this case.

## Writing and tools

- ASD. [ASD-STE100 Issue 9](https://www.asd-ste100.org/assets/files/ASD-STE100_ISSUE9.pdf), 15 January 2025. Writing rules and vocabulary reference. Database technical terms are defined in the [terms document](Leigh_Olaotan_301920357_Terms.md).
- Docker, PostgreSQL, mongosh and MongoDB supplied the local database tools. The [setup document](Leigh_Olaotan_301920357_Setup.md) records their versions.
- Prettier, Ruff and pgFormatter format the source files. ReportLab creates the summary PDF from its editable Markdown source. These are document and repository tools.
- OpenAI Codex supplied assistance described in the [AI-use declaration](Leigh_Olaotan_301920357_AIUse.md).
