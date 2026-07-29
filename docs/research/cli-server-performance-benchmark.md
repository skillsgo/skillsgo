# CLI Server Performance Benchmark

## Purpose

Measure whether a long-lived CLI Server reduces end-to-end App-to-Hub read latency compared with starting one CLI process per operation.

## Method

- Date: 2026-07-29
- Client: the same Apple development machine and network path for both variants
- Hub: `https://hub.skillsgo.ai`
- Query: `find implement --lang en --page 0 --per-page 20 --output json`
- Baseline: 12 invocations of the CLI built from `origin/main` at `42b1c057`
- Candidate: one CLI Server process built from `5d1fdcb7` and receiving 12 sequential NDJSON requests
- Measurement: wall-clock time from invocation/request submission through complete machine response
- The first sample is reported as cold; the remaining 11 samples form the hot distribution.
- Collection order was baseline first and candidate second. The result therefore measures the production path but does not by itself prove causal attribution to connection reuse.

## Results

| Mode | Cold | Hot median | Hot mean | Hot minimum | Hot maximum |
| --- | ---: | ---: | ---: | ---: | ---: |
| One process per command | 2629.3 ms | 1077.6 ms | 1189.4 ms | 1019.9 ms | 1662.6 ms |
| Long-lived CLI Server | 2005.8 ms | 698.0 ms | 764.5 ms | 666.5 ms | 1070.7 ms |

The CLI Server reduced hot median latency by 35.2% and hot mean latency by 35.7% in this run. The cold request improved by 23.7%, but cold results remain dominated by external network and Hub variance.

### Raw samples

All values are milliseconds in collection order:

- One-shot: `2629.3, 1019.9, 1662.6, 1130.1, 1487.1, 1019.9, 1077.6, 1277.8, 1046.0, 1047.5, 1048.0, 1266.4`
- CLI Server: `2005.8, 959.8, 1070.7, 737.8, 667.9, 748.1, 682.5, 666.5, 698.0, 820.1, 682.6, 675.2`

### Reproduction

Build `skillsgo-old` from baseline SHA `42b1c057` and `skillsgo-new` from candidate SHA `5d1fdcb7`. For the baseline, measure 12 complete subprocess calls:

```text
skillsgo-old find implement --hub https://hub.skillsgo.ai --lang en --page 0 --per-page 20 --output json
```

For the candidate, start `skillsgo-new server --stdio` once and measure one complete response for each of 12 writes of this NDJSON line, varying `id` from 0 through 11:

```json
{"schemaVersion":1,"id":"0","arguments":["find","implement","--hub","https://hub.skillsgo.ai","--lang","en","--page","0","--per-page","20","--output","json"]}
```

Use a monotonic wall clock immediately around each subprocess call or NDJSON write/read pair. Require exit code zero in both modes and retain stdout consumption so the measured boundary is identical.

## Interpretation

The result is consistent with the original hypothesis: keeping the Go process alive allows the default HTTP transport to retain network state and removes repeated process startup. Because the variants were measured in separate time blocks over a public network, this run does not isolate process startup from DNS, TCP, TLS, edge, or Hub variance. The remaining roughly 0.7-second hot median includes the public network path, edge behavior, and Hub query execution. Further optimization should profile those layers independently rather than adding concurrency to the local server without evidence.

This is an observational production-path benchmark, not a deterministic microbenchmark. Repeat it when the Hub deployment, Cloudflare configuration, client region, or search implementation changes.
