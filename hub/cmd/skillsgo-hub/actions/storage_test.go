/*
 * [INPUT]: Depends on validated first-class R2 configuration, the shared HTTP client, and runtime storage construction.
 * [OUTPUT]: Specifies that R2 selects the existing S3-compatible immutable artifact backend, rejects missing configuration, and keeps removed providers unavailable.
 * [POS]: Serves as focused wiring coverage for storage provider selection in the actions module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"net/http"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/storage/s3"
	"github.com/stretchr/testify/require"
)

func TestGetStorageBuildsR2WithS3CompatibleBackend(t *testing.T) {
	backend, err := GetStorage("r2", &config.Storage{R2: &config.R2Config{
		AccountID:       "0123456789abcdef0123456789abcdef",
		AccessKeyID:     "access-key",
		SecretAccessKey: "secret-key",
		Bucket:          "skillsgo-artifacts",
	}}, time.Second, http.DefaultClient)

	require.NoError(t, err)
	require.IsType(t, &s3.Storage{}, backend)
}

func TestGetStorageRejectsMissingR2Configuration(t *testing.T) {
	_, err := GetStorage("r2", &config.Storage{}, time.Second, http.DefaultClient)
	require.ErrorContains(t, err, "Invalid R2 Storage Configuration")
}

func TestGetStorageRejectsRemovedProviders(t *testing.T) {
	for _, storageType := range []string{"mongo", "external"} {
		t.Run(storageType, func(t *testing.T) {
			_, err := GetStorage(storageType, &config.Storage{}, time.Second, http.DefaultClient)
			require.ErrorContains(t, err, "storage type "+storageType+" is unknown")
		})
	}
}
