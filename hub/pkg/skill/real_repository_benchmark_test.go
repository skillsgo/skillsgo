/*
 * [INPUT]: Depends on an opt-in local five-repository benchmark corpus, real Git commits, and the production Artifact projection path.
 * [OUTPUT]: Provides allocation and wall-time benchmarks for projecting large real Source Repository trees into validated Package Artifacts.
 * [POS]: Serves as non-CI performance evidence for the source-to-Artifact hot path in the Skill source module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
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
			benchmark.ReportAllocs()
			benchmark.ReportMetric(float64(snapshot.ExpandedBytes), "expanded-B/op")
			for range benchmark.N {
				entries, sum, err := createRepositoryArtifact(context.Background(), repository.ID, "v0.0.0-benchmark", repository.Path, snapshot.Commit)
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
