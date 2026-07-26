/*
 * [INPUT]: Depends on the s3 package imports and contracts declared in this file.
 * [OUTPUT]: Specifies the s3 package behavior covered by s3_test.go.
 * [POS]: Serves as test coverage for the s3 package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package s3

import (
	"bytes"
	"context"
	"os"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/service/s3/types"
	"github.com/aws/smithy-go"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/storage/compliance"
)

func TestBackend(t *testing.T) {
	backend := getStorage(t)
	compliance.RunTests(t, backend, backend.clear)
}

func TestSkillContentStore(t *testing.T) {
	backend := getStorage(t)
	t.Cleanup(func() { _ = backend.clear() })
	content := []byte("---\nname: demo\ndescription: Demo Skill.\n---\n# Demo\n")

	created, err := backend.PutSkillContentIfAbsent(t.Context(), "github.com/acme/skills", "v1.0.0", "skills/demo", content)
	if err != nil || !created {
		t.Fatalf("first write created=%v err=%v", created, err)
	}
	created, err = backend.PutSkillContentIfAbsent(t.Context(), "github.com/acme/skills", "v1.0.0", "skills/demo", content)
	if err != nil || created {
		t.Fatalf("identical retry created=%v err=%v", created, err)
	}
	got, err := backend.SkillContent(t.Context(), "github.com/acme/skills", "v1.0.0", "skills/demo")
	if err != nil || !bytes.Equal(got, content) {
		t.Fatalf("read content=%q err=%v", got, err)
	}
	_, err = backend.PutSkillContentIfAbsent(t.Context(), "github.com/acme/skills", "v1.0.0", "skills/demo", []byte("different"))
	if !errors.Is(err, errors.KindAlreadyExists) {
		t.Fatalf("conflict err=%v", err)
	}
	_, err = backend.SkillContent(t.Context(), "github.com/acme/skills", "v1.0.0", "skills/missing")
	if !errors.Is(err, errors.KindNotFound) {
		t.Fatalf("missing err=%v", err)
	}
}

func TestSkillContentObjectName(t *testing.T) {
	got, err := skillContentObjectName("github.com/acme/skills", "v1.2.3", "skills/demo")
	if err != nil || got != "github.com/acme/skills/@v/v1.2.3.skills/skills/demo/SKILL.md" {
		t.Fatalf("object name=%q err=%v", got, err)
	}
	root, err := skillContentObjectName("github.com/acme/skills", "v1.2.3", ".")
	if err != nil || root != "github.com/acme/skills/@v/v1.2.3.skills/SKILL.md" {
		t.Fatalf("root object name=%q err=%v", root, err)
	}
	if _, err := skillContentObjectName("github.com/acme/skills", "v1.2.3", "../escape"); err == nil {
		t.Fatal("expected traversal path rejection")
	}
}

func BenchmarkBackend(b *testing.B) {
	backend := getStorage(b)
	compliance.RunBenchmarks(b, backend, backend.clear)
}

func (s *Storage) clear() error {
	ctx, cancel := context.WithTimeout(context.Background(), s.timeout)
	defer cancel()

	objects, err := s.s3API.ListObjectsV2(ctx, &s3.ListObjectsV2Input{Bucket: aws.String(s.bucket)})
	if err != nil {
		return err
	}

	for _, o := range objects.Contents {
		delParams := &s3.DeleteObjectInput{
			Bucket: aws.String(s.bucket),
			Key:    o.Key,
		}

		_, err := s.s3API.DeleteObject(ctx, delParams)
		if err != nil {
			return err
		}
	}
	return nil
}

func (s *Storage) createBucket() error {
	ctx, cancel := context.WithTimeout(context.Background(), s.timeout)
	defer cancel()

	if _, err := s.s3API.CreateBucket(ctx, &s3.CreateBucketInput{Bucket: aws.String(s.bucket)}); err != nil {
		var aerr smithy.APIError

		if errors.AsErr(err, &aerr) {
			switch aerr.(type) {
			case *types.BucketAlreadyOwnedByYou:
				return nil
			case *types.BucketAlreadyExists:
				return nil
			default:
				return aerr
			}
		}

		return err
	}

	waiter := s3.NewBucketExistsWaiter(s.s3API)

	return waiter.Wait(ctx, &s3.HeadBucketInput{Bucket: aws.String(s.bucket)}, 10*time.Minute)
}

func getStorage(t testing.TB) *Storage {
	url := os.Getenv("SKILLSGO_HUB_MINIO_ENDPOINT")
	if url == "" {
		t.SkipNow()
	}

	options := func(conf *aws.Config) {
		conf.BaseEndpoint = aws.String(url)
	}

	backend, err := New(
		&config.S3Config{
			Key:            "minio",
			Secret:         "minio123",
			Bucket:         "gomodsaws",
			Region:         "us-west-1",
			ForcePathStyle: true,
		},
		config.GetTimeoutDuration(300),
		options,
	)
	if err != nil {
		t.Fatal(err)
	}

	if err = backend.createBucket(); err != nil {
		t.Fatal(err)
	}

	return backend
}
