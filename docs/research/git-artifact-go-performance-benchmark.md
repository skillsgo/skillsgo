# Git Artifact Go hot-path benchmark

## Purpose

This benchmark measures the current Go implementation before authorizing performance changes. It uses the same five local Source Repository mirrors and historical snapshots as the storage benchmark. Local repeatable comparisons are the decision boundary for code optimization; the report does not attempt to estimate deployment billing.

## Environment and method

- Host: Apple M5 Pro, Darwin arm64.
- Go benchmark duration: exactly one operation per repository with `-benchtime=1x`.
- Corpus: `anthropics/skills`, `mattpocock/skills`, `vercel-labs/agent-skills`, `garrytan/gstack`, and `microsoft/azure-skills`.
- Stress snapshot: the sampled snapshot with the largest expanded tree for each repository.
- Incremental snapshot: the stress snapshot against its actual Git first parent, not another independently sampled commit.
- `Artifact projection`: production `git archive` execution, Go tar materialization, validation, and Package Sum calculation.
- `Initial Pack`: production `gitartifact.Publish` against an empty Artifact Repository. Entry extraction is outside the timed interval.
- `Incremental Pack`: production `gitartifact.Publish` after the first parent has already been published. Base preparation is outside the timed interval.
- Pack byte measurements include `.pack` and `.idx` files.

The opt-in benchmarks skip ordinary CI unless `SKILLSGO_REAL_REPOSITORY_BENCHMARK_DATA` points at a corpus containing `repositories.json`, `results.json`, and the referenced local mirrors.

## Artifact projection

| Repository | Expanded | Wall time | Go allocated | Allocations |
| --- | ---: | ---: | ---: | ---: |
| anthropics/skills | 10.10 MiB | 68.9 ms | 78.25 MiB | 23,541 |
| mattpocock/skills | 0.44 MiB | 22.4 ms | 4.69 MiB | 8,802 |
| vercel-labs/agent-skills | 7.31 MiB | 44.5 ms | 49.01 MiB | 21,404 |
| garrytan/gstack | 177.40 MiB | 643.7 ms | 1,236.82 MiB | 11,869 |
| microsoft/azure-skills | 11.42 MiB | 97.3 ms | 91.41 MiB | 99,250 |

The complete projection benchmark reported 938,246,144 bytes of maximum resident set size through `/usr/bin/time -lp`. The gstack operation allocated about 7.0 times its expanded input over its lifetime, confirming material allocation amplification, but its measured wall time remained below one second on this host.

## Initial Pack publication

| Repository | Expanded | Wall time | Go allocated | Resulting Pack |
| --- | ---: | ---: | ---: | ---: |
| anthropics/skills | 10.10 MiB | 1.753 s | 201.35 MiB | 3.24 MiB |
| mattpocock/skills | 0.44 MiB | 211.3 ms | 16.02 MiB | 0.21 MiB |
| vercel-labs/agent-skills | 7.31 MiB | 682.0 ms | 120.36 MiB | 0.93 MiB |
| garrytan/gstack | 177.40 MiB | 5.945 s | 2,381.58 MiB | 23.14 MiB |
| microsoft/azure-skills | 11.42 MiB | 1.552 s | 172.81 MiB | 5.83 MiB |

The CPU profile attributes the material user-space cost to Pack delta indexing and matching plus DEFLATE compression. Across these five stress snapshots, initial Pack publication is substantially more expensive than Artifact projection. This is the relevant path for a first Package publication and much of historical Backfill.

## First-parent incremental Pack publication

| Repository | Expanded target | Wall time | Go allocated | New Pack |
| --- | ---: | ---: | ---: | ---: |
| anthropics/skills | 10.10 MiB | 98.0 ms | 30.43 MiB | 159.53 KiB |
| mattpocock/skills | 0.44 MiB | 15.0 ms | 2.90 MiB | 5.36 KiB |
| vercel-labs/agent-skills | 7.31 MiB | 28.9 ms | 18.10 MiB | 15.76 KiB |
| garrytan/gstack | 177.40 MiB | 112.2 ms | 357.69 MiB | 60.58 KiB |
| microsoft/azure-skills | 11.42 MiB | 147.5 ms | 36.07 MiB | 86.11 KiB |

The earlier storage sample order is not commit order. An initial benchmark that paired neighboring JSON samples produced misleading near-full Packs. Resolving each target's actual first parent reduced gstack's measured new Pack from about 22.9 MiB to 60.6 KiB and its timed publication from 5.77 seconds to 112 milliseconds. Only the corrected first-parent numbers above are decision evidence.

## Interpretation

The baseline does not justify a broad hot-path rewrite. It does provide the control measurements for narrow parameter experiments.

- Initial publication and Backfill are Pack-bound. Optimizing repeated entry validation first would not address the dominant measured CPU stage for those operations.
- Normal adjacent updates are no longer Pack-bound. Incremental Pack publication measured 15–148 milliseconds, so speculative Pack tuning is not justified.
- Artifact projection measured 22–644 milliseconds and is comparable to or larger than incremental Pack publication in three of five repositories. Its allocation amplification is measurable, especially for the 177 MiB gstack tree, but the CPU saving available on production application compute is not yet known.
- The benchmark intentionally excludes Git network synchronization, R2 hydration, R2 publication, and PostgreSQL. Decisions in this report apply to the measured Go projection and Pack paths only.

Further optimization should continue through controlled local variants against the same corpus. Concurrency, validation ownership, and data-representation changes require their own before-and-after benchmark rather than being inferred from allocation counts alone.

## Initial Pack Window experiment

After the baseline, the initial Pack benchmark compared go-git's configured default Pack Window with windows 0, 1, and 5. Window 0 reduced CPU but expanded the five resulting Packs by about 2.3 times because the 177 MiB gstack tree lost effective delta compression, so it was rejected.

The default and window 5 candidates were then repeated five times for every repository. Window 5 reduced the sum of mean initial-Pack wall times from approximately 9.95 seconds to 8.55 seconds, a 14.1% improvement. Total Pack bytes increased from 34,966,970 to 35,020,410 bytes, or 0.15%. Per-repository mean wall-time changes ranged from about 3.5% faster for gstack to about 37.6% faster for anthropics.

A separate actual-first-parent incremental comparison produced byte-identical new Packs under the default and window 5 configurations, while single-operation timing moved by small mixed amounts. Because adjacent updates are already 15–148 milliseconds and their aggregate frequency is not established, the production optimization applies window 5 only when the Artifact Repository has no existing Pack. Incremental publication continues to use the configured go-git default. Compaction also remains unchanged.

## Reproduction

From `hub/`, with the local corpus path configured:

```bash
export SKILLSGO_REAL_REPOSITORY_BENCHMARK_DATA=/path/to/.benchmark-data

go test ./pkg/skill \
  -run '^$' \
  -bench '^BenchmarkRealRepositoryArtifactProjection$' \
  -benchtime=1x -benchmem \
  -cpuprofile=/tmp/skillsgo-projection.cpu.pprof \
  -memprofile=/tmp/skillsgo-projection.mem.pprof

go test ./pkg/gitartifact \
  -run '^$' \
  -bench '^BenchmarkRealRepositoryInitialPack$' \
  -benchtime=1x -benchmem \
  -cpuprofile=/tmp/skillsgo-initial-pack.cpu.pprof \
  -memprofile=/tmp/skillsgo-initial-pack.mem.pprof

go test ./pkg/gitartifact \
  -run '^$' \
  -bench '^BenchmarkRealRepositoryIncrementalPack$' \
  -benchtime=1x -benchmem
```

Use `go tool pprof -top` for profiles. A package-wide `-cpuprofile` includes untimed benchmark setup, so it is suitable for initial Pack analysis but must not be used to attribute incremental-only CPU when base preparation occurs in the same process. The benchmark's `ns/op`, `B/op`, and Pack-size metrics exclude that stopped-timer setup.
