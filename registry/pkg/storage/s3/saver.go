package s3

import (
	"bytes"
	"context"
	"io"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/s3/transfermanager"
	"github.com/skillsgo/skillsgo/registry/pkg/errors"
	"github.com/skillsgo/skillsgo/registry/pkg/observ"
	artifactUploader "github.com/skillsgo/skillsgo/registry/pkg/storage/artifact"
)

// Save implements the (github.com/skillsgo/skillsgo/registry/pkg/storage).Saver interface.
func (s *Storage) Save(ctx context.Context, module, version string, manifest []byte, zip io.Reader, zipMD5, info []byte) error {
	const op errors.Op = "s3.Save"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	err := artifactUploader.Upload(ctx, module, version, bytes.NewReader(info), bytes.NewReader(manifest), zip, s.upload, s.timeout)
	// TODO: take out lease on the /list file and add the version to it
	//
	// Do that only after module source+metadata is uploaded
	if err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}
	return nil
}

func (s *Storage) upload(ctx context.Context, path, contentType string, stream io.Reader) error {
	const op errors.Op = "s3.upload"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()

	upParams := &transfermanager.UploadObjectInput{
		Bucket:      aws.String(s.bucket),
		Key:         aws.String(path),
		Body:        stream,
		ContentType: aws.String(contentType),
	}

	if _, err := s.uploader.UploadObject(ctx, upParams); err != nil {
		return errors.E(op, err)
	}

	return nil
}
