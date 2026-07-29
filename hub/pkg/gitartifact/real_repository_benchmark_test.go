/*
 * [INPUT]: Depends on an opt-in local five-repository benchmark corpus, real Git snapshots, and production Git Artifact publication.
 * [OUTPUT]: Provides allocation, wall-time, and Pack-size benchmarks for initial and adjacent-Version incremental publication.
 * [POS]: Serves as non-CI performance evidence for the Hub-authored Git object and Pack hot path.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package gitartifact

import (
	"archive/tar"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"testing"
	"time"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

type realPackRepository struct {
	ID   string `json:"id"`
	Path string `json:"path"`
}

type realPackSnapshot struct {
	Commit        string `json:"commit"`
	ExpandedBytes int64  `json:"expandedBytes"`
}

type realPackRepositoryResult struct {
	ID        string             `json:"id"`
	Snapshots []realPackSnapshot `json:"snapshots"`
}

type realPackResults struct {
	Repositories []realPackRepositoryResult `json:"repositories"`
}

func BenchmarkRealRepositoryInitialPack(benchmark *testing.B) {
	repositories, snapshots := loadRealPackCorpus(benchmark)
	for _, repository := range repositories {
		target := largestRealPackSnapshot(snapshots[repository.ID])
		entries := readRealPackEntries(benchmark, repository.Path, target.Commit)
		benchmark.Run(filepath.Base(repository.Path), func(benchmark *testing.B) {
			benchmark.ReportAllocs()
			benchmark.ReportMetric(float64(target.ExpandedBytes), "expanded-B/op")
			for range benchmark.N {
				benchmark.StopTimer()
				repositoryPath := filepath.Join(benchmark.TempDir(), "artifact.git")
				benchmark.StartTimer()
				_, created, err := Publish(repositoryPath, repository.ID, "v1.0.0", time.Unix(1, 0), entries)
				benchmark.StopTimer()
				if err != nil || !created {
					benchmark.Fatalf("Publish() created=%v err=%v", created, err)
				}
				benchmark.ReportMetric(float64(realPackRepositoryBytes(benchmark, repositoryPath)), "pack-B/op")
				benchmark.StartTimer()
			}
		})
	}
}

func BenchmarkRealRepositoryIncrementalPack(benchmark *testing.B) {
	repositories, snapshots := loadRealPackCorpus(benchmark)
	for _, repository := range repositories {
		target := largestRealPackSnapshot(snapshots[repository.ID])
		previous := realPackFirstParent(benchmark, repository.Path, target)
		previousEntries := readRealPackEntries(benchmark, repository.Path, previous.Commit)
		targetEntries := readRealPackEntries(benchmark, repository.Path, target.Commit)
		benchmark.Run(filepath.Base(repository.Path), func(benchmark *testing.B) {
			benchmark.ReportAllocs()
			benchmark.ReportMetric(float64(target.ExpandedBytes), "expanded-B/op")
			for range benchmark.N {
				benchmark.StopTimer()
				repositoryPath := filepath.Join(benchmark.TempDir(), "artifact.git")
				_, _, err := Publish(repositoryPath, repository.ID, "v1.0.0", time.Unix(1, 0), previousEntries)
				if err != nil {
					benchmark.Fatal(err)
				}
				before := realPackRepositoryBytes(benchmark, repositoryPath)
				benchmark.StartTimer()
				_, created, err := Publish(repositoryPath, repository.ID, "v1.1.0", time.Unix(2, 0), targetEntries)
				benchmark.StopTimer()
				if err != nil || !created {
					benchmark.Fatalf("Publish() created=%v err=%v", created, err)
				}
				benchmark.ReportMetric(float64(realPackRepositoryBytes(benchmark, repositoryPath)-before), "new-pack-B/op")
				benchmark.StartTimer()
			}
		})
	}
}

func loadRealPackCorpus(testingTB testing.TB) ([]realPackRepository, map[string][]realPackSnapshot) {
	testingTB.Helper()
	root := os.Getenv("SKILLSGO_REAL_REPOSITORY_BENCHMARK_DATA")
	if root == "" {
		testingTB.Skip("SKILLSGO_REAL_REPOSITORY_BENCHMARK_DATA is not configured")
	}
	var repositories []realPackRepository
	readRealPackJSON(testingTB, filepath.Join(root, "repositories.json"), &repositories)
	var results realPackResults
	readRealPackJSON(testingTB, filepath.Join(root, "results.json"), &results)
	snapshots := make(map[string][]realPackSnapshot, len(results.Repositories))
	for _, repository := range results.Repositories {
		snapshots[repository.ID] = repository.Snapshots
	}
	return repositories, snapshots
}

func largestRealPackSnapshot(snapshots []realPackSnapshot) realPackSnapshot {
	var largest realPackSnapshot
	for _, snapshot := range snapshots {
		if snapshot.ExpandedBytes > largest.ExpandedBytes {
			largest = snapshot
		}
	}
	return largest
}

func realPackFirstParent(testingTB testing.TB, repository string, target realPackSnapshot) realPackSnapshot {
	testingTB.Helper()
	command := exec.Command("git", "-C", repository, "rev-parse", target.Commit+"^")
	output, err := command.Output()
	if err != nil {
		testingTB.Fatalf("resolve first parent of %s: %v", target.Commit, err)
	}
	return realPackSnapshot{Commit: strings.TrimSpace(string(output))}
}

func readRealPackEntries(testingTB testing.TB, repository, commit string) []protocolartifact.Entry {
	testingTB.Helper()
	command := exec.Command("git", "-C", repository, "archive", "--format=tar", commit)
	stdout, err := command.StdoutPipe()
	if err != nil {
		testingTB.Fatal(err)
	}
	command.Stderr = os.Stderr
	if err := command.Start(); err != nil {
		testingTB.Fatal(err)
	}
	reader := tar.NewReader(stdout)
	entries := make([]protocolartifact.Entry, 0)
	for {
		header, err := reader.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			testingTB.Fatal(err)
		}
		first, _, _ := strings.Cut(header.Name, "/")
		if first == ".agents" || first == ".claude" || first == ".codex" || !header.FileInfo().Mode().IsRegular() {
			continue
		}
		contents, err := io.ReadAll(reader)
		if err != nil {
			testingTB.Fatal(err)
		}
		mode := os.FileMode(0o644)
		if header.FileInfo().Mode().Perm()&0o111 != 0 {
			mode = 0o755
		}
		entries = append(entries, protocolartifact.Entry{Path: header.Name, Contents: contents, Mode: mode, Size: int64(len(contents))})
	}
	if err := command.Wait(); err != nil {
		testingTB.Fatal(err)
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].Path < entries[j].Path })
	validated, err := protocolartifact.ValidateEntries(entries)
	if err != nil {
		testingTB.Fatalf("validate %s: %v", commit, err)
	}
	return validated
}

func realPackRepositoryBytes(testingTB testing.TB, repositoryPath string) int64 {
	testingTB.Helper()
	matches, err := filepath.Glob(filepath.Join(repositoryPath, "objects", "pack", "pack-*"))
	if err != nil {
		testingTB.Fatal(err)
	}
	var total int64
	for _, match := range matches {
		info, err := os.Stat(match)
		if err != nil {
			testingTB.Fatal(err)
		}
		total += info.Size()
	}
	return total
}

func readRealPackJSON(testingTB testing.TB, filename string, target any) {
	testingTB.Helper()
	data, err := os.ReadFile(filename)
	if err != nil {
		testingTB.Fatal(err)
	}
	if err := json.Unmarshal(data, target); err != nil {
		testingTB.Fatal(fmt.Errorf("decode %s: %w", filename, err))
	}
}
