/*
 * [INPUT]: Depends on first-class R2 configuration, environment decoding, validation, and S3 transport adaptation.
 * [OUTPUT]: Specifies R2 endpoint derivation, credential mapping, jurisdiction handling, and environment-only configuration behavior.
 * [POS]: Serves as focused behavioral coverage for the R2 configuration adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

import (
	"testing"

	"github.com/go-playground/validator/v10"
	"github.com/stretchr/testify/require"
)

func TestR2ConfigConvertsToS3Transport(t *testing.T) {
	r2 := &R2Config{
		AccountID:       "0123456789abcdef0123456789abcdef",
		AccessKeyID:     "access-key",
		SecretAccessKey: "secret-key",
		Bucket:          "skillsgo-artifacts",
		Jurisdiction:    "eu",
	}

	transport := r2.S3Config()
	require.Equal(t, "auto", transport.Region)
	require.Equal(t, r2.AccessKeyID, transport.Key)
	require.Equal(t, r2.SecretAccessKey, transport.Secret)
	require.Equal(t, r2.Bucket, transport.Bucket)
	require.Equal(t, "https://0123456789abcdef0123456789abcdef.eu.r2.cloudflarestorage.com", transport.Endpoint)
	require.False(t, transport.ForcePathStyle)
}

func TestR2ConfigEnvironmentOnly(t *testing.T) {
	setTestHome(t)
	t.Setenv("SKILLSGO_HUB_STORAGE_TYPE", "r2")
	t.Setenv("SKILLSGO_HUB_R2_ACCOUNT_ID", "0123456789abcdef0123456789abcdef")
	t.Setenv("SKILLSGO_HUB_R2_ACCESS_KEY_ID", "access-key")
	t.Setenv("SKILLSGO_HUB_R2_SECRET_ACCESS_KEY", "secret-key")
	t.Setenv("SKILLSGO_HUB_R2_BUCKET_NAME", "skillsgo-artifacts")

	config := defaultConfig()
	require.NoError(t, envOverride(config))
	require.NotNil(t, config.Storage.R2)
	require.Equal(t, "skillsgo-artifacts", config.Storage.R2.Bucket)
	require.NoError(t, validateStorage(validator.New(), config.StorageType, config.Storage))
}

func TestR2ConfigRequiresCredentials(t *testing.T) {
	err := validateStorage(validator.New(), "r2", &Storage{R2: &R2Config{
		AccountID: "0123456789abcdef0123456789abcdef",
		Bucket:    "skillsgo-artifacts",
	}})
	require.Error(t, err)
}
