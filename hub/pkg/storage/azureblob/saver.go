/*
 * [INPUT]: Depends on the azureblob package imports and contracts declared in this file.
 * [OUTPUT]: Provides the azureblob package behavior implemented by saver.go.
 * [POS]: Serves as maintained source in the azureblob package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package azureblob

import (
	"bytes"
	"context"
	"io"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	artifactUploader "github.com/skillsgo/skillsgo/hub/pkg/storage/artifact"
)

// Save implements the (./pkg/storage).Saver interface.
func (s *Storage) Save(ctx context.Context, module, version string, manifest []byte, zip io.Reader, zipMD5, info []byte) error {
	const op errors.Op = "azureblob.Save"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()

	err := artifactUploader.Upload(ctx, module, version, bytes.NewReader(info), bytes.NewReader(manifest), zip, s.client.UploadWithContext, s.timeout)
	if err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}

	return nil
}
