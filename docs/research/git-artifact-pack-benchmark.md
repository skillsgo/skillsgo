# Git Artifact base and incremental Pack benchmark

## Question

This experiment compares two publication policies for Hub-authored, parentless Git Artifact commits:

1. full repack: repack every tagged Version into one base Pack and upload that complete Pack and index after every publication;
2. base plus increments: retain existing Packs, encode only objects newly created by each publication into a self-contained standard Git Pack, upload that Pack and index, and compact all tagged objects only when an operational threshold is reached.

The experiment measures repository bytes rather than ZIP compatibility or migration. Existing Catalog and R2 data are assumed disposable, as required by ADR-0016.

## Method

The benchmark used the local mirrors and snapshot selection from the earlier artifact-storage experiment:

- `github.com/anthropics/skills`;
- `github.com/mattpocock/skills`;
- `github.com/vercel-labs/agent-skills`;
- `github.com/garrytan/gstack`;
- `github.com/microsoft/azure-skills`.

Each accepted Git snapshot was projected through the current Package Artifact entry rules and published through `hub/pkg/gitartifact`. Every Version received a deterministic parentless synthetic commit and lightweight tag. Measurements include both `.pack` and `.idx` bytes. Mutable refs and discovery files are excluded because they are small and are refreshed under both policies.

The Package Artifact archive and expanded-tree limits were set to 200 MiB. All 20 gstack samples therefore participated. One of 50 Azure samples had no `SKILL.md` member and was rejected by the production validation rule, leaving 49 Azure Versions and 132 Versions overall.

For the full-repack policy, the resulting base Pack and index size was accumulated after each Version. For the incremental policy, each newly created Pack and index was accumulated once. The final incremental repository was then compacted once to measure steady-state base size. `Max warm update` is the largest single new Pack plus index; it is not a percentile and does not include small dumb-HTTP index reads.

## Results

| Repository | Versions | Full-repack upload | Incremental upload | Upload reduction | Uncompacted final | Compacted final | Compaction saving | Max warm update |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| anthropics/skills | 20 | 72.95 MiB | 4.46 MiB | 93.9% | 4.46 MiB | 3.91 MiB | 12.2% | 2.95 MiB |
| mattpocock/skills | 23 | 6.76 MiB | 0.68 MiB | 90.0% | 0.68 MiB | 0.41 MiB | 39.1% | 0.12 MiB |
| vercel-labs/agent-skills | 20 | 20.46 MiB | 1.93 MiB | 90.5% | 1.93 MiB | 1.25 MiB | 35.6% | 0.68 MiB |
| garrytan/gstack | 20 | 714.37 MiB | 73.45 MiB | 89.7% | 73.45 MiB | 45.19 MiB | 38.5% | 23.36 MiB |
| microsoft/azure-skills | 49 | 303.24 MiB | 8.37 MiB | 97.2% | 8.37 MiB | 7.10 MiB | 15.1% | 3.37 MiB |
| **Total** | **132** | **1,117.79 MiB** | **88.89 MiB** | **92.0%** | **88.89 MiB** | **57.86 MiB** | **34.9%** | **23.36 MiB** |

## Interpretation

Incremental publication is the dominant write-path improvement. It reduces immutable R2 upload bytes by about 12.6 times over this sample while preserving standard Git storage and dumb HTTP reads. Full compaction remains useful: it removes 34.9% of the multi-Pack steady-state bytes and reduces a cold client to one base Pack and index.

The repositories differ enough that a Version-count threshold alone is insufficient. The initial policy should compact after 16 increments or when increment bytes exceed 25% of the current base, whichever occurs first. A very large increment such as the 23.36 MiB gstack maximum should be able to trigger compaction by byte ratio without waiting for the Pack-count threshold.

The measured warm behavior test confirms that a go-git v6 dumb-HTTP client that already has the first Version's Pack requests only the new Pack when fetching the second Version. It still reads mutable discovery data and Pack indexes, so production telemetry must separately count `.idx`, `.pack`, and discovery bytes.

## Implementation consequences

- Publication uses go-git's low-level Pack encoder with the exact set of newly stored object IDs; `Repository.RepackObjects` remains reserved for base compaction because it always traverses all reachable objects.
- Incremental Packs use offset deltas selected only from their own object set and are independently readable; thin Packs are not stored.
- R2 checks immutable repository keys and skips uploads whose content-derived object already exists with the expected size. Mutable refs and `objects/info/packs` are written after immutable files.
- Compaction needs an R2 generation switch and stale-CDN grace period before deleting superseded Packs.
- Hydrating the complete repository into an ephemeral Railway worker remains a separate read-amplification concern. A persistent local publication cache or an R2-aware selective hydrator should be measured before production rollout.
