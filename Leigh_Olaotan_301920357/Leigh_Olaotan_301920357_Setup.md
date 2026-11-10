# Local database environment

Verified on 4 November 2026 on macOS 26.3.1, Apple Silicon. The [captured tests](Leigh_Olaotan_301920357_EnvironmentChecks.txt) contain actual outputs, collected by my on my workstation. They show service connectivity; they are not schema, query-performance or transaction results.

## Tools and working directory

Use Docker with a running engine, Python 3.9 or newer, MongoDB 7.0 and `mongosh`. Make `docker`, `python3` and `mongosh` available on PATH. PostgreSQL runs inside Docker, so a separate host `psql` installation is optional. These commands use a POSIX shell.

Throughout the component instructions, **repository root** means the parent of `Leigh_Olaotan_301920357/`. For an extracted submission, open a terminal in that parent directory. No Git metadata or repository maintenance tools are needed to run the exercises. Keep the submission folder name unchanged because the MongoDB scripts use it to load their shared definitions.

The commands create `temp/runtime/` for local database storage and `temp/logs/` for new results. These directories are not supplied inputs. The initial setup below creates a new PostgreSQL container. Use the existing-container instructions only after that setup.

## Recorded services

| Item | Observed configuration |
| --- | --- |
| PostgreSQL | 17.11, official PostgreSQL 17 Alpine Docker image |
| PostgreSQL container | `mit8103-postgres`, running and healthy |
| PostgreSQL host address | `127.0.0.1:55432`; container port `5432` |
| PostgreSQL database/user | `mit8103_portfolio` / `mit8103_admin` |
| PostgreSQL application tables | Zero during the initial connection checks; five tables with 39 fictional rows after loading the P1 schema and data. See [P1 evidence](portfolio-1-database-design/Leigh_Olaotan_301920357_P1_README.md). |
| Docker client/server | 29.8.2 / 29.8.2 |
| MongoDB | Existing Community server 7.0.43 on `127.0.0.1:27017` |
| MongoDB shell | Existing mongosh 2.12.0 |
| MongoDB portfolio database | `mit8103_order_events`, with 14 documents in `order_events`; see [P4 evidence](portfolio-4-nosql/Leigh_Olaotan_301920357_P4_README.md) |

PostgreSQL supports the relational and SQL work. MongoDB supports the document-model component for the same shop. The initial MongoDB checks used only read-only `ping` and `buildInfo` commands. Portfolio 4 added the separate event collection to the existing MongoDB installation. Its service configuration stayed unchanged.

## PostgreSQL exercise databases

- `mit8103_portfolio`: original five-table P1 fixture, 39 business rows; kept for P2 query results.
- `mit8103_benchmark`: same model with 1,030,100 synthetic rows and the measured customer-history index. See the [benchmark method](portfolio-2-query-optimisation/Leigh_Olaotan_301920357_P2_BenchmarkMethod.md).
- `mit8103_transactions`: same initial model/seed with controlled operations and recorded P3 state changes; final 54 business rows. See [P3 reproduction/state](portfolio-3-transactions-concurrency/Leigh_Olaotan_301920357_P3_README.md).

Two cluster-wide NOLOGIN practice roles, `mit8103_p3_owner` and `mit8103_p3_app`, support P3's controlled-operation demonstration. They have no login credentials. Independent verification databases were created and removed after their tests. All PostgreSQL exercise databases use the storage directory created by the setup commands below. If you delete that directory, you remove all these databases.

## MongoDB event exercise

On 7 November 2026, the existing MongoDB 7.0.43 service was verified as standalone and the unused `mit8103_order_events` database was populated with 14 fictional events. The [P4 README](portfolio-4-nosql/Leigh_Olaotan_301920357_P4_README.md) links the exact model, commands, installed validator/indexes, query results and validation evidence. A separate database replay and read-only comparison with P1 both passed.

The recorded run kept the primary `order_events` collection. Temporary validation collections and the dedicated replay database were removed after their tests. MongoDB continues to use its pre-existing service storage; it was not moved into the PostgreSQL runtime directory. This is local NoSQL implementation evidence, not a replication, sharding or cloud-deployment experiment.

## Using the existing PostgreSQL container

Run commands from repository root, as defined above, with the Docker engine running.

```sh
docker start mit8103-postgres
docker exec mit8103-postgres pg_isready -U mit8103_admin -d mit8103_portfolio
docker exec -it mit8103-postgres psql -X -U mit8103_admin -d mit8103_portfolio
```

The interactive command uses the local socket inside this isolated practice container. In psql, `\conninfo` shows the connection and `\q` exits. For a database GUI, select PostgreSQL at `127.0.0.1`, port `55432`, database `mit8103_portfolio`, and user `mit8103_admin`. The setup commands below create the password file at `temp/runtime/postgres/postgres.env`, with owner-only permissions. Use that password for a GUI connection. Keep the credential out of published files.

The password-authenticated TCP test actually run was:

```sh
docker exec -i mit8103-postgres sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U mit8103_admin -d mit8103_portfolio' <<'SQL'
SELECT version();
SELECT current_database(), current_user, 1 AS connection_check;
SELECT count(*) AS public_tables
FROM information_schema.tables WHERE table_schema = 'public';
SQL
docker port mit8103-postgres 5432/tcp
```

This tests TCP authentication inside the container and separately confirms its host binding. A host GUI connection has not been claimed as tested. The administrative practice user is suitable for this isolated coursework environment. Production application roles and permissions are outside these connection checks.

## Create PostgreSQL for a new reproduction

Use an unused container name and empty storage directory. The recorded container used the configuration below. The connection checks passed on that installation. A second complete installation was not recorded.

Python creates the local credential without displaying it. It refuses to overwrite an existing environment file. If using Git, exclude `temp/` from version control.

```sh
mkdir -p temp/runtime/postgres/data
python3 - <<'PY'
from pathlib import Path
import os
import secrets

env_path = Path('temp/runtime/postgres/postgres.env')
fd = os.open(env_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, 'w') as env_file:
    env_file.write('POSTGRES_USER=mit8103_admin\n')
    env_file.write('POSTGRES_DB=mit8103_portfolio\n')
    env_file.write('POSTGRES_PASSWORD=' + secrets.token_hex(24) + '\n')
PY

docker pull postgres@sha256:266d3c257594e195b309ae9d1805e54c788f1d7b375f56bf6c367aac6c917e7b
docker run --detach \
  --name mit8103-postgres \
  --restart unless-stopped \
  --publish 127.0.0.1:55432:5432 \
  --env-file temp/runtime/postgres/postgres.env \
  --mount "type=bind,source=$PWD/temp/runtime/postgres/data,target=/var/lib/postgresql/data" \
  --health-cmd 'pg_isready -U mit8103_admin -d mit8103_portfolio' \
  --health-interval 5s --health-timeout 3s --health-retries 10 \
  postgres@sha256:266d3c257594e195b309ae9d1805e54c788f1d7b375f56bf6c367aac6c917e7b
```

`docker stop mit8103-postgres` stops the service; `docker start mit8103-postgres` resumes it. These operations keep the bind-mounted data. Do not delete `temp/runtime/postgres/data`. The `temp/` directory contains the live practice database and its credential. Keep these files. Environment variables initialise a new database; editing the environment file later does not reset the password in an existing data directory.

The image is pinned by digest for reproducibility. Host exposure is limited to loopback. Credentials, database storage and new logs remain outside the submission folder.

## Checking the existing MongoDB service

The recorded connection check used the MongoDB Node driver bundled with `mongosh`. It ran `ping` and `buildInfo` against `admin`. The equivalent shell commands below avoid installation-specific driver paths. They are reproduction instructions, not the source of the saved Node output.

```sh
mongosh --norc --quiet 'mongodb://127.0.0.1:27017/?directConnection=true' --eval '
printjson(db.getSiblingDB("admin").runCommand({ ping: 1 }));
printjson(db.getSiblingDB("admin").runCommand({ buildInfo: 1 }).version);
'
```

Start MongoDB through its installed service manager before connecting. The submission does not change that service configuration. A successful ping shows that the server responds. It does not prove database permissions. Follow the P4 README to create the event collection and run its queries and validation tests.

## References and assistance

- [Official PostgreSQL container documentation](https://hub.docker.com/_/postgres): environment variables, persistence and container use.
- [MongoDB ping command](https://www.mongodb.com/docs/manual/reference/command/ping/): service response test.
- I prepared the isolated PostgreSQL container, ran the recorded tests and drafted these instructions. The AI-use declaration records how i used ai tools and my review and verification. Each portfolio component contains its implementation results.
