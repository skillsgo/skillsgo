package azureblob

import (
	"bytes"
	"context"
	"io"

	"github.com/skillsgo/skillsgo/registry/pkg/errors"
	"github.com/skillsgo/skillsgo/registry/pkg/observ"
	artifactUploader "github.com/skillsgo/skillsgo/registry/pkg/storage/artifact"
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
