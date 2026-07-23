/*
 * [INPUT]: Depends on immutable Repository storage, canonical Repository Tag listing, and configured offline/strict/fallback network policy.
 * [OUTPUT]: Provides Repository Tag union listing plus direct immutable Info and ZIP reads; publication misses are handled only by the Repository materializer decorator.
 * [POS]: Serves as the storage-first base of the Repository artifact protocol.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package download

import (
	"context"
	"sync"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"golang.org/x/mod/module"
)

// Protocol is the Repository artifact protocol exposed by the Hub proxy.
type Protocol interface {
	// List implements GET /{repository}/@v/list.
	List(ctx context.Context, mod string) ([]string, error)

	// Info implements GET /{repository}/@v/{version}.info.
	Info(ctx context.Context, mod, ver string) ([]byte, error)

	// Zip implements GET /{repository}/@v/{version}.zip.
	Zip(ctx context.Context, mod, ver string) (storage.SizeReadCloser, error)
}

// Opts specifies download protocol options to avoid long func signature.
type Opts struct {
	Storage     storage.Backend
	Lister      skill.UpstreamLister
	NetworkMode string
}

// NetworkMode constants.
const (
	Strict   = "strict"
	Offline  = "offline"
	Fallback = "fallback"
)

// New returns the storage-backed Repository artifact protocol.
func New(opts *Opts) Protocol {
	return &protocol{storage: opts.Storage, lister: opts.Lister, networkMode: opts.NetworkMode}
}

type protocol struct {
	storage     storage.Backend
	lister      skill.UpstreamLister
	networkMode string
}

func (p *protocol) List(ctx context.Context, mod string) ([]string, error) {
	const op errors.Op = "protocol.List"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()

	var strList, goList []string
	var sErr, goErr error
	var wg sync.WaitGroup

	/*
		TODO: potential refactor:

		Storage Lister: just return stuff from storage, or error otherwise.

		FallbackVCS lister: list from VCS, return empty list if error.

		StrictVCS Lister: list from VCS, error if it doesn't succeed.

		UnionLister(listers ...Lister): combines any number of listers.
	*/
	wg.Go(func() {
		strList, sErr = p.storage.List(ctx, mod)
	})

	if p.networkMode != Offline {
		wg.Go(func() {
			_, goList, goErr = p.lister.List(ctx, mod)
		})
	}

	wg.Wait()

	// if we got an unexpected storage err then we can not guarantee that the end result contains all versions
	// a tag or repo could have been deleted
	if sErr != nil {
		return nil, errors.E(op, sErr)
	}

	// if we're in offline mode, just return what came from storage.
	if p.networkMode == Offline {
		return strList, nil
	}

	// if i.e. github is unavailable we should fail as well so that the behavior of the proxy is stable.
	// otherwise we will get different results the next time because i.e. GH is up again
	isUnexpGoErr := goErr != nil && !errors.IsRepoNotFoundErr(goErr)
	if isUnexpGoErr && p.networkMode == Strict {
		return nil, errors.E(op, goErr)
	}

	// if we're in fallback mode, and VCS is down, just return what we have in storage,
	// don't remove any pseudo versions.
	if isUnexpGoErr && p.networkMode == Fallback {
		return strList, nil
	}

	isRepoNotFoundErr := goErr != nil && errors.IsRepoNotFoundErr(goErr)
	storageEmpty := len(strList) == 0
	// if storage has no versions, and the repo was deleted/not-found, we know for sure
	// there are no versions that SkillsGo Hub can serve, so return an error.
	if isRepoNotFoundErr && storageEmpty {
		return nil, errors.E(op, errors.S(mod), errors.KindNotFound, goErr)
	}

	strListSemVers := removePseudoVersions(strList)
	// If the Repository no longer exists but the Hub already saved versions,
	// return those so that running go get github.com/my/mod gives us the newest saved version
	// we should only do that if exclusively pseudo-versions have been saved
	// retain immutable published history.
	if isRepoNotFoundErr && len(strListSemVers) == 0 {
		return strList, nil
	}
	// Public lists contain release Tags only. Pseudo-versions remain addressable
	// by exact coordinate and through the Repository Resolution API.
	return union(goList, strListSemVers), nil
}

func removePseudoVersions(allVersions []string) []string {
	var vers []string
	for _, v := range allVersions {
		if !module.IsPseudoVersion(v) {
			vers = append(vers, v)
		}
	}
	return vers
}

func (p *protocol) Info(ctx context.Context, mod, ver string) ([]byte, error) {
	const op errors.Op = "protocol.Info"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	info, err := p.storage.Info(ctx, mod, ver)
	result := "hit"
	if err != nil {
		result = "miss"
	}
	observ.RecordCacheLookup(ctx, result, "info")
	logCacheLookup(ctx, mod, ver, "info", result)
	if err != nil {
		return nil, errors.E(op, err)
	}

	return info, nil
}

func (p *protocol) Zip(ctx context.Context, mod, ver string) (storage.SizeReadCloser, error) {
	const op errors.Op = "protocol.Zip"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	zip, err := p.storage.Zip(ctx, mod, ver)
	result := "hit"
	if err != nil {
		result = "miss"
	}
	observ.RecordCacheLookup(ctx, result, "zip")
	logCacheLookup(ctx, mod, ver, "zip", result)
	if err != nil {
		return nil, errors.E(op, err)
	}

	return zip, nil
}

func logCacheLookup(ctx context.Context, repositoryID, version, resource, result string) {
	log.EntryFromContext(ctx).WithFields(map[string]any{
		"cache_resource": resource,
		"cache_result":   result,
		"repository_id":  repositoryID,
		"version":        version,
	}).Debugf("artifact cache lookup")
}

// union concatenates two version lists and removes duplicates.
func union(list1, list2 []string) []string {
	if list1 == nil {
		list1 = []string{}
	}
	if list2 == nil {
		list2 = []string{}
	}
	list1 = append(list1, list2...)
	unique := []string{}
	m := make(map[string]struct{})
	for _, v := range list1 {
		if _, ok := m[v]; !ok {
			unique = append(unique, v)
			m[v] = struct{}{}
		}
	}
	return unique
}
