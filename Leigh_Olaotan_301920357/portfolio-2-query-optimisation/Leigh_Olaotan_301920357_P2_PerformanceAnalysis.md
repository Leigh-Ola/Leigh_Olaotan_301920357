# Measured indexing result

The customer-history index reduced median server execution time for the selective query from **19.032 ms to 0.578 ms** in this local five-run sample. The broad status count kept its sequential scan and similar timing. Both phases returned the same rows in the same order. Result hashes, row counts, settings and query-source hashes also match. The eleven existing indexes remain. Only the candidate index was added.

| Workload | Before median ms | After median ms | Median shared blocks accessed (hits + reads) |
| --- | --: | --: | --: |
| selective_history | 19.032 | 0.578 | 2867 → 16 |
| broad_status | 44.913 | 43.769 | 2858 → 2858 |

See the [method](Leigh_Olaotan_301920357_P2_BenchmarkMethod.md), [before timings](Leigh_Olaotan_301920357_P2_BeforeTimings.csv), [after timings](Leigh_Olaotan_301920357_P2_AfterTimings.csv), [before plans](Leigh_Olaotan_301920357_P2_BeforePlans.txt) and [after plans](Leigh_Olaotan_301920357_P2_AfterPlans.txt). Full JSON contains each measured and warm-up plan; text plans are separate diagnostic executions.

## Why the selective plan changed

Before indexing, the sales_order sequential scan examines 300,000 rows, removes 299,987 through the filter, and sorts the 13 matching rows before returning ten. Both phases use the existing unique customer-code index to resolve BC00042. After indexing, a B-tree Index Scan uses the customer and date conditions. The key order gives descending timestamps and order IDs. LIMIT stops after ten rows, so no sort node is necessary. This is an ordinary index scan with heap visits, not an index-only scan.

The observed median ratio is 32.93 times faster for server execution in this sample. This ratio does not measure full application speed. Execution Time excludes planning, connection setup and client or network delay. Planning values are separately kept in the CSV.

The broad query still reads 2,858 blocks and returns 270,000. Its before execution times range from 42.513 to 45.511 ms; after values range from 42.592 to 44.727 ms. The ranges overlap. The small median change is not evidence of a useful optimisation for that workload; the new index does not support the status predicate.

## Costs and limits

The candidate index occupies **12,189,696 bytes (11.62 MiB)**, compared with 23,412,736 bytes for the order heap. Inserts/deletes and updates to indexed keys now require index maintenance, more WAL and storage. These write costs were not benchmarked; no numeric write-throughput claim is made. A non-concurrent index build was appropriate in this isolated experiment with no application writers; a production rollout must have a separate locking/deployment decision.

[Observed settings with units](Leigh_Olaotan_301920357_P2_SettingsOutput.txt) show shared_buffers=50 blocks of 8 KiB: only 400 KiB. That was unchanged between phases. Warm-ups therefore do not imply shared-buffer residency: the baseline selective measurements report 5 hits and 2,862 reads, while the indexed measurements report 16 reads. PostgreSQL shared reads are buffer misses, not proof of physical disk I/O; operating-system caching may still serve them. No OS cache flush, cache-residency measurement or I/O timing was done. Both phases used the same memory settings. The saved plans and timings contain the measured results.

The data has a regular artificial pattern. The experiment uses one customer and date range. Parallel queries and JIT are off.

EXPLAIN and other host activity can affect timing. These limits prevent a general performance claim. The index is justified for this selective lookup, not for each report.

The baseline phase ran before the indexed phase. Time-related host changes can affect that comparison. Production data, write load and other settings must have their own measurements.

## Reproduce the after phase

After saving a new baseline, run these commands from repository root:

```sh
docker exec -i mit8103-postgres psql -X -v ON_ERROR_STOP=1 -U mit8103_admin -d mit8103_benchmark \
  < Leigh_Olaotan_301920357/portfolio-2-query-optimisation/Leigh_Olaotan_301920357_P2_Optimisation.sql
python3 Leigh_Olaotan_301920357/portfolio-2-query-optimisation/Leigh_Olaotan_301920357_P2_Benchmark.py \
  after --output-dir temp/logs/p2-new-after
```

Use the same database/options as the baseline and a new output directory. [Index output](Leigh_Olaotan_301920357_P2_IndexOutput.txt) records actual creation/storage. The runner tests expected results in both phases. A cross-phase verification also compared each returned value, settings, source hash, table counts and unchanged existing indexes; all matched.

Sources: PostgreSQL 17 [Using EXPLAIN](https://www.postgresql.org/docs/17/using-explain.html) and [multicolumn indexes](https://www.postgresql.org/docs/17/indexes-multicolumn.html).
