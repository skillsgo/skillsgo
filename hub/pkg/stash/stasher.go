/*
 * [INPUT]: Depends on the stash package imports and contracts declared in this file.
 * [OUTPUT]: Provides the stash package behavior implemented by stasher.go.
 * [POS]: Serves as maintained source in the stash package in its renamed SkillsGo Hub or CLI workspace.
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
	"go.opentelemetry.io/otel/trace"
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
	log.EntryFromContext(ctx).Debugf("saving %s@%s to storage...", mod, ver)

	semver_, err, _ := s.sfg.Do(mod+"###"+ver, func() (any, error) {
		// create a new context that ditches whatever deadline the caller passed
		// but keep the tracing info so that we can properly trace the whole thing.
		ctx, cancel := context.WithTimeout(trace.ContextWithSpan(context.Background(), span), s.timeout)
		defer cancel()
		if semver.IsValid(ver) {
			exists, err := s.checker.Exists(ctx, mod, ver)
			if err != nil {
				return "", errors.E(op, err)
			}
			if exists {
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
					_ = v.Zip.Close()
					return v.Semver, nil
				}
			}
		}
		defer func() { _ = v.Zip.Close() }()
		if err := s.storage.Save(ctx, mod, v.Semver, v.Manifest, v.Zip, v.ZipMD5, v.Info); err != nil {
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
		return nil, errors.E(op, err)
	}
	observ.RecordUpstreamFetch(ctx, "success")
	observ.RecordUpstreamFetchDuration(ctx, "success", duration)
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
		return nil, errors.E(op, err)
	}

	observ.RecordUpstreamFetch(ctx, "success")
	observ.RecordUpstreamFetchDuration(ctx, "success", duration)
	return v, nil
}
