/*
 * [INPUT]: Depends on the artifact package imports and contracts declared in this file.
 * [OUTPUT]: Provides the artifact package behavior implemented by delete.go.
 * [POS]: Serves as maintained source in the artifact package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package artifact

import (
	"context"
	"fmt"
	"time"

	"github.com/hashicorp/go-multierror"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
)

// Deleter takes a path to a file and deletes it from the blob store.
type Deleter func(ctx context.Context, path string) error

// Delete deletes .info, .manifest and .zip files from the blob store in parallel.
// Returns multierror containing errors from all deletes and timeouts.
func Delete(ctx context.Context, module, version string, del Deleter, timeout time.Duration) error {
	const op errors.Op = "module.Delete"
	tctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	delFn := func(ext string) <-chan error {
		ec := make(chan error)

		go func() {
			defer close(ec)
			p := config.PackageVersionedName(module, version, ext)
			ec <- del(tctx, p)
		}()
		return ec
	}

	errChan := make(chan error, numFiles)
	delOrAbort := func(ext string) {
		select {
		case err := <-delFn(ext):
			errChan <- err
		case <-tctx.Done():
			errChan <- fmt.Errorf("deleting %s.%s.%s failed: %w", module, version, ext, tctx.Err())
		}
	}

	go delOrAbort("info")
	go delOrAbort("manifest")
	go delOrAbort("zip")

	var errs error
	for range numFiles {
		err := <-errChan
		if err != nil {
			errs = multierror.Append(errs, err)
		}
	}
	close(errChan)
	if errs != nil {
		return errors.E(op, errs)
	}
	return nil
}
