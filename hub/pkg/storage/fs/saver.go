/*
 * [INPUT]: Depends on the fs package imports and contracts declared in this file.
 * [OUTPUT]: Provides the fs package behavior implemented by saver.go.
 * [POS]: Serves as maintained source in the fs package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package fs

import (
	"context"
	"io"
	"os"
	"path/filepath"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/spf13/afero"
)

func (s *storageImpl) Save(ctx context.Context, module, version string, zip io.Reader, zipMD5, info []byte) error {
	const op errors.Op = "fs.Save"
	_, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	dir := s.versionLocation(module, version)

	// NB: The process's umask is subtracted from the permissions below,
	// so an umask of for example 0077 allows directories and files to be
	// created with mode 0700 / 0600, i.e. not world- or group-readable.

	// Make the versioned directory to hold immutable Info and ZIP resources.
	if err := s.filesystem.MkdirAll(dir, 0o777); err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}

	// Write the zipfile.
	f, err := s.filesystem.OpenFile(filepath.Join(dir, "source.zip"), os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o666)
	if err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}
	defer func() { _ = f.Close() }()
	_, err = io.Copy(f, zip)
	if err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}

	// write the info file
	err = afero.WriteFile(s.filesystem, filepath.Join(dir, version+".info"), info, 0o666)
	if err != nil {
		return errors.E(op, err)
	}
	return nil
}
