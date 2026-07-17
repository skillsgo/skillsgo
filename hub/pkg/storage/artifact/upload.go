/*
 * [INPUT]: Depends on the artifact package imports and contracts declared in this file.
 * [OUTPUT]: Provides the artifact package behavior implemented by upload.go.
 * [POS]: Serves as maintained source in the artifact package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package artifact

import (
	"context"
	"fmt"
	"io"
	"time"

	multierror "github.com/hashicorp/go-multierror"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
)

const numFiles = 2

// Uploader takes a stream and saves it to the blob store under a given path.
type Uploader func(ctx context.Context, path, contentType string, stream io.Reader) error

// Upload saves .info and .zip files to the blob store in parallel.
// Returns multierror containing errors from all uploads and timeouts.
func Upload(ctx context.Context, module, version string, info, zip io.Reader, uploader Uploader, timeout time.Duration) error {
	const op errors.Op = "module.Upload"
	tctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	save := func(ext, contentType string, stream io.Reader) <-chan error {
		ec := make(chan error)

		go func() {
			defer close(ec)
			p := config.PackageVersionedName(module, version, ext)
			ec <- uploader(tctx, p, contentType, stream)
		}()
		return ec
	}

	errChan := make(chan error, numFiles)
	saveOrAbort := func(ext, contentType string, stream io.Reader) {
		select {
		case err := <-save(ext, contentType, stream):
			errChan <- err
		case <-tctx.Done():
			errChan <- fmt.Errorf("uploading %s.%s.%s failed: %w", module, version, ext, tctx.Err())
		}
	}
	go saveOrAbort("info", "application/json", info)
	go saveOrAbort("zip", "application/octet-stream", zip)

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
