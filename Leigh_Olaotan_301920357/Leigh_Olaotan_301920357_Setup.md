# Local database environment

Verified on 4 November 2026 on macOS 26.3.1, Apple Silicon. The
[captured checks](Leigh_Olaotan_301920357_EnvironmentChecks.txt) contain actual outputs,
collected by Codex on this workstation. They establish service connectivity; they are
not schema, query-performance or transaction results.

## Services

| Item                          | Observed configuration                                                                                                                                             |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| PostgreSQL                    | 17.11, official PostgreSQL 17 Alpine Docker image                                                                                                                  |
| PostgreSQL container          | `mit8103-postgres`, running and healthy                                                                                                                            |
| PostgreSQL host address       | `127.0.0.1:55432`; container port `5432`                                                                                                                           |
| PostgreSQL database/user      | `mit8103_portfolio` / `mit8103_admin`                                                                                                                              |
| PostgreSQL application tables | Zero at the original environment checkpoint; now five with 39 fictional rows. See [P1 evidence](portfolio-1-database-design/Leigh_Olaotan_301920357_P1_README.md). |
| Docker client/server          | 29.8.2 / 29.8.2                                                                                                                                                    |
| MongoDB                       | Existing Community server 7.0.43 on `127.0.0.1:27017`                                                                                                              |
| MongoDB shell                 | Existing mongosh 2.12.0                                                                                                                                            |
| MongoDB portfolio database    | `mit8103_order_events` is the intended later database; not created at this checkpoint                                                                              |

PostgreSQL supports the relational and SQL work. MongoDB supports the document-model
component for the same shop. The existing MongoDB installation was left in place; only
read-only `ping` and `buildInfo` commands were used. No application records were read or
changed.

## Separate exercise databases added in steps 8-11

- `mit8103_portfolio`: original five-table P1 fixture, 39 business rows; preserved for
  P2 query results.
- `mit8103_benchmark`: same model with 1,030,100 synthetic rows and the measured
  customer-history index. See the
  [benchmark method](portfolio-2-query-optimisation/Leigh_Olaotan_301920357_P2_BenchmarkMethod.md).
- `mit8103_transactions`: same initial model/seed with controlled operations and
  recorded P3 state changes; final 54 business rows. See
  [P3 reproduction/state](portfolio-3-transactions-concurrency/Leigh_Olaotan_301920357_P3_README.md).

Two cluster-wide NOLOGIN practice roles, `mit8103_p3_owner` and `mit8103_p3_app`,
support P3's controlled-operation demonstration. They have no login credentials.
Independent verification databases were created and removed after their checks. All
retained database storage is still in the same ignored runtime directory; deleting it
would remove every exercise database.

## Using the existing PostgreSQL container

Run commands from the Git repository root (the parent of the identity-named submission
folder), with Docker Desktop running. On this workstation Docker is available at
`/Users/user/.docker/bin/docker` if it is absent from the shell's PATH.

```sh
docker start mit8103-postgres
docker exec mit8103-postgres pg_isready -U mit8103_admin -d mit8103_portfolio
docker exec -it mit8103-postgres psql -X -U mit8103_admin -d mit8103_portfolio
```

The interactive command uses the local socket inside this isolated practice container.
In psql, `\conninfo` shows the connection and `\q` exits. For a database GUI, select
PostgreSQL at `127.0.0.1`, port `55432`, database `mit8103_portfolio`, and user
`mit8103_admin`. The generated password is stored only in
`temp/runtime/postgres/postgres.env`, with owner-only file permissions. Enter it
locally; never paste it into evidence or Git.

The password-authenticated TCP check actually run was:

```sh
docker exec -i mit8103-postgres sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U mit8103_admin -d mit8103_portfolio' <<'SQL'
SELECT version();
SELECT current_database(), current_user, 1 AS connection_check;
SELECT count(*) AS public_tables
FROM information_schema.tables WHERE table_schema = 'public';
SQL
docker port mit8103-postgres 5432/tcp
```

This checks TCP authentication inside the container and separately confirms its host
binding. A host GUI connection has not been claimed as tested. The administrative
practice user is suitable for this isolated coursework environment; production
application roles and permissions are outside the setup checkpoint.

## Recreating PostgreSQL on a fresh checkout

These are reconstruction instructions. Do not run the creation command against the
already-created container of the same name. The current container was created with this
configuration and the checks above passed. The whole fresh-checkout sequence has not
been rerun as a second installation.

The ignore rule `temp/` must be present before running these commands. Python generates
the local credential without displaying it and refuses to overwrite an existing
environment file.

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

`docker stop mit8103-postgres` stops the service; `docker start mit8103-postgres`
resumes it. These operations preserve the bind-mounted data. Do not delete
`temp/runtime/postgres/data` or treat the whole `temp/` directory as disposable: it
includes the live practice database and its credential. Environment variables initialise
a fresh database; editing the environment file later does not reset the password in an
existing data directory.

The image is pinned by digest for reproducibility. Host exposure is limited to loopback.
Secrets, data storage, plans and logs remain outside the tracked portfolio.

## Checking the existing MongoDB service

The installed MongoDB Node driver was used to avoid writing shell-session logs during
the automated read-only check. This is the equivalent checked code on this Homebrew
installation; its dependency path is specific to the observed mongosh version.

```sh
node <<'JS'
const { MongoClient } = require('/opt/homebrew/Cellar/mongosh/2.12.0/libexec/lib/node_modules/@mongosh/cli-repl/node_modules/mongodb');
(async () => {
  const client = new MongoClient('mongodb://127.0.0.1:27017/?directConnection=true', {
    serverSelectionTimeoutMS: 4000
  });
  try {
    await client.connect();
    const admin = client.db('admin');
    const ping = await admin.command({ ping: 1 });
    const build = await admin.command({ buildInfo: 1 });
    console.log({ serverVersion: build.version, ping: ping.ok });
  } finally {
    await client.close();
  }
})().catch(error => { console.error(error.message); process.exitCode = 1; });
JS
```

For manual shell use, connect with
`mongosh 'mongodb://127.0.0.1:27017/?directConnection=true'`, then use
`db.adminCommand({ ping: 1 })` and `db.version()`. This interactive route is guidance,
not the method used for the captured server check. The existing MongoDB launch
configuration was not changed; if it is stopped, start it using the installation's
existing service management before connecting. A successful ping alone does not
establish database permissions or complete the future NoSQL exercise.

## References and assistance

- [Official PostgreSQL container documentation](https://hub.docker.com/_/postgres):
  environment variables, persistence and container use.
- [MongoDB ping command](https://www.mongodb.com/docs/manual/reference/command/ping/):
  service response check.
- Codex prepared the isolated PostgreSQL container, ran the recorded checks and drafted
  these instructions. Student review and later implementation results must be recorded
  when they actually occur.
