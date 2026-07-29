/*
 * [INPUT]: Depends on canonical Source Repository Tag listing and configured offline/strict/fallback network policy.
 * [OUTPUT]: Provides upstream Package Tag listing; Catalog decorators own published versions and Package Info.
 * [POS]: Serves as the source-discovery base of the Package distribution protocol without object-storage metadata coupling.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package download

import (
	"context"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
)

// Protocol is the Package distribution protocol exposed by the Hub proxy.
type Protocol interface {
	// List implements GET /api/v1/{packagePath}/versions.
	List(ctx context.Context, mod string) ([]string, error)

	// Info implements GET /api/v1/{packagePath}/versions/{version} and returns canonical Package Info.
	Info(ctx context.Context, mod, ver string) ([]byte, error)
}

// Opts specifies download protocol options to avoid long func signature.
type Opts struct {
	Lister      skill.UpstreamLister
	NetworkMode string
}

// NetworkMode constants.
const (
	Strict   = "strict"
	Offline  = "offline"
	Fallback = "fallback"
)

// New returns the storage-backed Package distribution protocol.
func New(opts *Opts) Protocol {
	return &protocol{lister: opts.Lister, networkMode: opts.NetworkMode}
}

type protocol struct {
	lister      skill.UpstreamLister
	networkMode string
}

func (p *protocol) List(ctx context.Context, mod string) ([]string, error) {
	const op errors.Op = "protocol.List"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()

	if p.networkMode == Offline {
		return []string{}, nil
	}
	_, versions, upstreamErr := p.lister.List(ctx, mod)

	// if i.e. github is unavailable we should fail as well so that the behavior of the proxy is stable.
	// otherwise we will get different results the next time because i.e. GH is up again
	isUnexpGoErr := upstreamErr != nil && !errors.IsRepoNotFoundErr(upstreamErr)
	if isUnexpGoErr && p.networkMode == Strict {
		return nil, errors.E(op, upstreamErr)
	}

	// if we're in fallback mode, and VCS is down, just return what we have in storage,
	// don't remove any pseudo versions.
	if isUnexpGoErr && p.networkMode == Fallback {
		return []string{}, nil
	}

	if upstreamErr != nil && errors.IsRepoNotFoundErr(upstreamErr) {
		return nil, errors.E(op, errors.S(mod), errors.KindNotFound, upstreamErr)
	}
	return versions, nil
}

func (p *protocol) Info(ctx context.Context, mod, ver string) ([]byte, error) {
	const op errors.Op = "protocol.Info"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	return nil, errors.E(op, errors.S(mod), errors.V(ver), errors.KindNotFound)
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
