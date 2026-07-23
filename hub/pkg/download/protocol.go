/*
 * [INPUT]: Depends on storage, source listing, synchronous stashing, and a durable asynchronous stash submitter.
 * [OUTPUT]: Provides storage-first artifact protocol behavior with cache, durable async dispatch, and download-mode telemetry.
 * [POS]: Serves as the observable storage/source orchestration layer in the artifact download protocol.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package download

import (
	"context"
	"sync"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/download/mode"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/skillsgo/skillsgo/hub/pkg/requestid"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/stash"
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

// Wrapper helps extend the main protocol's functionality with addons.
type Wrapper func(Protocol) Protocol

// Opts specifies download protocol options to avoid long func signature.
type Opts struct {
	Storage      storage.Backend
	Stasher      stash.Stasher
	Lister       skill.UpstreamLister
	DownloadFile *mode.DownloadFile
	NetworkMode  string
	AsyncStash   func(context.Context, string, string) error
}

// NetworkMode constants.
const (
	Strict   = "strict"
	Offline  = "offline"
	Fallback = "fallback"
)

// New returns a full implementation of the download.Protocol
// that the proxy needs. New also takes a variadic list of wrappers
// to extend the protocol's functionality (see addons package).
// The wrappers are applied in order, meaning the last wrapper
// passed is the Protocol that gets hit first.
func New(opts *Opts, wrappers ...Wrapper) Protocol {
	if opts.DownloadFile == nil {
		opts.DownloadFile = &mode.DownloadFile{Mode: mode.Sync}
	}
	var p Protocol = &protocol{opts.DownloadFile, opts.Storage, opts.Stasher, opts.Lister, opts.NetworkMode, opts.AsyncStash}
	for _, w := range wrappers {
		p = w(p)
	}

	return p
}

type protocol struct {
	df          *mode.DownloadFile
	storage     storage.Backend
	stasher     stash.Stasher
	lister      skill.UpstreamLister
	networkMode string
	asyncStash  func(context.Context, string, string) error
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
	if err == nil {
		observ.RecordCacheLookup(ctx, "hit", "info")
		logCacheLookup(ctx, mod, ver, "info", "hit")
	} else if errors.IsNotFoundErr(err) {
		observ.RecordCacheLookup(ctx, "miss", "info")
		logCacheLookup(ctx, mod, ver, "info", "miss")
		err = p.processDownload(ctx, mod, ver, func(newVer string) error {
			info, err = p.storage.Info(ctx, mod, newVer)
			return err
		})
	}
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
	if err == nil {
		observ.RecordCacheLookup(ctx, "hit", "zip")
		logCacheLookup(ctx, mod, ver, "zip", "hit")
	} else if errors.IsNotFoundErr(err) {
		observ.RecordCacheLookup(ctx, "miss", "zip")
		logCacheLookup(ctx, mod, ver, "zip", "miss")
		err = p.processDownload(ctx, mod, ver, func(newVer string) error {
			zip, err = p.storage.Zip(ctx, mod, newVer)
			return err
		})
	}
	if err != nil {
		return nil, errors.E(op, err)
	}

	return zip, nil
}

func (p *protocol) processDownload(ctx context.Context, mod, ver string, f func(newVer string) error) error {
	const op errors.Op = "protocol.processDownload"
	if p.networkMode == Offline {
		return errors.E(op, "artifact is not available in offline storage", errors.S(mod), errors.V(ver), errors.KindNotFound)
	}
	// Create a new context with custom deadline and ditch whatever deadline was passed by the caller.
	// This is needed so that the async go routines can continue even after the HTTP request is complete (which leads to context cancellation).
	ctx, cancel := copyContextWithCustomTimeout(ctx, time.Minute*15)
	defer cancel()
	log.EntryFromContext(ctx).WithFields(map[string]any{
		"download_mode": p.df.Match(mod),
		"skill_id":      mod,
		"version":       ver,
	}).Debugf("artifact download dispatched")
	switch p.df.Match(mod) {
	case mode.Sync:
		newVer, err := p.stasher.Stash(ctx, mod, ver)
		if err != nil {
			return errors.E(op, err)
		}
		return f(newVer)
	case mode.Async:
		if p.asyncStash == nil {
			return errors.E(op, "async stash dispatcher is not configured")
		}
		if err := p.asyncStash(ctx, mod, ver); err != nil {
			return errors.E(op, err)
		}
		return errors.E(op, "async: module not found", errors.KindNotFound)
	case mode.Redirect:
		return errors.E(op, "redirect", errors.KindRedirect)
	case mode.AsyncRedirect:
		if p.asyncStash == nil {
			return errors.E(op, "async stash dispatcher is not configured")
		}
		if err := p.asyncStash(ctx, mod, ver); err != nil {
			return errors.E(op, err)
		}
		return errors.E(op, "async_redirect: module not found", errors.KindRedirect)
	case mode.None:
		return errors.E(op, "none", errors.KindNotFound)
	}
	return nil
}

func logCacheLookup(ctx context.Context, skillID, version, resource, result string) {
	log.EntryFromContext(ctx).WithFields(map[string]any{
		"cache_resource": resource,
		"cache_result":   result,
		"skill_id":       skillID,
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

func copyContextWithCustomTimeout(ctx context.Context, timeout time.Duration) (context.Context, context.CancelFunc) {
	ctxCopy, cancel := context.WithTimeout(context.Background(), timeout)
	ctxCopy = requestid.SetInContext(ctxCopy, requestid.FromContext(ctx))
	ctxCopy = log.SetEntryInContext(ctxCopy, log.EntryFromContext(ctx))
	return ctxCopy, cancel
}
