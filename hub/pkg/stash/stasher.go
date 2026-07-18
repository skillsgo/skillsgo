/*
 * [INPUT]: Depends on request-scoped logging, immutable source resolution, storage, indexing, metrics, and singleflight.
 * [OUTPUT]: Persists resolved artifacts while preserving correlation context and reporting cache, singleflight, resolution, and upstream duration telemetry.
 * [POS]: Serves as the observable source-to-storage transaction in the artifact pipeline.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package stash

import (
	"context"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/index"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"golang.org/x/mod/semver"
	"golang.org/x/sync/singleflight"
)

// Stasher has the job of taking a module
// from an upstream entity and stashing it to a Storage Backend and Index.
// It also returns a string that represents a semver version of
// what was requested, this is helpful if what was requested
// was a descriptive version such as a branch name or a full commit sha.
type Stasher interface {
	Stash(ctx context.Context, mod, ver string) (string, error)
}

// Wrapper helps extend the main stasher's functionality with addons.
type Wrapper func(Stasher) Stasher

// New returns a plain stasher that takes
// a module from a download.Protocol and
// stashes it into a backend.Storage.
func New(f skill.Fetcher, s storage.Backend, indexer index.Indexer, timeout time.Duration, wrappers ...Wrapper) Stasher {
	var st Stasher = &stasher{f, s, storage.WithChecker(s), indexer, &singleflight.Group{}, timeout}
	for _, w := range wrappers {
		st = w(st)
	}

	return st
}

type stasher struct {
	fetcher skill.Fetcher
	storage storage.Backend
	checker storage.Checker
	indexer index.Indexer
	sfg     *singleflight.Group
	timeout time.Duration
}

func (s *stasher) Stash(ctx context.Context, mod, ver string) (string, error) {
	const op errors.Op = "stasher.Stash"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	started := time.Now()
	entry := log.EntryFromContext(ctx).WithFields(map[string]any{
		"skill_id":          mod,
		"requested_version": ver,
	})
	entry.Debugf("artifact stash requested")
	cacheResult := "miss"

	semver_, err, shared := s.sfg.Do(mod+"###"+ver, func() (any, error) {
		// create a new context that ditches whatever deadline the caller passed
		// but keep the tracing info so that we can properly trace the whole thing.
		ctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), s.timeout)
		defer cancel()
		if semver.IsValid(ver) {
			exists, err := s.checker.Exists(ctx, mod, ver)
			if err != nil {
				return "", errors.E(op, err)
			}
			if exists {
				cacheResult = "hit"
				return ver, nil
			}
		}

		var v *storage.Version
		if resolvedFetcher, ok := s.fetcher.(skill.ResolvedFetcher); ok {
			resolution, err := resolvedFetcher.Resolve(ctx, mod, ver)
			if err != nil {
				return "", errors.E(op, err)
			}
			exists, err := s.checker.Exists(ctx, mod, resolution.Version)
			if err != nil {
				return "", errors.E(op, err)
			}
			if exists {
				cacheResult = "hit"
				return resolution.Version, nil
			}
			v, err = s.fetchResolved(ctx, resolvedFetcher, mod, resolution)
			if err != nil {
				return "", errors.E(op, err)
			}
		} else {
			var err error
			v, err = s.fetchModule(ctx, mod, ver)
			if err != nil {
				return "", errors.E(op, err)
			}
			if v.Semver != ver {
				exists, err := s.checker.Exists(ctx, mod, v.Semver)
				if err != nil {
					return "", errors.E(op, err)
				}
				if exists {
					cacheResult = "hit"
					_ = v.Zip.Close()
					return v.Semver, nil
				}
			}
		}
		defer func() { _ = v.Zip.Close() }()
		if err := s.storage.Save(ctx, mod, v.Semver, v.Zip, v.ZipMD5, v.Info); err != nil {
			return "", errors.E(op, err)
		}
		if err := s.indexer.Index(ctx, mod, v.Semver); err != nil && !errors.Is(err, errors.KindAlreadyExists) {
			return "", errors.E(op, err)
		}
		return v.Semver, nil
	})
	if err != nil {
		return "", err
	}

	semver, ok := semver_.(string)
	if !ok {
		return "", errors.E(op, "unexpected type assertion failure for semver", errors.KindUnexpected)
	}
	entry.WithFields(map[string]any{
		"cache_result":        cacheResult,
		"duration_ms":         time.Since(started).Milliseconds(),
		"resolved_version":    semver,
		"singleflight_shared": shared,
	}).Debugf("artifact stash completed")
	return semver, nil
}

func (s *stasher) fetchResolved(ctx context.Context, f skill.ResolvedFetcher, skillPath string, resolution *skill.Resolution) (*storage.Version, error) {
	const op errors.Op = "stasher.fetchResolved"
	start := time.Now()
	v, err := f.FetchResolved(ctx, skillPath, resolution)
	duration := time.Since(start)
	if err != nil {
		observ.RecordUpstreamFetch(ctx, "failure")
		observ.RecordUpstreamFetchDuration(ctx, "failure", duration)
		log.EntryFromContext(ctx).WithFields(map[string]any{
			"duration_ms": duration.Milliseconds(),
			"result":      "failure",
			"skill_id":    skillPath,
		}).SystemErr(errors.E(op, err))
		return nil, errors.E(op, err)
	}
	observ.RecordUpstreamFetch(ctx, "success")
	observ.RecordUpstreamFetchDuration(ctx, "success", duration)
	log.EntryFromContext(ctx).WithFields(map[string]any{
		"duration_ms": duration.Milliseconds(),
		"result":      "success",
		"skill_id":    skillPath,
	}).Debugf("upstream artifact fetch completed")
	return v, nil
}

func (s *stasher) fetchModule(ctx context.Context, mod, ver string) (*storage.Version, error) {
	const op errors.Op = "stasher.fetchModule"
	start := time.Now()
	v, err := s.fetcher.Fetch(ctx, mod, ver)
	duration := time.Since(start)

	if err != nil {
		observ.RecordUpstreamFetch(ctx, "failure")
		observ.RecordUpstreamFetchDuration(ctx, "failure", duration)
		log.EntryFromContext(ctx).WithFields(map[string]any{
			"duration_ms": duration.Milliseconds(),
			"result":      "failure",
			"skill_id":    mod,
			"version":     ver,
		}).SystemErr(errors.E(op, err))
		return nil, errors.E(op, err)
	}

	observ.RecordUpstreamFetch(ctx, "success")
	observ.RecordUpstreamFetchDuration(ctx, "success", duration)
	log.EntryFromContext(ctx).WithFields(map[string]any{
		"duration_ms": duration.Milliseconds(),
		"result":      "success",
		"skill_id":    mod,
		"version":     ver,
	}).Debugf("upstream artifact fetch completed")
	return v, nil
}
