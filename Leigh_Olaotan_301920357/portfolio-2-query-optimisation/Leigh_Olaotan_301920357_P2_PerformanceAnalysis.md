# Measured indexing result

The customer-history index reduced median server execution time for the selective query from **19.032 ms to 0.578 ms** in this local five-run sample. The broad status count retained its sequential scan and similar timing. Both complete ordered result sets, their hashes, row counts, settings and query-source hash match across phases. All eleven existing indexes remain; only the candidate index was added.

| Workload | Before median ms | After median ms | Median shared blocks accessed (hits + reads) |
| --- | ---: | ---: | ---: |
| selective_history | 19.032 | 0.578 | 2867 → 16 |
| broad_status | 44.913 | 43.769 | 2858 → 2858 |

See the [method](Leigh_Olaotan_301920357_P2_BenchmarkMethod.md), [before timings](Leigh_Olaotan_301920357_P2_BeforeTimings.csv), [after timings](Leigh_Olaotan_301920357_P2_AfterTimings.csv), [before plans](Leigh_Olaotan_301920357_P2_BeforePlans.txt) and [after plans](Leigh_Olaotan_301920357_P2_AfterPlans.txt). Full JSON contains every measured and warm-up plan; text plans are separate diagnostic executions.

## Why the selective plan changed

Before indexing, the sales_order sequential scan examines 300,000 rows, removes 299,987 through the filter, and sorts the 13 qualifying rows before returning ten. Both phases use the existing unique customer-code index to resolve BC00042. After indexing, a B-tree Index Scan uses customer equality and the date interval; key order supplies the requested descending timestamp/order order. LIMIT stops after ten rows, so no sort node is needed. This is an ordinary index scan with heap visits, not an index-only scan.

The observed median ratio is 32.93 times faster for server execution in this sample. It is not an end-to-end application speedup: planning, connection establishment and client/network overhead are excluded from Execution Time. Planning values are separately preserved in the CSV.

The broad query still reads 2,858 blocks and returns 270,000. Its before execution times range from 42.513 to 45.511 ms; after values range from 42.592 to 44.727 ms. The ranges overlap. The small median change is not evidence of a useful optimisation for that workload; the new index does not support the status predicate.

## Costs and limits

The candidate index occupies **12,189,696 bytes (11.62 MiB)**, compared with 23,412,736 bytes for the order heap. Inserts/deletes and updates to indexed keys now require index maintenance, additional WAL and storage. These write costs were not benchmarked; no numeric write-throughput claim is made. A non-concurrent index build was appropriate in this isolated experiment with no application writers; a production rollout needs a separate locking/deployment decision.

[Observed settings with units](Leigh_Olaotan_301920357_P2_SettingsOutput.txt) show shared_buffers=50 blocks of 8 KiB: only 400 KiB. That was unchanged between phases. Warm-ups therefore do not imply shared-buffer residency: the baseline selective measurements report 5 hits and 2,862 reads, while the indexed measurements report 16 reads. PostgreSQL shared reads are buffer misses, not proof of physical disk I/O; operating-system caching may still serve them. No OS cache flush, cache-residency measurement or I/O timing was performed. This limitation corrects the baseline method's initial broad cached-workload wording; original measurements are preserved unchanged.

Regular synthetic data, one customer/date range, disabled parallel query/JIT, EXPLAIN instrumentation, sequential before/after phases and host variability limit generalisation. The index is justified for this selective lookup, not for every report. Production distributions, write load and other settings require separate measurement.

## Reproduce the after phase

After creating and committing a fresh baseline, from repository root:

```sh
docker exec -i mit8103-postgres psql -X -v ON_ERROR_STOP=1 -U mit8103_admin -d mit8103_benchmark \
  < Leigh_Olaotan_301920357/portfolio-2-query-optimisation/Leigh_Olaotan_301920357_P2_Optimisation.sql
python3 Leigh_Olaotan_301920357/portfolio-2-query-optimisation/Leigh_Olaotan_301920357_P2_Benchmark.py \
  after --output-dir temp/logs/p2-new-after
```

Use the same database/options as the baseline and a new output directory. [Index output](Leigh_Olaotan_301920357_P2_IndexOutput.txt) records actual creation/storage. The runner checks expected results in both phases. A cross-phase verification also compared every returned value, settings, source hash, table counts and unchanged existing indexes; all matched.

Sources: PostgreSQL 17 [Using EXPLAIN](https://www.postgresql.org/docs/17/using-explain.html) and [multicolumn indexes](https://www.postgresql.org/docs/17/indexes-multicolumn.html). Codex implemented, executed and analysed the experiment; student review and reflection remain pending.
