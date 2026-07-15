package actions

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/skillsgo/skillsgo/registry/pkg/config"
	"github.com/skillsgo/skillsgo/registry/pkg/errors"
	"github.com/skillsgo/skillsgo/registry/pkg/storage"
	"github.com/skillsgo/skillsgo/registry/pkg/storage/azureblob"
	"github.com/skillsgo/skillsgo/registry/pkg/storage/external"
	"github.com/skillsgo/skillsgo/registry/pkg/storage/fs"
	"github.com/skillsgo/skillsgo/registry/pkg/storage/gcp"
	"github.com/skillsgo/skillsgo/registry/pkg/storage/mem"
	"github.com/skillsgo/skillsgo/registry/pkg/storage/minio"
	"github.com/skillsgo/skillsgo/registry/pkg/storage/mongo"
	"github.com/skillsgo/skillsgo/registry/pkg/storage/s3"
	"github.com/spf13/afero"
)

// GetStorage returns storage backend based on env configuration.
func GetStorage(storageType string, storageConfig *config.Storage, timeout time.Duration, client *http.Client) (storage.Backend, error) {
	const op errors.Op = "actions.GetStorage"
	switch storageType {
	case "memory":
		return mem.NewStorage()
	case "mongo":
		if storageConfig.Mongo == nil {
			return nil, errors.E(op, "Invalid Mongo Storage Configuration")
		}
		return mongo.NewStorage(storageConfig.Mongo, timeout)
	case "disk":
		if storageConfig.Disk == nil {
			return nil, errors.E(op, "Invalid Disk Storage Configuration")
		}
		rootLocation := storageConfig.Disk.RootPath
		if err := os.MkdirAll(rootLocation, 0o700); err != nil {
			return nil, errors.E(op, fmt.Errorf("could not create disk storage root %q: %w", rootLocation, err))
		}
		s, err := fs.NewStorage(rootLocation, afero.NewOsFs())
		if err != nil {
			errStr := fmt.Sprintf("could not create new storage from os fs (%s)", err)
			return nil, errors.E(op, errStr)
		}
		return s, nil
	case "minio":
		if storageConfig.Minio == nil {
			return nil, errors.E(op, "Invalid Minio Storage Configuration")
		}
		return minio.NewStorage(storageConfig.Minio, timeout)
	case "gcp":
		if storageConfig.GCP == nil {
			return nil, errors.E(op, "Invalid GCP Storage Configuration")
		}
		return gcp.New(context.Background(), storageConfig.GCP, timeout)
	case "s3":
		if storageConfig.S3 == nil {
			return nil, errors.E(op, "Invalid S3 Storage Configuration")
		}
		return s3.New(storageConfig.S3, timeout, func(config *aws.Config) {
			config.HTTPClient = client
		})
	case "azureblob":
		if storageConfig.AzureBlob == nil {
			return nil, errors.E(op, "Invalid AzureBlob Storage Configuration")
		}
		return azureblob.New(storageConfig.AzureBlob, timeout)
	case "external":
		if storageConfig.External == nil {
			return nil, errors.E(op, "Invalid External Storage Configuration")
		}
		return external.NewClient(storageConfig.External.URL, client), nil
	default:
		return nil, fmt.Errorf("storage type %s is unknown", storageType)
	}
}
