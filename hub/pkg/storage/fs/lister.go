/*
 * [INPUT]: Depends on a containment-checked Module storage location and semantic-version directory names.
 * [OUTPUT]: Provides safe listing of immutable versions stored for one Module.
 * [POS]: Serves as the filesystem backend's Module-version enumeration operation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package fs

import (
	"context"
	"os"
	"strings"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/spf13/afero"
	"golang.org/x/mod/semver"
)

func (s *storageImpl) List(ctx context.Context, module string) ([]string, error) {
	const op errors.Op = "fs.List"
	_, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	loc, locationErr := s.containedLocation(module)
	if locationErr != nil {
		return nil, errors.E(op, locationErr, errors.S(module), errors.KindBadRequest)
	}
	fileInfos, err := afero.ReadDir(s.filesystem, loc)
	if err != nil {
		if os.IsNotExist(err) {
			return []string{}, nil
		}

		return nil, errors.E(op, errors.S(module), err, errors.KindUnexpected)
	}
	ret := []string{}
	for _, fileInfo := range fileInfos {
		if !fileInfo.IsDir() {
			continue
		}
		ver := fileInfo.Name()
		if v := semver.Canonical(ver); v != "" && strings.HasPrefix(ver, v) {
			ret = append(ret, ver)
		}
	}
	return ret, nil
}
