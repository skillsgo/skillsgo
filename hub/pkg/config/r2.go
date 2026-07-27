/*
 * [INPUT]: Depends on Cloudflare R2 account identity, S3 API credentials, bucket identity, and optional jurisdiction.
 * [OUTPUT]: Provides validated first-class R2 configuration and conversion to the shared S3-compatible backend configuration.
 * [POS]: Serves as the Cloudflare-facing configuration adapter in the Hub config package.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

import "fmt"

// R2Config specifies the properties required to use Cloudflare R2.
type R2Config struct {
	AccountID       string `envconfig:"SKILLSGO_HUB_R2_ACCOUNT_ID"        validate:"required,alphanum"`
	AccessKeyID     string `envconfig:"SKILLSGO_HUB_R2_ACCESS_KEY_ID"     validate:"required"`
	SecretAccessKey string `envconfig:"SKILLSGO_HUB_R2_SECRET_ACCESS_KEY" validate:"required"`
	Bucket          string `envconfig:"SKILLSGO_HUB_R2_BUCKET_NAME"       validate:"required"`
	Jurisdiction    string `envconfig:"SKILLSGO_HUB_R2_JURISDICTION"      validate:"omitempty,alphanum"`
}

// S3Config converts R2 product configuration into the shared S3-compatible
// storage transport configuration.
func (config *R2Config) S3Config() *S3Config {
	host := config.AccountID
	if config.Jurisdiction != "" {
		host += "." + config.Jurisdiction
	}
	return &S3Config{
		Region:         "auto",
		Key:            config.AccessKeyID,
		Secret:         config.SecretAccessKey,
		Bucket:         config.Bucket,
		Endpoint:       fmt.Sprintf("https://%s.r2.cloudflarestorage.com", host),
		ForcePathStyle: false,
	}
}
