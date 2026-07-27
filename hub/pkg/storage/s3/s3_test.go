/*
 * [INPUT]: Depends on the shared storage compliance suite and an explicitly configured dedicated S3-compatible test bucket.
 * [OUTPUT]: Specifies S3 backend compliance, immutable Skill sidecars, object naming, and opt-in real-provider integration behavior.
 * [POS]: Serves as provider-neutral S3 transport integration coverage for AWS S3, Cloudflare R2, or a chosen compatible endpoint.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package s3

import (
	"bytes"
	"context"
	"os"
	"strconv"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/service/s3/types"
	"github.com/aws/smithy-go"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
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
	digest := catalog.ContentDigest(content)

	created, err := backend.PutSkillContentIfAbsent(t.Context(), digest, content)
	if err != nil || !created {
		t.Fatalf("first write created=%v err=%v", created, err)
	}
	created, err = backend.PutSkillContentIfAbsent(t.Context(), digest, content)
	if err != nil || created {
		t.Fatalf("identical retry created=%v err=%v", created, err)
	}
	got, err := backend.SkillContent(t.Context(), digest)
	if err != nil || !bytes.Equal(got, content) {
		t.Fatalf("read content=%q err=%v", got, err)
	}
	_, err = backend.SkillContent(t.Context(), "sha256:0000000000000000000000000000000000000000000000000000000000000000")
	if !errors.Is(err, errors.KindNotFound) {
		t.Fatalf("missing err=%v", err)
	}
}

func TestSkillContentObjectName(t *testing.T) {
	digest := "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
	got, err := skillContentObjectName(digest)
	if err != nil || got != "skillsmd/0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef/SKILL.md" {
		t.Fatalf("object name=%q err=%v", got, err)
	}
	if _, err := skillContentObjectName("../escape"); err == nil {
		t.Fatal("expected invalid digest rejection")
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
	endpoint := os.Getenv("SKILLSGO_TEST_S3_ENDPOINT")
	if endpoint == "" {
		t.SkipNow()
	}
	required := func(name string) string {
		value := os.Getenv(name)
		if value == "" {
			t.Fatalf("%s is required when SKILLSGO_TEST_S3_ENDPOINT is set", name)
		}
		return value
	}
	forcePathStyle, err := strconv.ParseBool(os.Getenv("SKILLSGO_TEST_S3_FORCE_PATH_STYLE"))
	if err != nil && os.Getenv("SKILLSGO_TEST_S3_FORCE_PATH_STYLE") != "" {
		t.Fatalf("invalid SKILLSGO_TEST_S3_FORCE_PATH_STYLE: %v", err)
	}

	backend, err := New(
		&config.S3Config{
			Key:            required("SKILLSGO_TEST_S3_ACCESS_KEY_ID"),
			Secret:         required("SKILLSGO_TEST_S3_SECRET_ACCESS_KEY"),
			Bucket:         required("SKILLSGO_TEST_S3_BUCKET_NAME"),
			Region:         required("SKILLSGO_TEST_S3_REGION"),
			Endpoint:       endpoint,
			ForcePathStyle: forcePathStyle,
		},
		config.GetTimeoutDuration(300),
	)
	if err != nil {
		t.Fatal(err)
	}

	createBucket, parseErr := strconv.ParseBool(os.Getenv("SKILLSGO_TEST_S3_CREATE_BUCKET"))
	if parseErr != nil && os.Getenv("SKILLSGO_TEST_S3_CREATE_BUCKET") != "" {
		t.Fatalf("invalid SKILLSGO_TEST_S3_CREATE_BUCKET: %v", parseErr)
	}
	if createBucket {
		if err = backend.createBucket(); err != nil {
			t.Fatal(err)
		}
	}

	return backend
}
