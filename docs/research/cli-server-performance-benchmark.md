# CLI Server Performance Benchmark

## Purpose

Measure whether a long-lived CLI Server reduces end-to-end App-to-Hub read latency compared with starting one CLI process per operation.

## Method

- Date: 2026-07-29
- Client: the same Apple development machine and network path for both variants
- Hub: `https://hub.skillsgo.ai`
- Query: `find implement --lang en --page 0 --per-page 20 --output json`
- Baseline: 12 invocations of the CLI built from `origin/main` at `42b1c057`
- Candidate: one candidate CLI Server process receiving 12 sequential NDJSON requests
- Measurement: wall-clock time from invocation/request submission through complete machine response
- The first sample is reported as cold; the remaining 11 samples form the hot distribution.

## Results

| Mode | Cold | Hot median | Hot mean | Hot minimum | Hot maximum |
| --- | ---: | ---: | ---: | ---: | ---: |
| One process per command | 2629.3 ms | 1077.6 ms | 1189.4 ms | 1019.9 ms | 1662.6 ms |
| Long-lived CLI Server | 2005.8 ms | 698.0 ms | 764.5 ms | 666.5 ms | 1070.7 ms |

The CLI Server reduced hot median latency by 35.2% and hot mean latency by 35.7% in this run. The cold request improved by 23.7%, but cold results remain dominated by external network and Hub variance.

## Interpretation

The result supports the original hypothesis: keeping the Go process alive allows the default HTTP transport to retain network state and removes repeated process startup. The remaining roughly 0.7-second hot median is not CLI process overhead; it includes the public network path, edge behavior, and Hub query execution. Further optimization should profile those layers independently rather than adding concurrency to the local server without evidence.

This is an observational production-path benchmark, not a deterministic microbenchmark. Repeat it when the Hub deployment, Cloudflare configuration, client region, or search implementation changes.
