/*
 * [INPUT]: Depends on an opt-in local five-repository benchmark corpus, real Git commits, and the production Artifact projection path.
 * [OUTPUT]: Provides allocation and wall-time benchmarks for projecting conventionally discovered real Skill subtrees and comparing repeated versus one-sync Backfill source synchronization.
 * [POS]: Serves as non-CI performance evidence for the source-to-Artifact hot path in the Skill source module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/spf13/afero"
)

type realBenchmarkRepository struct {
	ID   string `json:"id"`
	Path string `json:"path"`
}

type realBenchmarkSnapshot struct {
	Commit        string `json:"commit"`
	ExpandedBytes int64  `json:"expandedBytes"`
}

type realBenchmarkRepositoryResult struct {
	ID        string                  `json:"id"`
	Snapshots []realBenchmarkSnapshot `json:"snapshots"`
}

type realBenchmarkResults struct {
	Repositories []realBenchmarkRepositoryResult `json:"repositories"`
}

func BenchmarkRealRepositoryArtifactProjection(benchmark *testing.B) {
	repositories, snapshots := loadRealRepositoryBenchmarkCorpus(benchmark)
	for _, repository := range repositories {
		snapshot := largestRealBenchmarkSnapshot(snapshots[repository.ID])
		benchmark.Run(filepath.Base(repository.Path), func(benchmark *testing.B) {
			listing, err := gitOutput(context.Background(), repository.Path, "ls-tree", "-r", "--name-only", snapshot.Commit)
			if err != nil {
				benchmark.Fatal(err)
			}
			candidates := discoverSkillCandidates(strings.Split(listing, "\n"))
			directories := make([]string, len(candidates))
			for index, candidate := range candidates {
				directories[index] = filepath.ToSlash(filepath.Dir(candidate))
			}
			if len(directories) == 0 {
				benchmark.Fatal("Repository contains no discoverable Skill directories")
			}
			benchmark.ReportAllocs()
			for range benchmark.N {
				entries, sum, err := createRepositoryArtifact(context.Background(), repository.ID, "v0.0.0-benchmark", repository.Path, snapshot.Commit, packageArtifactSelection{paths: directories, skillDirectories: directories})
				if err != nil {
					benchmark.Fatal(err)
				}
				if len(entries) == 0 || sum == "" {
					benchmark.Fatal("Artifact projection returned no entries or Sum")
				}
			}
		})
	}
}

func BenchmarkRealRepositoryBackfillSynchronization(benchmark *testing.B) {
	repositories, _ := loadRealRepositoryBenchmarkCorpus(benchmark)
	for _, repository := range repositories {
		packagePath, err := ParsePackagePath(repository.ID)
		if err != nil {
			benchmark.Fatal(err)
		}
		benchmark.Run(filepath.Base(repository.Path), func(benchmark *testing.B) {
			benchmark.Run("repeated-sync", func(benchmark *testing.B) {
				benchmark.ReportAllocs()
				for range benchmark.N {
					fetcher := realBenchmarkFetcher(benchmark, repository)
					for range historicalDiscoveryBenchmarkVersions {
						if err := fetcher.syncRepository(context.Background(), packagePath); err != nil {
							benchmark.Fatal(err)
						}
					}
				}
			})
			benchmark.Run("one-sync", func(benchmark *testing.B) {
				benchmark.ReportAllocs()
				for range benchmark.N {
					fetcher := realBenchmarkFetcher(benchmark, repository)
					if err := fetcher.syncRepository(context.Background(), packagePath); err != nil {
						benchmark.Fatal(err)
					}
				}
			})
		})
	}
}

const historicalDiscoveryBenchmarkVersions = 5

func realBenchmarkFetcher(testingTB testing.TB, repository realBenchmarkRepository) *gitFetcher {
	testingTB.Helper()
	fetcher, err := NewRepositoryFetcher(testingTB.TempDir(), afero.NewOsFs())
	if err != nil {
		testingTB.Fatal(err)
	}
	concrete := fetcher.(*gitFetcher)
	concrete.cloneURL = func(PackagePath) string { return repository.Path }
	return concrete
}

func loadRealRepositoryBenchmarkCorpus(testingTB testing.TB) ([]realBenchmarkRepository, map[string][]realBenchmarkSnapshot) {
	testingTB.Helper()
	root := os.Getenv("SKILLSGO_REAL_REPOSITORY_BENCHMARK_DATA")
	if root == "" {
		testingTB.Skip("SKILLSGO_REAL_REPOSITORY_BENCHMARK_DATA is not configured")
	}
	var repositories []realBenchmarkRepository
	readRealBenchmarkJSON(testingTB, filepath.Join(root, "repositories.json"), &repositories)
	var results realBenchmarkResults
	readRealBenchmarkJSON(testingTB, filepath.Join(root, "results.json"), &results)
	snapshots := make(map[string][]realBenchmarkSnapshot, len(results.Repositories))
	for _, repository := range results.Repositories {
		snapshots[repository.ID] = repository.Snapshots
	}
	return repositories, snapshots
}

func largestRealBenchmarkSnapshot(snapshots []realBenchmarkSnapshot) realBenchmarkSnapshot {
	var largest realBenchmarkSnapshot
	for _, snapshot := range snapshots {
		if snapshot.ExpandedBytes > largest.ExpandedBytes {
			largest = snapshot
		}
	}
	return largest
}

func readRealBenchmarkJSON(testingTB testing.TB, filename string, target any) {
	testingTB.Helper()
	data, err := os.ReadFile(filename)
	if err != nil {
		testingTB.Fatal(err)
	}
	if err := json.Unmarshal(data, target); err != nil {
		testingTB.Fatal(err)
	}
}
