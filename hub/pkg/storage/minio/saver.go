/*
 * [INPUT]: Depends on the minio package imports and contracts declared in this file.
 * [OUTPUT]: Provides the minio package behavior implemented by saver.go.
 * [POS]: Serves as maintained source in the minio package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package minio

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"io"

	"github.com/hashicorp/go-multierror"
	minio "github.com/minio/minio-go/v6"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
)

func (s *storageImpl) Save(ctx context.Context, module, vsn string, zip io.Reader, zipMD5, info []byte) error {
	const op errors.Op = "storage.minio.Save"
	_, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	dir := s.versionLocation(module, vsn)
	infoFileName := dir + "/" + vsn + ".info"
	// Chunk the stream into 8mb and send them in parts to minio.
	// This is because the minio client over-allocates a stream buffer (600Mb)
	// when the size is unknown, see https://github.com/minio/minio-go/issues/848
	err := s.saveZip(dir, module, vsn, zip)
	if err != nil {
		return errors.E(op, err)
	}
	_, err = s.minioClient.PutObject(s.bucketName, infoFileName, bytes.NewReader(info), int64(len(info)), minio.PutObjectOptions{})
	if err != nil {
		return errors.E(op, err)
	}
	return nil
}

type partWriter struct {
	numParts   int
	c          *minio.Client
	mod, ver   string
	bucketName string
	err        error
	srcs       []minio.SourceInfo
}

func (zw *partWriter) Write(p []byte) (int, error) {
	const op errors.Op = "minio.partWriter.Write"
	if zw.err != nil {
		return 0, errors.E(op, zw.err)
	} else if len(p) == 0 {
		return 0, nil
	}
	partName := fmt.Sprintf("parts/%s/%s/%d", zw.mod, zw.ver, zw.numParts)
	plen := int64(len(p))
	_, zw.err = zw.c.PutObject(zw.bucketName, partName, bytes.NewReader(p), plen, minio.PutObjectOptions{})
	if zw.err != nil {
		return 0, errors.E(op, zw.err)
	}
	zw.srcs = append(zw.srcs, minio.NewSourceInfo(zw.bucketName, partName, nil))
	zw.numParts++
	return len(p), nil
}

func (s *storageImpl) saveZip(dir, module, ver string, zip io.Reader) error {
	const op errors.Op = "minio.saveZip"
	const partSize = 8 * 1024 * 1024
	rdr := bufio.NewReaderSize(zip, partSize)
	wr := &partWriter{0, s.minioClient, module, ver, s.bucketName, nil, nil}
	_, err := rdr.WriteTo(wr)
	if err != nil {
		return errors.E(op, err)
	}
	zipFileName := dir + "/" + "source.zip"
	dst, err := minio.NewDestinationInfo(s.bucketName, zipFileName, nil, nil)
	if err != nil {
		return errors.E(op, errors.E("minio.NewDestinationInfo", err))
	}
	err = s.minioClient.ComposeObject(dst, wr.srcs)
	if err != nil {
		return errors.E(op, errors.E("minio.ComposeObject", err))
	}
	err = s.removeParts(module, ver, wr.numParts)
	if err != nil {
		return errors.E(op, err)
	}
	return nil
}

func (s *storageImpl) removeParts(mod, ver string, numParts int) error {
	const op errors.Op = "minio.removeParts"
	objectsCh := make(chan string)
	go func() {
		defer close(objectsCh)
		for i := range numParts {
			objectsCh <- fmt.Sprintf("parts/%s/%s/%d", mod, ver, i)
		}
	}()
	var errs error
	for e := range s.minioClient.RemoveObjects(s.bucketName, objectsCh) {
		errs = multierror.Append(errs, e.Err)
	}
	if errs != nil {
		return errors.E(op, errs)
	}
	return nil
}
